import Combine
import AppKit
import Foundation

private struct RefreshResult {
    var system: SystemSnapshot
    var diskGrowth: DiskGrowthSummary
    var cacheEstimate: CacheEstimate
    var launchCacheSnapshot: CacheSnapshot
    var codexQuota: CodexQuotaSnapshot
}

struct DashboardTrendSample: Equatable {
    var timestamp: Date
    var cpuUsage: Double?
    var memoryUsedPercent: Double?
    var diskUsedPercent: Double?
    var diskReadBytesPerSecond: UInt64?
    var diskWriteBytesPerSecond: UInt64?
    var diskIOActivityPercent: Double?
    var batteryPercent: Double?
    var codexRemainingPercent: Double?

    init(system: SystemSnapshot, codexQuota: CodexQuotaSnapshot) {
        self.timestamp = system.timestamp
        self.cpuUsage = system.cpuUsage
        self.memoryUsedPercent = system.memoryUsedPercent
        self.diskUsedPercent = system.diskCapacity.usedPercent
        self.diskReadBytesPerSecond = system.diskIO.readBytesPerSecond
        self.diskWriteBytesPerSecond = system.diskIO.writeBytesPerSecond
        if system.diskIO.readBytesPerSecond != nil || system.diskIO.writeBytesPerSecond != nil {
            let read = Double(system.diskIO.readBytesPerSecond ?? 0)
            let write = Double(system.diskIO.writeBytesPerSecond ?? 0)
            self.diskIOActivityPercent = min(((read + write) / (100 * 1_024 * 1_024)) * 100, 100)
        } else {
            self.diskIOActivityPercent = nil
        }
        self.batteryPercent = system.battery.percent
        self.codexRemainingPercent = codexQuota.remainingPercent
    }
}

private let maxDashboardTrendSampleCount = 60

private func buildRefreshResult(
    previousSystem: SystemSnapshot,
    launchSystem: SystemSnapshot,
    launchCacheSnapshot: CacheSnapshot?,
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
    }
    system.diskIO = enrichedDiskIO(
        currentSystem: system,
        previousSystem: previousSystem,
        launchSystem: launchSystem
    )

    let diskGrowth = diskGrowthSinceLaunch(launchSystem: launchSystem, currentSystem: system)
    var cacheEstimate = cacheAnalyzer.estimate()
    try? cacheStore.record(CacheSnapshot(timestamp: system.timestamp, totalBytes: cacheEstimate.totalBytes))
    let cacheBaseline = launchCacheSnapshot ?? CacheSnapshot(
        timestamp: system.timestamp,
        totalBytes: cacheEstimate.totalBytes
    )
    cacheEstimate = enrichedCacheEstimate(
        current: cacheEstimate,
        cacheBaseline: cacheBaseline,
        diskGrowth: diskGrowth
    )

    return RefreshResult(
        system: system,
        diskGrowth: diskGrowth,
        cacheEstimate: cacheEstimate,
        launchCacheSnapshot: cacheBaseline,
        codexQuota: codexReader.latestQuotaSnapshot()
    )
}

private func enrichedDiskIO(
    currentSystem: SystemSnapshot,
    previousSystem: SystemSnapshot,
    launchSystem: SystemSnapshot
) -> DiskIOSnapshot {
    let current = currentSystem.diskIO
    var readRate: UInt64?
    var writeRate: UInt64?
    let elapsed = previousSystem.timestamp.distance(to: currentSystem.timestamp)
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

    var readSinceLaunch: UInt64?
    var writeSinceLaunch: UInt64?
    var sourceDescription = "Disk I/O counters unavailable"
    if let totalRead = current.totalReadBytes,
       let totalWrite = current.totalWriteBytes,
       let launchRead = launchSystem.diskIO.totalReadBytes,
       let launchWrite = launchSystem.diskIO.totalWriteBytes {
        if totalRead >= launchRead, totalWrite >= launchWrite {
            readSinceLaunch = totalRead - launchRead
            writeSinceLaunch = totalWrite - launchWrite
            sourceDescription = "Since launch I/O ready"
        } else {
            sourceDescription = "Disk I/O counters reset"
        }
    }

    return DiskIOSnapshot(
        readBytesPerSecond: readRate,
        writeBytesPerSecond: writeRate,
        readBytes24h: readSinceLaunch,
        writeBytes24h: writeSinceLaunch,
        sourceDescription: sourceDescription,
        totalReadBytes: current.totalReadBytes,
        totalWriteBytes: current.totalWriteBytes
    )
}

