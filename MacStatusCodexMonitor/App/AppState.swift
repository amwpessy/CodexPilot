import Combine
import Foundation

private struct RefreshResult {
    var system: SystemSnapshot
    var diskGrowth: DiskGrowthSummary
    var cacheEstimate: CacheEstimate
    var codexQuota: CodexQuotaSnapshot
}

private func buildRefreshResult(
    previousSystem: SystemSnapshot,
    systemMonitor: any SystemMonitoring,
    diskStore: any DiskGrowthStoring,
    diskIOStore: any DiskIOHistoryStoring,
    cacheStore: any CacheGrowthStoring,
    cacheAnalyzer: any CacheAnalyzing,
    codexReader: any CodexQuotaReading
) -> RefreshResult {
    var system = systemMonitor.snapshot(previousIO: previousSystem.diskIO)
    let diskSnapshot = DiskSnapshot(
        timestamp: system.timestamp,
        availableBytes: system.diskCapacity.availableBytes,
        totalBytes: system.diskCapacity.totalBytes
    )
    try? diskStore.record(diskSnapshot)

    if let totalRead = system.diskIO.totalReadBytes,
       let totalWrite = system.diskIO.totalWriteBytes {
        let ioSnapshot = DiskIOTotalSnapshot(
            timestamp: system.timestamp,
            readBytes: totalRead,
            writeBytes: totalWrite
        )
        try? diskIOStore.record(ioSnapshot)
        let summary = diskIOStore.summary(now: system.timestamp)
        system.diskIO = enrichedDiskIO(
            current: system.diskIO,
            previousSystem: previousSystem,
            summary: summary
        )
    }

    let diskGrowth = diskStore.growthSummary(now: system.timestamp)
    var cacheEstimate = cacheAnalyzer.estimate()
    try? cacheStore.record(CacheSnapshot(timestamp: system.timestamp, totalBytes: cacheEstimate.totalBytes))
    let cacheGrowth = cacheStore.summary(now: system.timestamp)
    cacheEstimate = enrichedCacheEstimate(
        current: cacheEstimate,
        cacheGrowth: cacheGrowth,
        diskGrowth: diskGrowth
    )

    return RefreshResult(
        system: system,
        diskGrowth: diskGrowth,
        cacheEstimate: cacheEstimate,
        codexQuota: codexReader.latestQuotaSnapshot()
    )
}

private func enrichedDiskIO(
    current: DiskIOSnapshot,
    previousSystem: SystemSnapshot,
    summary: DiskIOHistorySummary
) -> DiskIOSnapshot {
    var readRate: UInt64?
    var writeRate: UInt64?
    let elapsed = previousSystem.timestamp.distance(to: summary.latest?.timestamp ?? previousSystem.timestamp)
    if elapsed > 0,
       let totalRead = current.totalReadBytes,
       let totalWrite = current.totalWriteBytes,
       let previousRead = previousSystem.diskIO.totalReadBytes,
       let previousWrite = previousSystem.diskIO.totalWriteBytes,
       totalRead >= previousRead,
       totalWrite >= previousWrite {
        readRate = UInt64(Double(totalRead - previousRead) / elapsed)
        writeRate = UInt64(Double(totalWrite - previousWrite) / elapsed)
    }

    return DiskIOSnapshot(
        readBytesPerSecond: readRate,
        writeBytesPerSecond: writeRate,
        readBytes24h: summary.readBytes24h,
        writeBytes24h: summary.writeBytes24h,
        sourceDescription: summary.statusText,
        totalReadBytes: current.totalReadBytes,
        totalWriteBytes: current.totalWriteBytes
    )
}

private func enrichedCacheEstimate(
    current: CacheEstimate,
    cacheGrowth: CacheGrowthSummary,
    diskGrowth: DiskGrowthSummary
) -> CacheEstimate {
    let share: Double?
    if let cacheGrowthBytes = cacheGrowth.growthBytes,
       let diskGrowthBytes = diskGrowth.growthBytes,
       cacheGrowthBytes > 0,
       diskGrowthBytes > 0 {
        share = min(Double(cacheGrowthBytes) / Double(diskGrowthBytes) * 100, 100)
    } else {
        share = nil
    }

    return CacheEstimate(
        totalBytes: current.totalBytes,
        growthBytes24h: cacheGrowth.growthBytes,
        growthShareOfDiskGrowth: share,
        entries: current.entries,
        scannedAt: current.scannedAt,
        statusText: cacheGrowth.statusText
    )
}

protocol SystemMonitoring: Sendable {
    func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot
}

protocol DiskGrowthStoring: Sendable {
    func record(_ snapshot: DiskSnapshot) throws
    func growthSummary(now: Date) -> DiskGrowthSummary
}

protocol DiskIOHistoryStoring: Sendable {
    func record(_ snapshot: DiskIOTotalSnapshot) throws
    func summary(now: Date) -> DiskIOHistorySummary
}

protocol CacheGrowthStoring: Sendable {
    func record(_ snapshot: CacheSnapshot) throws
    func summary(now: Date) -> CacheGrowthSummary
}

protocol CacheAnalyzing: Sendable {
    func estimate() -> CacheEstimate
}

protocol CodexQuotaReading: Sendable {
    func latestQuotaSnapshot() -> CodexQuotaSnapshot
}

extension SystemMonitor: SystemMonitoring {}
extension DiskGrowthStore: DiskGrowthStoring {}
extension DiskIOHistoryStore: DiskIOHistoryStoring {}
extension CacheGrowthStore: CacheGrowthStoring {}
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
    private let diskIOStore: any DiskIOHistoryStoring
    private let cacheStore: any CacheGrowthStoring
    private let cacheAnalyzer: any CacheAnalyzing
    private let codexReader: any CodexQuotaReading
    private let refreshQueue: DispatchQueue
    private var isRefreshing = false

    init(systemMonitor: any SystemMonitoring = SystemMonitor(),
         diskStore: any DiskGrowthStoring = DiskGrowthStore(),
         diskIOStore: any DiskIOHistoryStoring = DiskIOHistoryStore(),
         cacheStore: any CacheGrowthStoring = CacheGrowthStore(),
         cacheAnalyzer: any CacheAnalyzing = CacheAnalyzer(),
         codexReader: any CodexQuotaReading = CodexQuotaReader(),
         refreshQueue: DispatchQueue = DispatchQueue(label: "MacStatusCodexMonitor.AppState.refresh", qos: .utility)) {
        self.systemMonitor = systemMonitor
        self.diskStore = diskStore
        self.diskIOStore = diskIOStore
        self.cacheStore = cacheStore
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

        let previousSystem = system
        let systemMonitor = self.systemMonitor
        let diskStore = self.diskStore
        let diskIOStore = self.diskIOStore
        let cacheStore = self.cacheStore
        let cacheAnalyzer = self.cacheAnalyzer
        let codexReader = self.codexReader

        refreshQueue.async { [weak self] in
            let result = buildRefreshResult(
                previousSystem: previousSystem,
                systemMonitor: systemMonitor,
                diskStore: diskStore,
                diskIOStore: diskIOStore,
                cacheStore: cacheStore,
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
