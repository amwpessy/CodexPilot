import Foundation
import IOKit.ps
import MachO

final class SystemMonitor {
    func snapshot(previousIO: DiskIOSnapshot? = nil) -> SystemSnapshot {
        let capacity = diskCapacity()
        return SystemSnapshot(
            timestamp: Date(),
            cpuUsage: cpuUsage(),
            memoryUsedPercent: memoryUsedPercent(),
            memoryUsedBytes: memoryUsedBytes(),
            memoryTotalBytes: ProcessInfo.processInfo.physicalMemory,
            battery: batterySnapshot(),
            diskCapacity: capacity,
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "System I/O estimate unavailable in v1 collector"
            ),
            gpu: gpuSnapshot()
        )
    }

    private func cpuUsage() -> Double? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = Double(load.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return (total - idle) / total * 100
    }

    private func memoryUsedBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return active + wired + compressed
    }

    private func memoryUsedPercent() -> Double? {
        guard let used = memoryUsedBytes() else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return nil }
        return Double(used) / Double(total) * 100
    }

    private func batterySnapshot() -> BatterySnapshot {
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

    private func diskCapacity() -> DiskCapacity {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let values = try? home.resourceValues(forKeys: keys)
        let total = UInt64(values?.volumeTotalCapacity ?? 0)
        let available = UInt64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return DiskCapacity(totalBytes: total, availableBytes: available)
    }

    private func gpuSnapshot() -> Availability<GPUSnapshot> {
        .unavailable("GPU utilization unavailable through stable public API")
    }
}
