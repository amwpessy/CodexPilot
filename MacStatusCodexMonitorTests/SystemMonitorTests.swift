import XCTest
@testable import MacStatusCodexMonitor

final class SystemMonitorTests: XCTestCase {
    func testSnapshotComputesCPUUsageFromSampleDeltas() {
        var samples = [
            SystemMonitor.CPUTicks(user: 100, system: 50, idle: 150, nice: 0),
            SystemMonitor.CPUTicks(user: 140, system: 70, idle: 190, nice: 0),
        ]

        let monitor = SystemMonitor(
            now: { Date(timeIntervalSince1970: 1_000) },
            cpuTicksProvider: { samples.removeFirst() },
            memoryProvider: {
                SystemMonitor.MemorySample(usedBytes: 512, totalBytes: 1_024)
            },
            batteryProvider: {
                BatterySnapshot(percent: nil, isCharging: nil, timeRemainingMinutes: nil, statusText: "No battery")
            },
            diskCapacityProvider: {
                DiskCapacity(totalBytes: 2_048, availableBytes: 1_024)
            },
            gpuProvider: { .unavailable("stub") }
        )

        let first = monitor.snapshot()
        let second = monitor.snapshot()

        XCTAssertNil(first.cpuUsage)
        XCTAssertEqual(second.cpuUsage ?? -1, 50, accuracy: 0.001)
    }

    func testSnapshotSamplesMemoryOncePerSnapshot() {
        var memorySampleCount = 0
        let monitor = SystemMonitor(
            now: { Date(timeIntervalSince1970: 1_000) },
            cpuTicksProvider: { nil },
            memoryProvider: {
                memorySampleCount += 1
                return SystemMonitor.MemorySample(usedBytes: 256, totalBytes: 1_024)
            },
            batteryProvider: {
                BatterySnapshot(percent: nil, isCharging: nil, timeRemainingMinutes: nil, statusText: "No battery")
            },
            diskCapacityProvider: {
                DiskCapacity(totalBytes: 2_048, availableBytes: 1_024)
            },
            gpuProvider: { .unavailable("stub") }
        )

        let snapshot = monitor.snapshot()

        XCTAssertEqual(memorySampleCount, 1)
        XCTAssertEqual(snapshot.memoryUsedBytes, 256)
        XCTAssertEqual(snapshot.memoryUsedPercent ?? -1, 25, accuracy: 0.001)
    }
}
