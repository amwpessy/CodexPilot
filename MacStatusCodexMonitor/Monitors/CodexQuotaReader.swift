import Foundation

struct CodexQuotaReader: Sendable {
    private let root: URL

    init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    ) {
        self.root = root
    }

    func latestQuotaSnapshot() -> CodexQuotaSnapshot {
        let files = jsonlFiles(in: root)
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

        return latest ?? .unavailable
    }

    func parseLine(_ line: String, fileModifiedAt: Date?) -> CodexQuotaSnapshot? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any] else {
            return nil
        }

        let timestamp = (object["timestamp"] as? String).flatMap(Self.isoDate(_:)) ?? fileModifiedAt
        let primary = rateLimits["primary"] as? [String: Any]
        let usedPercent = primary?["used_percent"] as? Double
        let resetsAt = (primary?["resets_at"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let windowMinutes = primary?["window_minutes"] as? Int
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

    private static func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
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

        let resetCardKeys = rateLimits.keys
            .filter { key in
                let lowered = key.lowercased()
                return lowered.contains("reset") || lowered.contains("card")
            }
            .filter { $0 != "rate_limit_reached_type" }
            .sorted()

        for key in resetCardKeys {
            guard let value = rateLimits[key], !(value is NSNull) else {
                continue
            }
            parts.append("\(key): \(describeJSONValue(value))")
        }

        return parts.isEmpty ? "Not reported" : parts.joined(separator: " / ")
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
