import XCTest
@testable import MacStatusCodexMonitor

final class CodexQuotaReaderTests: XCTestCase {
    func testLatestQuotaSnapshotChoosesFreshestQuotaEventAcrossFilesAndLines() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let olderFile = root.appendingPathComponent("older.jsonl")
        let newerFile = root.appendingPathComponent("newer.jsonl")

        try """
        {"timestamp":"2026-07-15T07:45:30.000Z","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":12.0,"window_minutes":60,"resets_at":1784700000},"credits":{"has_credits":false,"unlimited":false,"balance":null},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        {"timestamp":"2026-07-15T07:55:30.000Z","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":44.0,"window_minutes":60,"resets_at":1784700600},"credits":{"has_credits":true,"unlimited":false,"balance":3},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """.write(to: olderFile, atomically: true, encoding: .utf8)

        try """
        {"timestamp":"2026-07-15T07:50:30.000Z","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":23.0,"window_minutes":60,"resets_at":1784700300},"credits":{"has_credits":false,"unlimited":false,"balance":null},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """.write(to: newerFile, atomically: true, encoding: .utf8)

        let snapshot = CodexQuotaReader(root: root).latestQuotaSnapshot()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        XCTAssertEqual(snapshot.limitID, "codex")
        XCTAssertEqual(snapshot.usedPercent, 44.0)
        XCTAssertEqual(snapshot.remainingPercent, 56.0)
        XCTAssertEqual(snapshot.creditsDescription, "Balance: 3")
        XCTAssertEqual(snapshot.planType, "team")
        XCTAssertEqual(snapshot.freshness, formatter.date(from: "2026-07-15T07:55:30.000Z"))
    }

    func testParsesRateLimitEvent() {
        let line = """
        {"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1784704630},"secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":null},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """

        let snapshot = CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil)

        XCTAssertEqual(snapshot?.limitID, "codex")
        XCTAssertEqual(snapshot?.usedPercent, 2.0)
        XCTAssertEqual(snapshot?.remainingPercent, 98.0)
        XCTAssertEqual(snapshot?.windowMinutes, 10080)
        XCTAssertEqual(snapshot?.planType, "team")
        XCTAssertEqual(snapshot?.creditsDescription, "No credits")
        XCTAssertEqual(snapshot?.sourceDescription, "local Codex log signal")
    }

    func testParsesNestedRateLimitsAndIntegerValues() {
        let line = """
        {"timestamp":"2026-07-17T04:01:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":4,"window_minutes":10080,"resets_at":1784704630},"secondary":{"used_percent":9,"window_minutes":10080,"resets_at":1783388619},"credits":{"has_credits":false,"unlimited":false,"balance":null},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}}
        """

        let snapshot = CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil)

        XCTAssertEqual(snapshot?.limitID, "codex")
        XCTAssertEqual(snapshot?.usedPercent, 4)
        XCTAssertEqual(snapshot?.remainingPercent, 96)
        XCTAssertEqual(snapshot?.windowMinutes, 10080)
        XCTAssertEqual(snapshot?.resetsAt, Date(timeIntervalSince1970: 1_784_704_630))
        XCTAssertTrue(snapshot?.extraQuotaDescription.contains("secondary") == true)
    }

    func testNormalizesSelectedCodexDirectoryToSessionsWithoutFileSystemProbe() {
        let selectedCodexDirectory = URL(fileURLWithPath: "/tmp/nonexistent-home/.codex", isDirectory: true)

        let sessionsURL = CodexLogAccessStore.normalizedSessionsURL(from: selectedCodexDirectory)

        XCTAssertEqual(sessionsURL.path, "/tmp/nonexistent-home/.codex/sessions")
    }

    func testNormalizesSelectedHomeDirectoryToCodexSessionsWhenPresent() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessions = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        try fileManager.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        let sessionsURL = CodexLogAccessStore.normalizedSessionsURL(from: home)

        XCTAssertEqual(sessionsURL.path, sessions.path)
    }

    func testRejectsSelectedDirectoryWithoutCodexJSONLLogs() {
        let selectedProjectDirectory = URL(fileURLWithPath: "/tmp/nonexistent-home/Documents/Codex/2026-07-14", isDirectory: true)

        XCTAssertThrowsError(try CodexLogAccessStore.validatedSessionsURL(from: selectedProjectDirectory)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Codex JSONL"))
        }
    }

    func testIgnoresConversationOnlyEvents() {
        let line = #"{"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"agent_message","text":"hello"}}"#
        XCTAssertNil(CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil))
    }

    func testParsesSecondaryAndResetCardLikeQuotaExtras() {
        let line = """
        {"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10.0,"window_minutes":60,"resets_at":1784704630},"secondary":{"used_percent":50.0,"window_minutes":10080},"reset_cards_remaining":2,"credits":{"has_credits":true,"unlimited":false,"balance":1},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """

        let snapshot = CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil)

        XCTAssertTrue(snapshot?.extraQuotaDescription.contains("secondary") == true)
        XCTAssertTrue(snapshot?.extraQuotaDescription.contains("重置卡: 2 / Reset cards: 2") == true)
    }

    func testParsesNestedResetCardCountFromQuotaExtras() {
        let line = """
        {"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10.0,"window_minutes":60,"resets_at":1784704630},"quota":{"reset_cards":{"remaining":3,"total":5}},"credits":{"has_credits":true,"unlimited":false,"balance":1},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """

        let snapshot = CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil)

        XCTAssertTrue(snapshot?.extraQuotaDescription.contains("重置卡: 3 / Reset cards: 3") == true)
    }
}
