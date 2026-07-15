import XCTest
@testable import MacStatusCodexMonitor

final class CodexQuotaReaderTests: XCTestCase {
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
