import Foundation

enum Availability<Value> {
    case available(Value)
    case unavailable(String)

    var value: Value? {
        if case let .available(value) = self { return value }
        return nil
    }

    var message: String? {
        if case let .unavailable(message) = self { return message }
        return nil
    }
}

struct SystemSnapshot {
    var timestamp: Date
    var cpuUsage: Double?
    var memoryUsedPercent: Double?
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var battery: BatterySnapshot
    var diskCapacity: DiskCapacity
    var diskIO: DiskIOSnapshot
    var gpu: Availability<GPUSnapshot>
}

struct BatterySnapshot {
    var percent: Double?
    var isCharging: Bool?
    var timeRemainingMinutes: Int?
    var statusText: String
}

struct DiskCapacity {
    var totalBytes: UInt64
    var availableBytes: UInt64

    var usedBytes: UInt64 {
        totalBytes > availableBytes ? totalBytes - availableBytes : 0
    }

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct DiskIOSnapshot {
    var readBytesPerSecond: UInt64?
    var writeBytesPerSecond: UInt64?
    var readBytes24h: UInt64?
    var writeBytes24h: UInt64?
    var sourceDescription: String
}

struct GPUSnapshot {
    var name: String
    var utilizationPercent: Double?
}
