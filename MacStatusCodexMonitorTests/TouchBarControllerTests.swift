import AppKit
import XCTest
@testable import MacStatusCodexMonitor

@MainActor
final class TouchBarControllerTests: XCTestCase {
    func testTouchBarUsesPersistentPrincipalStatusStripWithColoredProgress() async {
        let initialSystem = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 10),
            cpuUsage: 42,
            memoryUsedPercent: 67,
            memoryUsedBytes: 512,
            memoryTotalBytes: 1_024,
            battery: BatterySnapshot(percent: 88, isCharging: false, timeRemainingMinutes: nil, statusText: "Battery"),
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 300),
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "stub"
            ),
            gpu: .unavailable("stub")
        )
        let refreshedSystem = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 20),
            cpuUsage: 84,
            memoryUsedPercent: 73,
            memoryUsedBytes: 768,
            memoryTotalBytes: 1_024,
            battery: BatterySnapshot(percent: 91, isCharging: true, timeRemainingMinutes: nil, statusText: "Charging"),
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 200),
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "stub"
            ),
            gpu: .unavailable("stub")
        )
        let initialDiskGrowth = DiskGrowthSummary(
            latest: nil,
            baseline: nil,
            growthBytes: nil,
            observedHours: 0,
            statusText: "learning"
        )
        let refreshedDiskGrowth = DiskGrowthSummary(
            latest: nil,
            baseline: nil,
            growthBytes: 1_536,
            observedHours: 24,
            statusText: "ready"
        )
        let quota = CodexQuotaSnapshot(
            sourceDescription: "local",
            freshness: refreshedSystem.timestamp,
            limitID: "codex",
            usedPercent: 25,
            remainingPercent: 75,
            resetsAt: nil,
            windowMinutes: 60,
            planType: "team",
            creditsDescription: "Credits available",
            individualLimitDescription: "Not reported",
            rateLimitReachedType: nil
        )
        let state = AppState(
            systemMonitor: StubTouchBarSystemMonitor(snapshots: [initialSystem, refreshedSystem]),
            diskStore: StubTouchBarDiskGrowthStore(growthSummaries: [initialDiskGrowth, refreshedDiskGrowth]),
            cacheStore: StubTouchBarCacheGrowthStore(),
            cacheAnalyzer: StubTouchBarCacheAnalyzer(),
            codexReader: StubTouchBarCodexQuotaReader(result: quota),
            refreshQueue: DispatchQueue(label: "TouchBarControllerTests.refresh")
        )

        let controller = TouchBarController(state: state)
        let touchBar = controller.makeTouchBar()

        XCTAssertEqual(touchBar.principalItemIdentifier, TouchBarController.statusStrip)
        XCTAssertEqual(touchBar.defaultItemIdentifiers, [TouchBarController.statusStrip])
        XCTAssertEqual(touchBar.customizationRequiredItemIdentifiers, [TouchBarController.statusStrip])

        let item = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.statusStrip) as? NSCustomTouchBarItem
        let strip = item?.view as? TouchBarStatusStripView

        XCTAssertEqual(strip?.labelText(for: .cpu), "CPU 42%")
        XCTAssertEqual(strip?.labelText(for: .memory), "Mem 67%")
        XCTAssertEqual(strip?.labelText(for: .disk), "Disk Learning")
        XCTAssertEqual(strip?.labelText(for: .battery), "Batt 88%")
        XCTAssertEqual(strip?.labelText(for: .codex), "Codex Not reported")
        assertProgress(strip, .cpu, equals: 0.42)
        assertProgress(strip, .memory, equals: 0.67)
        assertProgress(strip, .battery, equals: 0.88)
        XCTAssertEqual(strip?.barColor(for: .cpu), NSColor.systemBlue)
        XCTAssertEqual(strip?.barColor(for: .memory), NSColor.systemTeal)
        XCTAssertEqual(strip?.barColor(for: .codex), NSColor.systemRed)

        state.refresh()

        await waitForLabel(in: strip, metric: .codex, toEqual: "Codex 75%")

        XCTAssertEqual(strip?.labelText(for: .cpu), "CPU 84%")
        XCTAssertEqual(strip?.labelText(for: .memory), "Mem 73%")
        XCTAssertEqual(strip?.labelText(for: .disk), "Disk +1.5 KB")
        XCTAssertEqual(strip?.labelText(for: .battery), "Batt 91%")
        assertProgress(strip, .cpu, equals: 0.84)
        assertProgress(strip, .memory, equals: 0.73)
        assertProgress(strip, .disk, equals: 0.015)
        assertProgress(strip, .battery, equals: 0.91)
        assertProgress(strip, .codex, equals: 0.75)
        XCTAssertEqual(strip?.barColor(for: .battery), NSColor.systemGreen)
        XCTAssertEqual(strip?.barColor(for: .codex), NSColor.systemPurple)
    }

    private func assertProgress(
        _ strip: TouchBarStatusStripView?,
        _ metric: TouchBarMetric,
        equals expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = strip?.progress(for: metric) else {
            XCTFail("Missing progress for \(metric)", file: file, line: line)
            return
        }

        XCTAssertEqual(actual, expected, accuracy: 0.001, file: file, line: line)
    }

    private func waitForLabel(
        in strip: TouchBarStatusStripView?,
        metric: TouchBarMetric,
        toEqual expected: String,
        timeout: TimeInterval = 2.0
    ) async {
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if strip?.labelText(for: metric) == expected {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for label to become \(expected). Current value: \(strip?.labelText(for: metric) ?? "nil")")
    }
}

private final class StubTouchBarSystemMonitor: SystemMonitoring {
    private let snapshots: LockedTouchBarBox<[SystemSnapshot]>

    init(snapshots: [SystemSnapshot]) {
        self.snapshots = LockedTouchBarBox(snapshots)
    }

    func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot {
        snapshots.withLock { $0.removeFirst() }
    }
}

private final class StubTouchBarDiskGrowthStore: DiskGrowthStoring {
    private let growthSummaries: LockedTouchBarBox<[DiskGrowthSummary]>

    init(growthSummaries: [DiskGrowthSummary]) {
        self.growthSummaries = LockedTouchBarBox(growthSummaries)
    }

    func record(_ snapshot: DiskSnapshot) throws {}

    func growthSummary(now: Date) -> DiskGrowthSummary {
        growthSummaries.withLock { $0.removeFirst() }
    }
}

private struct StubTouchBarCacheGrowthStore: CacheGrowthStoring {
    func record(_ snapshot: CacheSnapshot) throws {}

    func summary(now: Date) -> CacheGrowthSummary {
        CacheGrowthSummary(
            latest: nil,
            baseline: nil,
            growthBytes: nil,
            observedHours: 0,
            statusText: "none"
        )
    }
}

private struct StubTouchBarCacheAnalyzer: CacheAnalyzing {
    func estimate() -> CacheEstimate {
        CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")
    }
}

private struct StubTouchBarCodexQuotaReader: CodexQuotaReading {
    var result: CodexQuotaSnapshot

    func latestQuotaSnapshot() -> CodexQuotaSnapshot {
        result
    }
}

private final class LockedTouchBarBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    @discardableResult
    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
