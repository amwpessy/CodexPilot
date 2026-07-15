import Foundation

struct DiskSnapshot: Codable, Equatable {
    var timestamp: Date
    var availableBytes: UInt64
    var totalBytes: UInt64
}

struct DiskGrowthSummary: Equatable {
    var latest: DiskSnapshot?
    var baseline: DiskSnapshot?
    var growthBytes: Int64?
    var observedHours: Double
    var statusText: String
}

struct CacheEstimate: Equatable {
    struct Entry: Equatable, Identifiable {
        var id: String { path }
        var path: String
        var bytes: UInt64
    }

    var totalBytes: UInt64
    var growthBytes24h: Int64?
    var growthShareOfDiskGrowth: Double?
    var entries: [Entry]
    var scannedAt: Date
    var statusText: String

    init(
        totalBytes: UInt64,
        growthBytes24h: Int64? = nil,
        growthShareOfDiskGrowth: Double? = nil,
        entries: [Entry],
        scannedAt: Date,
        statusText: String
    ) {
        self.totalBytes = totalBytes
        self.growthBytes24h = growthBytes24h
        self.growthShareOfDiskGrowth = growthShareOfDiskGrowth
        self.entries = entries
        self.scannedAt = scannedAt
        self.statusText = statusText
    }
}

struct CacheSnapshot: Codable, Equatable {
    var timestamp: Date
    var totalBytes: UInt64
}

struct CacheGrowthSummary: Equatable {
    var latest: CacheSnapshot?
    var baseline: CacheSnapshot?
    var growthBytes: Int64?
    var observedHours: Double
    var statusText: String
}
