import Foundation
import Darwin

struct CodexLogAccess: Sendable {
    var scopeURL: URL?
    var sessionsURL: URL
    var usesBookmark: Bool
}

enum CodexLogAccessError: LocalizedError {
    case noCodexJSONLLogs(URL)

    var errorDescription: String? {
        switch self {
        case let .noCodexJSONLLogs(url):
            return "No Codex JSONL logs found in \(url.path). Select ~/.codex or ~/.codex/sessions."
        }
    }
}

enum CodexLogAccessStore {
    private static let bookmarkKey = "CodexPilot.codexSessionsBookmark"

    static func userHomeDirectoryURL() -> URL {
        guard let passwordEntry = getpwuid(getuid()),
              let homePath = passwordEntry.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
    }

    static func defaultCodexDirectoryURL() -> URL {
        userHomeDirectoryURL().appendingPathComponent(".codex", isDirectory: true)
    }

    static func defaultSessionsURL() -> URL {
        defaultCodexDirectoryURL().appendingPathComponent("sessions", isDirectory: true)
    }

    static func resolvedAccess() -> CodexLogAccess {
        selectedAccess() ?? CodexLogAccess(
            scopeURL: nil,
            sessionsURL: defaultSessionsURL(),
            usesBookmark: false
        )
    }

    static func resolvedSessionsURL() -> URL {
        resolvedAccess().sessionsURL
    }

    static func selectedSessionsURL() -> URL? {
        selectedAccess()?.sessionsURL
    }

    static func selectedAccess() -> CodexLogAccess? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }

        if stale {
            try? saveSelectedDirectory(url)
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let sessionsURL = normalizedSessionsURL(from: url)
        guard containsJSONLFiles(in: sessionsURL) else {
            clearSelectedDirectory()
            return nil
        }

        return CodexLogAccess(
            scopeURL: url,
            sessionsURL: sessionsURL,
            usesBookmark: true
        )
    }

    static func saveSelectedDirectory(_ url: URL) throws {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        _ = try validatedSessionsURL(from: url)

        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func clearSelectedDirectory() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static func validatedSessionsURL(from url: URL) throws -> URL {
        let sessionsURL = normalizedSessionsURL(from: url)
        guard containsJSONLFiles(in: sessionsURL) else {
            throw CodexLogAccessError.noCodexJSONLLogs(sessionsURL)
        }
        return sessionsURL
    }

    static func normalizedSessionsURL(from url: URL) -> URL {
        if url.lastPathComponent == "sessions" {
            return url
        }
        if url.lastPathComponent == ".codex" {
            return url.appendingPathComponent("sessions", isDirectory: true)
        }

        let codexSessionsURL = url
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        if FileManager.default.fileExists(atPath: codexSessionsURL.path) {
            return codexSessionsURL
        }

        let sessionsURL = url.appendingPathComponent("sessions", isDirectory: true)
        if FileManager.default.fileExists(atPath: sessionsURL.path) {
            return sessionsURL
        }

        return url
    }

    static func containsJSONLFiles(in root: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for item in enumerator {
            guard let url = item as? URL, url.pathExtension == "jsonl" else {
                continue
            }
            return true
        }

        return false
    }
}

struct CodexQuotaReader: Sendable {
    private let root: URL?

    init(
        root: URL? = nil
    ) {
        self.root = root
    }

