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
        let memorySampleCount = LockedBox(0)
        let monitor = SystemMonitor(
            now: { Date(timeIntervalSince1970: 1_000) },
            cpuTicksProvider: { nil },
            memoryProvider: {
                memorySampleCount.withLock { $0 += 1 }
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

        XCTAssertEqual(memorySampleCount.value, 1)
        XCTAssertEqual(snapshot.memoryUsedBytes, 256)
        XCTAssertEqual(snapshot.memoryUsedPercent ?? -1, 25, accuracy: 0.001)
    }

    func testSnapshotSerializesCPUTickHistoryAcrossConcurrentCalls() {
        let metrics = LockedBox(ProviderMetrics())
        let sampleSource = LockedBox([
            SystemMonitor.CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            SystemMonitor.CPUTicks(user: 25, system: 0, idle: 75, nice: 0),
            SystemMonitor.CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
        ])
        let monitor = SystemMonitor(
            now: { Date(timeIntervalSince1970: 1_000) },
            cpuTicksProvider: {
                metrics.withLock {
                    $0.activeCalls += 1
                    $0.maxConcurrentCalls = max($0.maxConcurrentCalls, $0.activeCalls)
                }
                usleep(50_000)
                defer {
                    metrics.withLock { $0.activeCalls -= 1 }
                }
                return sampleSource.withLock { $0.removeFirst() }
            },
            memoryProvider: { nil },
            batteryProvider: {
                BatterySnapshot(percent: nil, isCharging: nil, timeRemainingMinutes: nil, statusText: "No battery")
            },
            diskCapacityProvider: {
                DiskCapacity(totalBytes: 2_048, availableBytes: 1_024)
            },
            gpuProvider: { .unavailable("stub") }
        )

        XCTAssertNil(monitor.snapshot().cpuUsage)

        let results = LockedBox([Double]())
        let group = DispatchGroup()

        for _ in 0..<2 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let value = monitor.snapshot().cpuUsage
                results.withLock { $0.append(value ?? -1) }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)

        let sortedResults = results.value.sorted()
        XCTAssertEqual(sortedResults.count, 2)
        guard sortedResults.count == 2 else {
            return
        }
        XCTAssertEqual(sortedResults[0], 25, accuracy: 0.001)
        XCTAssertEqual(sortedResults[1], 75, accuracy: 0.001)
        XCTAssertEqual(metrics.value.maxConcurrentCalls, 1)
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ storage: Value) {
        self.storage = storage
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    @discardableResult
    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }
}

private struct ProviderMetrics {
    var activeCalls = 0
    var maxConcurrentCalls = 0
}
