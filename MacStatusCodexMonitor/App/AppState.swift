import Combine
import Foundation

private struct RefreshResult {
    var system: SystemSnapshot
    var diskGrowth: DiskGrowthSummary
    var cacheEstimate: CacheEstimate
    var codexQuota: CodexQuotaSnapshot
}

private func buildRefreshResult(
    previousIO: DiskIOSnapshot,
    systemMonitor: any SystemMonitoring,
    diskStore: any DiskGrowthStoring,
    cacheAnalyzer: any CacheAnalyzing,
    codexReader: any CodexQuotaReading
) -> RefreshResult {
    let system = systemMonitor.snapshot(previousIO: previousIO)
    let diskSnapshot = DiskSnapshot(
        timestamp: system.timestamp,
        availableBytes: system.diskCapacity.availableBytes,
        totalBytes: system.diskCapacity.totalBytes
    )
    try? diskStore.record(diskSnapshot)

    return RefreshResult(
        system: system,
        diskGrowth: diskStore.growthSummary(now: system.timestamp),
        cacheEstimate: cacheAnalyzer.estimate(),
        codexQuota: codexReader.latestQuotaSnapshot()
    )
}

protocol SystemMonitoring: Sendable {
    func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot
}

protocol DiskGrowthStoring: Sendable {
    func record(_ snapshot: DiskSnapshot) throws
    func growthSummary(now: Date) -> DiskGrowthSummary
}

protocol CacheAnalyzing: Sendable {
    func estimate() -> CacheEstimate
}

protocol CodexQuotaReading: Sendable {
    func latestQuotaSnapshot() -> CodexQuotaSnapshot
}

extension SystemMonitor: SystemMonitoring {}
extension DiskGrowthStore: DiskGrowthStoring {}
extension CacheAnalyzer: CacheAnalyzing {}
extension CodexQuotaReader: CodexQuotaReading {}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var system: SystemSnapshot
    @Published private(set) var diskGrowth: DiskGrowthSummary
    @Published private(set) var cacheEstimate: CacheEstimate
    @Published private(set) var codexQuota: CodexQuotaSnapshot

    private let systemMonitor: any SystemMonitoring
    private let diskStore: any DiskGrowthStoring
    private let cacheAnalyzer: any CacheAnalyzing
    private let codexReader: any CodexQuotaReading
    private let refreshQueue: DispatchQueue
    private var isRefreshing = false

    init(systemMonitor: any SystemMonitoring = SystemMonitor(),
         diskStore: any DiskGrowthStoring = DiskGrowthStore(),
         cacheAnalyzer: any CacheAnalyzing = CacheAnalyzer(),
         codexReader: any CodexQuotaReading = CodexQuotaReader(),
         refreshQueue: DispatchQueue = DispatchQueue(label: "MacStatusCodexMonitor.AppState.refresh", qos: .utility)) {
        self.systemMonitor = systemMonitor
        self.diskStore = diskStore
        self.cacheAnalyzer = cacheAnalyzer
        self.codexReader = codexReader
        self.refreshQueue = refreshQueue
        self.system = systemMonitor.snapshot(previousIO: nil)
        self.diskGrowth = diskStore.growthSummary(now: Date())
        self.cacheEstimate = CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "Not scanned yet")
        self.codexQuota = .unavailable
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true

        let previousIO = system.diskIO
        let systemMonitor = self.systemMonitor
        let diskStore = self.diskStore
        let cacheAnalyzer = self.cacheAnalyzer
        let codexReader = self.codexReader

        refreshQueue.async { [weak self] in
            let result = buildRefreshResult(
                previousIO: previousIO,
                systemMonitor: systemMonitor,
                diskStore: diskStore,
                cacheAnalyzer: cacheAnalyzer,
                codexReader: codexReader
            )

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                self.system = result.system
                self.diskGrowth = result.diskGrowth
                self.cacheEstimate = result.cacheEstimate
                self.codexQuota = result.codexQuota
                self.isRefreshing = false
            }
        }
    }
}
