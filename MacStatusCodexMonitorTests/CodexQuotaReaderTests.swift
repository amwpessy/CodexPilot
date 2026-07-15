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

    func testIgnoresConversationOnlyEvents() {
        let line = #"{"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"agent_message","text":"hello"}}"#
        XCTAssertNil(CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil))
    }
}
