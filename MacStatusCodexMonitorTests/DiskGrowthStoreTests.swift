import XCTest
@testable import MacStatusCodexMonitor

final class DiskGrowthStoreTests: XCTestCase {
    func testComputesTwentyFourHourGrowthFromAvailableSpaceDrop() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DiskGrowthStore(storageURL: directory.appendingPathComponent("disk.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-25 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 750, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertEqual(summary.growthBytes, 150)
        XCTAssertEqual(summary.statusText, "24h history ready")
    }

    func testReportsLearningWhenHistoryIsShort() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DiskGrowthStore(storageURL: directory.appendingPathComponent("disk.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-2 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 800, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertNil(summary.growthBytes)
        XCTAssertEqual(summary.statusText, "Learning: 2.0h history")
    }
}
