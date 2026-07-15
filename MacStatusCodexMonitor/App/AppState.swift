import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var system: SystemSnapshot
    @Published private(set) var diskGrowth: DiskGrowthSummary
    @Published private(set) var cacheEstimate: CacheEstimate
    @Published private(set) var codexQuota: CodexQuotaSnapshot

    private let systemMonitor: SystemMonitor
    private let diskStore: DiskGrowthStore
    private let cacheAnalyzer: CacheAnalyzer
    private let codexReader: CodexQuotaReader

    init(systemMonitor: SystemMonitor = SystemMonitor(),
         diskStore: DiskGrowthStore = DiskGrowthStore(),
         cacheAnalyzer: CacheAnalyzer = CacheAnalyzer(),
         codexReader: CodexQuotaReader = CodexQuotaReader()) {
        self.systemMonitor = systemMonitor
        self.diskStore = diskStore
        self.cacheAnalyzer = cacheAnalyzer
        self.codexReader = codexReader
        self.system = systemMonitor.snapshot()
        self.diskGrowth = diskStore.growthSummary(now: Date())
        self.cacheEstimate = CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "Not scanned yet")
        self.codexQuota = .unavailable
    }

    func refresh() {
        let snapshot = systemMonitor.snapshot(previousIO: system.diskIO)
        system = snapshot
        let diskSnapshot = DiskSnapshot(
            timestamp: snapshot.timestamp,
            availableBytes: snapshot.diskCapacity.availableBytes,
            totalBytes: snapshot.diskCapacity.totalBytes
        )
        try? diskStore.record(diskSnapshot)
        diskGrowth = diskStore.growthSummary(now: snapshot.timestamp)
        cacheEstimate = cacheAnalyzer.estimate()
        codexQuota = codexReader.latestQuotaSnapshot()
    }
}
