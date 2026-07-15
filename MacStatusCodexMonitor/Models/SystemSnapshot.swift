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
    var totalReadBytes: UInt64?
    var totalWriteBytes: UInt64?

    init(
        readBytesPerSecond: UInt64?,
        writeBytesPerSecond: UInt64?,
        readBytes24h: UInt64?,
        writeBytes24h: UInt64?,
        sourceDescription: String,
        totalReadBytes: UInt64? = nil,
        totalWriteBytes: UInt64? = nil
    ) {
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.readBytes24h = readBytes24h
        self.writeBytes24h = writeBytes24h
        self.sourceDescription = sourceDescription
        self.totalReadBytes = totalReadBytes
        self.totalWriteBytes = totalWriteBytes
    }
}

struct DiskIOTotalSnapshot: Codable, Equatable {
    var timestamp: Date
    var readBytes: UInt64
    var writeBytes: UInt64
}

struct DiskIOHistorySummary: Equatable {
    var latest: DiskIOTotalSnapshot?
    var baseline: DiskIOTotalSnapshot?
    var readBytes24h: UInt64?
    var writeBytes24h: UInt64?
    var observedHours: Double
    var statusText: String
}

struct GPUSnapshot {
    var name: String
    var utilizationPercent: Double?
}
