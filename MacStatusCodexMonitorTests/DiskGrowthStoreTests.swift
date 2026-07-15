import XCTest
@testable import MacStatusCodexMonitor

final class DiskGrowthStoreTests: XCTestCase {
    func testComputesTwentyFourHourGrowthFromAvailableSpaceDrop() throws {
        let directory = try makeTemporaryDirectory()
        let store = makeStore(in: directory)
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-25 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 750, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertEqual(summary.growthBytes, 150)
        XCTAssertEqual(summary.statusText, "24h history ready")
    }

    func testReportsLearningWhenHistoryIsShort() throws {
        let directory = try makeTemporaryDirectory()
        let store = makeStore(in: directory)
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-2 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 800, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertNil(summary.growthBytes)
        XCTAssertEqual(summary.statusText, "Learning: 2.0h history")
    }

    func testDoesNotReportReadyWhenNearestTwentyFourHourBaselineIsTooStale() throws {
        let directory = try makeTemporaryDirectory()
        let store = makeStore(in: directory)
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-40 * 3600), availableBytes: 920, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-8 * 3600), availableBytes: 860, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 800, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertNil(summary.growthBytes)
        XCTAssertEqual(summary.statusText, "Learning: sparse 24h history")
    }

    func testRecordPreservesCorruptStoreBeforeWritingFreshHistory() throws {
        let directory = try makeTemporaryDirectory()
        let storageURL = directory.appendingPathComponent("disk.json")
        let backupURL = directory.appendingPathComponent("disk.json.corrupt")
        let originalData = Data("not valid json".utf8)
        try originalData.write(to: storageURL)
        let store = DiskGrowthStore(storageURL: storageURL)

        try store.record(DiskSnapshot(timestamp: Date(timeIntervalSince1970: 10_000_000), availableBytes: 700, totalBytes: 1_000))

        XCTAssertEqual(try Data(contentsOf: backupURL), originalData)

        let rewrittenSnapshots = store.loadSnapshots()
        XCTAssertEqual(rewrittenSnapshots.count, 1)
        XCTAssertEqual(rewrittenSnapshots.first?.availableBytes, 700)
    }

    func testRecordTrimsSnapshotsOutsideThirtyDayRetention() throws {
        let directory = try makeTemporaryDirectory()
        let store = makeStore(in: directory)
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-(31 * 24 * 3600)), availableBytes: 950, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-(29 * 24 * 3600)), availableBytes: 850, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 800, totalBytes: 1_000))

        let snapshots = store.loadSnapshots()

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.map(\.availableBytes), [850, 800])
    }

    func testCacheAnalyzerTotalsRegularFilesAcrossDirectoriesAndSortsEntries() throws {
        let directory = try makeTemporaryDirectory()
        let cachesURL = directory.appendingPathComponent("Caches", isDirectory: true)
        let logsURL = directory.appendingPathComponent("Logs", isDirectory: true)
        let nestedURL = cachesURL.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)

        try Data(repeating: 0x61, count: 3).write(to: cachesURL.appendingPathComponent("top.bin"))
        try Data(repeating: 0x62, count: 5).write(to: nestedURL.appendingPathComponent("nested.bin"))
        try Data(repeating: 0x63, count: 2).write(to: logsURL.appendingPathComponent("log.bin"))

        let estimate = CacheAnalyzer(directories: [logsURL, cachesURL]).estimate()

        XCTAssertEqual(estimate.totalBytes, 10)
        XCTAssertEqual(estimate.entries.map(\.path), [cachesURL.path, logsURL.path])
        XCTAssertEqual(estimate.entries.map(\.bytes), [8, 2])
        XCTAssertEqual(estimate.statusText, "User-cache estimate")
    }

    func testDiskIOHistoryComputesTwentyFourHourReadWriteDeltas() throws {
        let directory = try makeTemporaryDirectory()
        let store = DiskIOHistoryStore(storageURL: directory.appendingPathComponent("disk-io.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskIOTotalSnapshot(timestamp: now.addingTimeInterval(-24 * 3600), readBytes: 1_000, writeBytes: 2_000))
        try store.record(DiskIOTotalSnapshot(timestamp: now, readBytes: 3_500, writeBytes: 7_250))

        let summary = store.summary(now: now)

        XCTAssertEqual(summary.readBytes24h, 2_500)
        XCTAssertEqual(summary.writeBytes24h, 5_250)
        XCTAssertEqual(summary.statusText, "24h I/O history ready")
    }

    func testDiskIOHistoryReportsLearningForSparseTwentyFourHourBaseline() throws {
        let directory = try makeTemporaryDirectory()
        let store = DiskIOHistoryStore(storageURL: directory.appendingPathComponent("disk-io.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskIOTotalSnapshot(timestamp: now.addingTimeInterval(-40 * 3600), readBytes: 1_000, writeBytes: 2_000))
        try store.record(DiskIOTotalSnapshot(timestamp: now, readBytes: 3_500, writeBytes: 7_250))

        let summary = store.summary(now: now)

        XCTAssertNil(summary.readBytes24h)
        XCTAssertNil(summary.writeBytes24h)
        XCTAssertEqual(summary.statusText, "Learning: sparse 24h I/O history")
    }

    func testCacheGrowthStoreComputesTwentyFourHourCacheDelta() throws {
        let directory = try makeTemporaryDirectory()
        let store = CacheGrowthStore(storageURL: directory.appendingPathComponent("cache.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(CacheSnapshot(timestamp: now.addingTimeInterval(-24 * 3600), totalBytes: 2_000))
        try store.record(CacheSnapshot(timestamp: now, totalBytes: 3_500))

        let summary = store.summary(now: now)

        XCTAssertEqual(summary.growthBytes, 1_500)
        XCTAssertEqual(summary.statusText, "24h cache history ready")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeStore(in directory: URL) -> DiskGrowthStore {
        DiskGrowthStore(storageURL: directory.appendingPathComponent("disk.json"))
    }
}
