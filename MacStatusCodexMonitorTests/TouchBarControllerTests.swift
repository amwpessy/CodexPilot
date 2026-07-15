import AppKit
import XCTest
@testable import MacStatusCodexMonitor

@MainActor
final class TouchBarControllerTests: XCTestCase {
    func testTouchBarItemsReflectCurrentStateValues() {
        let system = SystemSnapshot(
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
        let diskGrowth = DiskGrowthSummary(
            latest: nil,
            baseline: nil,
            growthBytes: 1_536,
            observedHours: 24,
            statusText: "ready"
        )
        let quota = CodexQuotaSnapshot(
            sourceDescription: "local",
            freshness: system.timestamp,
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
            systemMonitor: StubTouchBarSystemMonitor(snapshot: system),
            diskStore: StubTouchBarDiskGrowthStore(growthSummary: diskGrowth),
            cacheAnalyzer: StubTouchBarCacheAnalyzer(),
            codexReader: StubTouchBarCodexQuotaReader(result: quota)
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
        XCTAssertEqual((diskItem?.view as? NSTextField)?.stringValue, "Disk +1.5 KB")
        XCTAssertEqual((batteryItem?.view as? NSTextField)?.stringValue, "Batt 88%")
        XCTAssertEqual((codexItem?.view as? NSTextField)?.stringValue, "Codex 75%")
    }
}

private struct StubTouchBarSystemMonitor: SystemMonitoring {
    var snapshot: SystemSnapshot

    func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot {
        snapshot
    }
}

private struct StubTouchBarDiskGrowthStore: DiskGrowthStoring {
    var growthSummary: DiskGrowthSummary

    func record(_ snapshot: DiskSnapshot) throws {}

    func growthSummary(now: Date) -> DiskGrowthSummary {
        growthSummary
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
