import Foundation
import IOKit
import IOKit.ps
import MachO
import os

final class SystemMonitor: Sendable {
    struct CPUTicks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    struct MemorySample {
        var usedBytes: UInt64
        var totalBytes: UInt64

        var usedPercent: Double? {
            guard totalBytes > 0 else { return nil }
            return Double(usedBytes) / Double(totalBytes) * 100
        }
    }

    private let now: @Sendable () -> Date
    private let cpuTicksProvider: @Sendable () -> CPUTicks?
    private let memoryProvider: @Sendable () -> MemorySample?
    private let batteryProvider: @Sendable () -> BatterySnapshot
    private let diskCapacityProvider: @Sendable () -> DiskCapacity
    private let diskIOProvider: @Sendable () -> DiskIOTotalSnapshot?
    private let gpuProvider: @Sendable () -> Availability<GPUSnapshot>
    private let cpuTickHistory = LockedCPUTickHistory()

    convenience init() {
        self.init(
            now: { Date() },
            cpuTicksProvider: { Self.readCPUTicks() },
            memoryProvider: { Self.readMemorySample() },
            batteryProvider: { Self.readBatterySnapshot() },
            diskCapacityProvider: { Self.readDiskCapacity() },
            diskIOProvider: { Self.readDiskIOTotalSnapshot() },
            gpuProvider: { Self.readGPUSnapshot() }
        )
    }

    init(
        now: @escaping @Sendable () -> Date,
        cpuTicksProvider: @escaping @Sendable () -> CPUTicks?,
        memoryProvider: @escaping @Sendable () -> MemorySample?,
        batteryProvider: @escaping @Sendable () -> BatterySnapshot,
        diskCapacityProvider: @escaping @Sendable () -> DiskCapacity,
        diskIOProvider: @escaping @Sendable () -> DiskIOTotalSnapshot? = { nil },
        gpuProvider: @escaping @Sendable () -> Availability<GPUSnapshot>
    ) {
        self.now = now
        self.cpuTicksProvider = cpuTicksProvider
        self.memoryProvider = memoryProvider
        self.batteryProvider = batteryProvider
        self.diskCapacityProvider = diskCapacityProvider
        self.diskIOProvider = diskIOProvider
        self.gpuProvider = gpuProvider
    }

    func snapshot(previousIO: DiskIOSnapshot? = nil) -> SystemSnapshot {
        let capacity = diskCapacityProvider()
        let memory = memoryProvider()
        let timestamp = now()
        let ioTotals = diskIOProvider()
        return SystemSnapshot(
            timestamp: timestamp,
            cpuUsage: cpuUsage(),
            memoryUsedPercent: memory?.usedPercent,
            memoryUsedBytes: memory?.usedBytes,
            memoryTotalBytes: memory?.totalBytes,
            battery: batteryProvider(),
            diskCapacity: capacity,
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: ioTotals == nil ? "Disk I/O counters unavailable" : "IORegistry disk counters",
                totalReadBytes: ioTotals?.readBytes,
                totalWriteBytes: ioTotals?.writeBytes
            ),
            gpu: gpuProvider()
        )
    }

    private func cpuUsage() -> Double? {
        guard let delta = cpuTickHistory.sampleDelta(using: cpuTicksProvider) else {
            return nil
        }

        let userDelta = Double(delta.current.user) - Double(delta.previous.user)
        let systemDelta = Double(delta.current.system) - Double(delta.previous.system)
        let idleDelta = Double(delta.current.idle) - Double(delta.previous.idle)
        let niceDelta = Double(delta.current.nice) - Double(delta.previous.nice)
        let activeDelta = userDelta + systemDelta + niceDelta
        let totalDelta = activeDelta + idleDelta
        guard totalDelta > 0 else { return nil }
        return activeDelta / totalDelta * 100
    }

    private static func readCPUTicks() -> CPUTicks? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: load.cpu_ticks.0,
            system: load.cpu_ticks.1,
            idle: load.cpu_ticks.2,
            nice: load.cpu_ticks.3
        )
    }

    private static func readMemorySample() -> MemorySample? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return MemorySample(
            usedBytes: active + wired + compressed,
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    private static func readBatterySnapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            return BatterySnapshot(percent: nil, isCharging: nil, timeRemainingMinutes: nil, statusText: "No battery")
        }

        let current = description[kIOPSCurrentCapacityKey as String] as? Double
        let max = description[kIOPSMaxCapacityKey as String] as? Double
        let percent = current.flatMap { currentValue in
            max.flatMap { maxValue in maxValue > 0 ? currentValue / maxValue * 100 : nil }
        }
        let state = description[kIOPSPowerSourceStateKey as String] as? String
        let charging = state == kIOPSACPowerValue
        let minutes = description[kIOPSTimeToEmptyKey as String] as? Int
        return BatterySnapshot(percent: percent, isCharging: charging, timeRemainingMinutes: minutes, statusText: charging ? "Charging" : "On battery")
    }

    private static func readDiskCapacity() -> DiskCapacity {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let values = try? home.resourceValues(forKeys: keys)
        let total = UInt64(values?.volumeTotalCapacity ?? 0)
        let available = UInt64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return DiskCapacity(totalBytes: total, availableBytes: available)
    }

    private static func readDiskIOTotalSnapshot() -> DiskIOTotalSnapshot? {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            return nil
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var foundCounters = false

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 {
                break
            }
            defer { IOObjectRelease(service) }

            guard let property = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue(),
                  let statistics = property as? [String: Any] else {
                continue
            }

            if let read = uint64Value(statistics["Bytes (Read)"]) {
                totalRead += read
                foundCounters = true
            }
            if let write = uint64Value(statistics["Bytes (Write)"]) {
                totalWrite += write
                foundCounters = true
            }
        }

        guard foundCounters else {
            return nil
        }
        return DiskIOTotalSnapshot(timestamp: Date(), readBytes: totalRead, writeBytes: totalWrite)
    }

    private static func readGPUSnapshot() -> Availability<GPUSnapshot> {
        .unavailable("GPU utilization unavailable through stable public API")
    }

    private static func uint64Value(_ value: Any?) -> UInt64? {
        switch value {
        case let value as UInt64:
            return value
        case let value as UInt32:
            return UInt64(value)
        case let value as Int where value >= 0:
            return UInt64(value)
        case let value as NSNumber:
            return value.uint64Value
        default:
            return nil
        }
    }
}

private struct LockedCPUTickHistory: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: State())

    func sampleDelta(using provider: @Sendable () -> SystemMonitor.CPUTicks?) -> (previous: SystemMonitor.CPUTicks, current: SystemMonitor.CPUTicks)? {
        state.withLock { history in
            guard let current = provider() else {
                return nil
            }
            guard let previous = history.previous else {
                history.previous = current
                return nil
            }
            history.previous = current
            return (previous, current)
        }
    }

    private struct State {
        var previous: SystemMonitor.CPUTicks?
    }
}