    func latestQuotaSnapshot() -> CodexQuotaSnapshot {
        let access = root.map {
            CodexLogAccess(scopeURL: nil, sessionsURL: $0, usesBookmark: false)
        } ?? CodexLogAccessStore.resolvedAccess()
        let scopeURL = access.scopeURL ?? access.sessionsURL
        let didStartAccessing = scopeURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                scopeURL.stopAccessingSecurityScopedResource()
            }
        }

        let files = jsonlFiles(in: access.sessionsURL)
        guard !files.isEmpty else {
            return Self.unavailableSnapshot(
                sourceDescription: "No Codex JSONL files found",
                detail: access.sessionsURL.path
            )
        }

        var latest: CodexQuotaSnapshot?

        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else {
                continue
            }

            let modifiedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let snapshot = parseLine(String(line), fileModifiedAt: modifiedAt) else {
                    continue
                }

                if (snapshot.freshness ?? .distantPast) >= (latest?.freshness ?? .distantPast) {
                    latest = snapshot
                }
            }
        }

        return latest ?? Self.unavailableSnapshot(
            sourceDescription: "No Codex quota event found in local logs",
            detail: "\(files.count) JSONL files scanned"
        )
    }

    func parseLine(_ line: String, fileModifiedAt: Date?) -> CodexQuotaSnapshot? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimits = Self.findRateLimits(in: object) else {
            return nil
        }

        let timestamp = (object["timestamp"] as? String).flatMap(Self.isoDate(_:)) ?? fileModifiedAt
        let primary = rateLimits["primary"] as? [String: Any]
        let usedPercent = Self.doubleValue(primary?["used_percent"])
        let resetsAt = Self.doubleValue(primary?["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        let windowMinutes = Self.intValue(primary?["window_minutes"])
        let remainingPercent = usedPercent.map { max(0, min(100, 100 - $0)) }

        return CodexQuotaSnapshot(
            sourceDescription: "local Codex log signal",
            freshness: timestamp,
            limitID: rateLimits["limit_id"] as? String,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes,
            planType: rateLimits["plan_type"] as? String,
            creditsDescription: Self.creditsDescription(rateLimits["credits"]),
            individualLimitDescription: rateLimits["individual_limit"].map(Self.describeJSONValue) ?? "Not reported",
            extraQuotaDescription: Self.extraQuotaDescription(rateLimits),
            rateLimitReachedType: rateLimits["rate_limit_reached_type"] as? String
        )
    }

    private func jsonlFiles(in root: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "jsonl" else {
                return nil
            }
            return url
        }
    }

    private static func unavailableSnapshot(sourceDescription: String, detail: String) -> CodexQuotaSnapshot {
        CodexQuotaSnapshot(
            sourceDescription: sourceDescription,
            freshness: nil,
            limitID: nil,
            usedPercent: nil,
            remainingPercent: nil,
            resetsAt: nil,
            windowMinutes: nil,
            planType: nil,
            creditsDescription: "Not reported",
            individualLimitDescription: detail,
            extraQuotaDescription: "Not reported",
            rateLimitReachedType: nil
        )
    }

    private static func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    private static func findRateLimits(in object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            if let rateLimits = dictionary["rate_limits"] as? [String: Any] {
                return rateLimits
            }

            for key in dictionary.keys.sorted() {
                guard let value = dictionary[key],
                      let rateLimits = findRateLimits(in: value) else {
                    continue
                }
                return rateLimits
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let rateLimits = findRateLimits(in: value) {
                    return rateLimits
                }
            }
        }

        return nil
    }

    private static func creditsDescription(_ value: Any?) -> String {
        guard let dictionary = value as? [String: Any] else {
            return "Not reported"
        }

        let hasCredits = dictionary["has_credits"] as? Bool
        let unlimited = dictionary["unlimited"] as? Bool
        let balance = dictionary["balance"]

        if unlimited == true {
            return "Unlimited credits"
        }
        if hasCredits == false {
            return "No credits"
        }
        if let balance, !(balance is NSNull) {
            return "Balance: \(describeJSONValue(balance))"
        }

        return hasCredits == true ? "Credits available" : "Not reported"
    }

    private static func extraQuotaDescription(_ rateLimits: [String: Any]) -> String {
        var parts: [String] = []

        if let secondary = rateLimits["secondary"], !(secondary is NSNull) {
            parts.append("secondary: \(describeJSONValue(secondary))")
        }

        if let resetCards = resetCardCount(in: rateLimits) {
            parts.append("重置卡: \(resetCards) / Reset cards: \(resetCards)")
        }

        let resetCardKeys = rateLimits.keys
            .filter { key in
                let lowered = key.lowercased()
                return lowered.contains("reset") || lowered.contains("card")
            }
            .filter { key in
                let lowered = key.lowercased()
                return lowered != "rate_limit_reached_type"
                    && lowered != "resets_at"
                    && resetCardCount(in: rateLimits) == nil
            }
            .sorted()

        for key in resetCardKeys {
            guard let value = rateLimits[key], !(value is NSNull) else {
                continue
            }
            parts.append("\(key): \(describeJSONValue(value))")
        }

        return parts.isEmpty ? "Not reported" : parts.joined(separator: " / ")
    }

    private static func resetCardCount(in object: Any, path: [String] = []) -> Int? {
        if let dictionary = object as? [String: Any] {
            for key in dictionary.keys.sorted() {
                let lowered = key.lowercased()
                guard lowered != "resets_at",
                      lowered != "rate_limit_reached_type",
                      let value = dictionary[key] else {
                    continue
                }

                let nextPath = path + [lowered]
                if isResetCardPath(nextPath),
                   isCountKey(lowered),
                   let count = intValue(value) {
                    return count
                }

                if let count = resetCardCount(in: value, path: nextPath) {
                    return count
                }
            }
        } else if isResetCardPath(path),
                  let last = path.last,
                  isCountKey(last),
                  let count = intValue(object) {
            return count
        }

        return nil
    }

    private static func isResetCardPath(_ path: [String]) -> Bool {
        let joined = path.joined(separator: "_")
        return joined.contains("reset") && joined.contains("card")
    }

    private static func isCountKey(_ key: String) -> Bool {
        key.contains("remaining")
            || key.contains("count")
            || key.contains("available")
            || key.contains("balance")
            || key.hasSuffix("cards")
            || key.hasSuffix("card")
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as UInt:
            return Int(value)
        case let value as Double where value.rounded() == value:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as UInt:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func describeJSONValue(_ value: Any) -> String {
        if value is NSNull {
            return "Not reported"
        }
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return "\(value)"
    }
}
