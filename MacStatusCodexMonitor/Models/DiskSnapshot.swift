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
    var entries: [Entry]
    var scannedAt: Date
    var statusText: String
}