private func diskGrowthSinceLaunch(
    launchSystem: SystemSnapshot,
    currentSystem: SystemSnapshot
) -> DiskGrowthSummary {
    let baseline = DiskSnapshot(
        timestamp: launchSystem.timestamp,
        availableBytes: launchSystem.diskCapacity.availableBytes,
        totalBytes: launchSystem.diskCapacity.totalBytes
    )
    let latest = DiskSnapshot(
        timestamp: currentSystem.timestamp,
        availableBytes: currentSystem.diskCapacity.availableBytes,
        totalBytes: currentSystem.diskCapacity.totalBytes
    )
    let growth = signedByteDifference(
        launchSystem.diskCapacity.availableBytes,
        currentSystem.diskCapacity.availableBytes
    )
    let observedHours = max(0, launchSystem.timestamp.distance(to: currentSystem.timestamp) / 3600)
    return DiskGrowthSummary(
        latest: latest,
        baseline: baseline,
        growthBytes: growth,
        observedHours: observedHours,
        statusText: "Since launch disk history ready"
    )
}

private func enrichedCacheEstimate(
    current: CacheEstimate,
    cacheBaseline: CacheSnapshot,
    diskGrowth: DiskGrowthSummary
) -> CacheEstimate {
    let cacheGrowthBytes = signedByteDifference(current.totalBytes, cacheBaseline.totalBytes)
    let share: Double?
    if let diskGrowthBytes = diskGrowth.growthBytes,
       cacheGrowthBytes > 0,
       diskGrowthBytes > 0 {
        share = min(Double(cacheGrowthBytes) / Double(diskGrowthBytes) * 100, 100)
    } else {
        share = nil
    }

    return CacheEstimate(
        totalBytes: current.totalBytes,
        growthBytes24h: cacheGrowthBytes,
        growthShareOfDiskGrowth: share,
        entries: current.entries,
        scannedAt: current.scannedAt,
        statusText: "Since launch cache history ready"
    )
}

