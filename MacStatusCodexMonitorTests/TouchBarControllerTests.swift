import AppKit
import XCTest
@testable import MacStatusCodexMonitor

@MainActor
final class TouchBarControllerTests: XCTestCase {
    func testTouchBarItemsStartUnavailableThenRefreshLiveValues() async {
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
            cacheAnalyzer: StubTouchBarCacheAnalyzer(),
            codexReader: StubTouchBarCodexQuotaReader(result: quota),
            refreshQueue: DispatchQueue(label: "TouchBarControllerTests.refresh")
        )

        let controller = TouchBarController(state: state)
        let touchBar = controller.makeTouchBar()

        let cpuItem = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.cpu) as? NSCustomTouchBarItem
        let memoryItem = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.memory) as? NSCustomTouchBarItem
        let diskItem = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.disk) as? NSCustomTouchBarItem
        let batteryItem = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.battery) as? NSCustomTouchBarItem
        let codexItem = controller.touchBar(touchBar, makeItemForIdentifier: TouchBarController.codex) as? NSCustomTouchBarItem

        XCTAssertEqual((cpuItem?.view as? NSTextField)?.stringValue, "CPU 42%")
        XCTAssertEqual((memoryItem?.view as? NSTextField)?.stringValue, "Mem 67%")
        XCTAssertEqual((diskItem?.view as? NSTextField)?.stringValue, "Disk Learning")
        XCTAssertEqual((batteryItem?.view as? NSTextField)?.stringValue, "Batt 88%")
        XCTAssertEqual((codexItem?.view as? NSTextField)?.stringValue, "Codex Not reported")

        state.refresh()

        await waitForLabel(codexItem?.view as? NSTextField, toEqual: "Codex 75%")

        XCTAssertEqual((cpuItem?.view as? NSTextField)?.stringValue, "CPU 84%")
        XCTAssertEqual((memoryItem?.view as? NSTextField)?.stringValue, "Mem 73%")
        XCTAssertEqual((diskItem?.view as? NSTextField)?.stringValue, "Disk +1.5 KB")
        XCTAssertEqual((batteryItem?.view as? NSTextField)?.stringValue, "Batt 91%")
    }

    private func waitForLabel(_ label: NSTextField?, toEqual expected: String, timeout: TimeInterval = 2.0) async {
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if label?.stringValue == expected {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for label to become \(expected). Current value: \(label?.stringValue ?? "nil")")
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
