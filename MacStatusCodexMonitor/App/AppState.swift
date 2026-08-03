import Combine
import Foundation

private struct RefreshResult {
    var system: SystemSnapshot
    var diskGrowth: DiskGrowthSummary
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
    systemMonitor: any SystemMonitoring,
    diskStore: any DiskGrowthStoring,
    diskIOStore: any DiskIOHistoryStoring,
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

    return RefreshResult(
        system: system,
        diskGrowth: diskGrowth,
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

protocol CodexQuotaReading: Sendable {
    func latestQuotaSnapshot() -> CodexQuotaSnapshot
}

extension SystemMonitor: SystemMonitoring {}
extension DiskGrowthStore: DiskGrowthStoring {}
extension DiskIOHistoryStore: DiskIOHistoryStoring {}
extension CodexQuotaReader: CodexQuotaReading {}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var system: SystemSnapshot
    @Published private(set) var diskGrowth: DiskGrowthSummary
    @Published private(set) var codexQuota: CodexQuotaSnapshot
    @Published private(set) var dashboardTrendSamples: [DashboardTrendSample]
    let sessionStartedAt: Date

    private let systemMonitor: any SystemMonitoring
    private let diskStore: any DiskGrowthStoring
    private let diskIOStore: any DiskIOHistoryStoring
    private let codexReader: any CodexQuotaReading
    private let refreshQueue: DispatchQueue
    private let launchSystem: SystemSnapshot
    private var isRefreshing = false

    init(systemMonitor: any SystemMonitoring = SystemMonitor(),
         diskStore: any DiskGrowthStoring = DiskGrowthStore(),
         diskIOStore: any DiskIOHistoryStoring = DiskIOHistoryStore(),
         codexReader: any CodexQuotaReading = CodexQuotaReader(),
         refreshQueue: DispatchQueue = DispatchQueue(label: "MacStatusCodexMonitor.AppState.refresh", qos: .utility)) {
        self.systemMonitor = systemMonitor
        self.diskStore = diskStore
        self.diskIOStore = diskIOStore
        self.codexReader = codexReader
        self.refreshQueue = refreshQueue
        let initialSystem = systemMonitor.snapshot(previousIO: nil)
        self.system = initialSystem
        self.launchSystem = initialSystem
        self.sessionStartedAt = initialSystem.timestamp
        self.diskGrowth = diskGrowthSinceLaunch(launchSystem: initialSystem, currentSystem: initialSystem)
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
        let systemMonitor = self.systemMonitor
        let diskStore = self.diskStore
        let diskIOStore = self.diskIOStore
        let codexReader = self.codexReader

        refreshQueue.async { [weak self] in
            let result = buildRefreshResult(
                previousSystem: previousSystem,
                launchSystem: launchSystem,
                systemMonitor: systemMonitor,
                diskStore: diskStore,
                diskIOStore: diskIOStore,
                codexReader: codexReader
            )

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                self.system = result.system
                self.diskGrowth = result.diskGrowth
                self.codexQuota = result.codexQuota
                self.appendDashboardTrendSample(system: result.system, codexQuota: result.codexQuota)
                self.isRefreshing = false
            }
        }
    }

    private func appendDashboardTrendSample(system: SystemSnapshot, codexQuota: CodexQuotaSnapshot) {
        dashboardTrendSamples.append(DashboardTrendSample(system: system, codexQuota: codexQuota))
        if dashboardTrendSamples.count > maxDashboardTrendSampleCount {
            dashboardTrendSamples.removeFirst(dashboardTrendSamples.count - maxDashboardTrendSampleCount)
        }
    }

}