private func signedByteDifference(_ first: UInt64, _ second: UInt64) -> Int64 {
    if first >= second {
        return Int64(clamping: first - second)
    }
    return -Int64(clamping: second - first)
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
    func clean() throws -> CacheCleanResult
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
    @Published private(set) var dashboardTrendSamples: [DashboardTrendSample]
    @Published private(set) var isCleaningCache = false

    private let systemMonitor: any SystemMonitoring
    private let diskStore: any DiskGrowthStoring
    private let diskIOStore: any DiskIOHistoryStoring
    private let cacheStore: any CacheGrowthStoring
    private let cacheAnalyzer: any CacheAnalyzing
    private let codexReader: any CodexQuotaReading
    private let refreshQueue: DispatchQueue
    private let launchSystem: SystemSnapshot
    private var launchCacheSnapshot: CacheSnapshot?
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
        let initialSystem = systemMonitor.snapshot(previousIO: nil)
        self.system = initialSystem
        self.launchSystem = initialSystem
        self.diskGrowth = diskGrowthSinceLaunch(launchSystem: initialSystem, currentSystem: initialSystem)
        self.cacheEstimate = CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "Not scanned yet")
        self.codexQuota = .unavailable
        self.dashboardTrendSamples = [DashboardTrendSample(system: initialSystem, codexQuota: .unavailable)]
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true

        let previousSystem = system
        let launchSystem = self.launchSystem
        let launchCacheSnapshot = self.launchCacheSnapshot
        let systemMonitor = self.systemMonitor
        let diskStore = self.diskStore
        let diskIOStore = self.diskIOStore
        let cacheStore = self.cacheStore
        let cacheAnalyzer = self.cacheAnalyzer
        let codexReader = self.codexReader

        refreshQueue.async { [weak self] in
            let result = buildRefreshResult(
                previousSystem: previousSystem,
                launchSystem: launchSystem,
                launchCacheSnapshot: launchCacheSnapshot,
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
                self.launchCacheSnapshot = result.launchCacheSnapshot
                self.codexQuota = result.codexQuota
                self.appendDashboardTrendSample(system: result.system, codexQuota: result.codexQuota)
                self.isRefreshing = false
            }
        }
    }

    func cleanCache() {
        guard !isCleaningCache else {
            return
        }
        isCleaningCache = true

        let previousSystem = system
        let launchSystem = self.launchSystem
        let systemMonitor = self.systemMonitor
        let diskStore = self.diskStore
        let diskIOStore = self.diskIOStore
        let cacheStore = self.cacheStore
        let cacheAnalyzer = self.cacheAnalyzer
        let codexReader = self.codexReader
        refreshQueue.async { [weak self] in
            let cleanResult: CacheCleanResult
            do {
                cleanResult = try cacheAnalyzer.clean()
            } catch {
                cleanResult = CacheCleanResult(
                    removedBytes: 0,
                    removedItemCount: 0,
                    failures: [CacheCleanResult.Failure(path: "Cache cleanup", message: error.localizedDescription)]
                )
            }

            var result = buildRefreshResult(
                previousSystem: previousSystem,
                launchSystem: launchSystem,
                launchCacheSnapshot: nil,
                systemMonitor: systemMonitor,
                diskStore: diskStore,
                diskIOStore: diskIOStore,
                cacheStore: cacheStore,
                cacheAnalyzer: cacheAnalyzer,
                codexReader: codexReader
            )
            let statusText = cleanResult.failures.isEmpty ? "Cache cleaned" : "Cache clean incomplete"
            result.cacheEstimate = CacheEstimate(
                totalBytes: result.cacheEstimate.totalBytes,
                growthBytes24h: 0,
                growthShareOfDiskGrowth: nil,
                entries: result.cacheEstimate.entries,
                scannedAt: result.cacheEstimate.scannedAt,
                statusText: statusText
            )

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                self.system = result.system
                self.diskGrowth = result.diskGrowth
                self.cacheEstimate = result.cacheEstimate
                self.launchCacheSnapshot = result.launchCacheSnapshot
                self.codexQuota = result.codexQuota
                self.appendDashboardTrendSample(system: result.system, codexQuota: result.codexQuota)
                self.isCleaningCache = false
            }
        }
    }

    private func appendDashboardTrendSample(system: SystemSnapshot, codexQuota: CodexQuotaSnapshot) {
        dashboardTrendSamples.append(DashboardTrendSample(system: system, codexQuota: codexQuota))
        if dashboardTrendSamples.count > maxDashboardTrendSampleCount {
            dashboardTrendSamples.removeFirst(dashboardTrendSamples.count - maxDashboardTrendSampleCount)
        }
    }

    func chooseCodexLogDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.message = "选择 ~/.codex 或 ~/.codex/sessions，以便 CodexPilot 在沙盒中读取 Codex 额度日志。"
        panel.prompt = "授权 / Authorize"

        let codexDirectory = CodexLogAccessStore.defaultCodexDirectoryURL()
        if FileManager.default.fileExists(atPath: codexDirectory.path) {
            panel.directoryURL = codexDirectory
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try CodexLogAccessStore.saveSelectedDirectory(url)
            refresh()
        } catch {
            codexQuota = CodexQuotaSnapshot(
                sourceDescription: "Codex log authorization failed",
                freshness: Date(),
                limitID: nil,
                usedPercent: nil,
                remainingPercent: nil,
                resetsAt: nil,
                windowMinutes: nil,
                planType: nil,
                creditsDescription: "Not reported",
                individualLimitDescription: error.localizedDescription,
                extraQuotaDescription: "Not reported",
                rateLimitReachedType: nil
            )
        }
    }
}
