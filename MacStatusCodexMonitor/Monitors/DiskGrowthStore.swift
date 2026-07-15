import Foundation

struct DiskGrowthStore: Sendable {
    private let storageURL: URL
    private let retention: TimeInterval = 30 * 24 * 3600
    // Require a baseline close to the 24h target so sparse history cannot masquerade as a 24h delta.
    private let baselineTolerance: TimeInterval = 2 * 3600

    init(storageURL: URL = DiskGrowthStore.defaultStorageURL()) {
        self.storageURL = storageURL
    }

    func record(_ snapshot: DiskSnapshot) throws {
        var snapshots: [DiskSnapshot]
        do {
            snapshots = try loadSnapshotsOrThrow()
        } catch SnapshotLoadError.corruptStore {
            try quarantineCorruptStore()
            snapshots = []
        }

        snapshots.append(snapshot)

        let cutoff = snapshot.timestamp.addingTimeInterval(-retention)
        snapshots = snapshots
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.diskSnapshotEncoder.encode(snapshots)
        try data.write(to: storageURL, options: [.atomic])
    }

    func loadSnapshots() -> [DiskSnapshot] {
        guard let snapshots = try? loadSnapshotsOrThrow() else {
            return []
        }
        return snapshots
    }

    func growthSummary(now: Date) -> DiskGrowthSummary {
        let snapshots = loadSnapshots()
        guard let latest = snapshots.last else {
            return DiskGrowthSummary(
                latest: nil,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "No disk history yet"
            )
        }

        guard let earliest = snapshots.first else {
            return DiskGrowthSummary(
                latest: latest,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "No disk history yet"
            )
        }

        let target = now.addingTimeInterval(-24 * 3600)
        let observedHours = latest.timestamp.timeIntervalSince(earliest.timestamp) / 3600

        guard observedHours >= 24 else {
            return DiskGrowthSummary(
                latest: latest,
                baseline: earliest,
                growthBytes: nil,
                observedHours: observedHours,
                statusText: String(format: "Learning: %.1fh history", observedHours)
            )
        }

        guard let baseline = nearestBaseline(to: target, in: snapshots) else {
            return DiskGrowthSummary(
                latest: latest,
                baseline: nil,
                growthBytes: nil,
                observedHours: observedHours,
                statusText: "Learning: sparse 24h history"
            )
        }

        let growth = Int64(clamping: baseline.availableBytes) - Int64(clamping: latest.availableBytes)

        return DiskGrowthSummary(
            latest: latest,
            baseline: baseline,
            growthBytes: growth,
            observedHours: observedHours,
            statusText: "24h history ready"
        )
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MacStatusCodexMonitor/disk-snapshots.json")
    }

    private func loadSnapshotsOrThrow() throws -> [DiskSnapshot] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        do {
            let snapshots = try JSONDecoder.diskSnapshotDecoder.decode([DiskSnapshot].self, from: data)
            return snapshots.sorted { $0.timestamp < $1.timestamp }
        } catch {
            throw SnapshotLoadError.corruptStore(error)
        }
    }

    private func nearestBaseline(to target: Date, in snapshots: [DiskSnapshot]) -> DiskSnapshot? {
        let candidate = snapshots.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }

        guard let candidate,
              abs(candidate.timestamp.timeIntervalSince(target)) <= baselineTolerance else {
            return nil
        }

        return candidate
    }

    private func quarantineCorruptStore() throws {
        let backupURL = storageURL.appendingPathExtension("corrupt")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.moveItem(at: storageURL, to: backupURL)
    }
}

struct DiskIOHistoryStore: Sendable {
    private let storageURL: URL
    private let retention: TimeInterval = 30 * 24 * 3600
    private let baselineTolerance: TimeInterval = 2 * 3600

    init(storageURL: URL = DiskIOHistoryStore.defaultStorageURL()) {
        self.storageURL = storageURL
    }

    func record(_ snapshot: DiskIOTotalSnapshot) throws {
        var snapshots: [DiskIOTotalSnapshot]
        do {
            snapshots = try loadSnapshotsOrThrow()
        } catch SnapshotLoadError.corruptStore {
            try quarantineCorruptStore()
            snapshots = []
        }

        snapshots.append(snapshot)

        let cutoff = snapshot.timestamp.addingTimeInterval(-retention)
        snapshots = snapshots
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.diskSnapshotEncoder.encode(snapshots)
        try data.write(to: storageURL, options: [.atomic])
    }

    func loadSnapshots() -> [DiskIOTotalSnapshot] {
        guard let snapshots = try? loadSnapshotsOrThrow() else {
            return []
        }
        return snapshots
    }

    func summary(now: Date) -> DiskIOHistorySummary {
        let snapshots = loadSnapshots()
        guard let latest = snapshots.last else {
            return DiskIOHistorySummary(
                latest: nil,
                baseline: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                observedHours: 0,
                statusText: "No disk I/O history yet"
            )
        }

        guard let earliest = snapshots.first else {
            return DiskIOHistorySummary(
                latest: latest,
                baseline: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                observedHours: 0,
                statusText: "No disk I/O history yet"
            )
        }

        let target = now.addingTimeInterval(-24 * 3600)
        let observedHours = latest.timestamp.timeIntervalSince(earliest.timestamp) / 3600

        guard observedHours >= 24 else {
            return DiskIOHistorySummary(
                latest: latest,
                baseline: earliest,
                readBytes24h: nil,
                writeBytes24h: nil,
                observedHours: observedHours,
                statusText: String(format: "Learning: %.1fh I/O history", observedHours)
            )
        }

        guard let baseline = nearestBaseline(to: target, in: snapshots) else {
            return DiskIOHistorySummary(
                latest: latest,
                baseline: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                observedHours: observedHours,
                statusText: "Learning: sparse 24h I/O history"
            )
        }

        guard latest.readBytes >= baseline.readBytes,
              latest.writeBytes >= baseline.writeBytes else {
            return DiskIOHistorySummary(
                latest: latest,
                baseline: baseline,
                readBytes24h: nil,
                writeBytes24h: nil,
                observedHours: observedHours,
                statusText: "Disk I/O counters reset"
            )
        }

        return DiskIOHistorySummary(
            latest: latest,
            baseline: baseline,
            readBytes24h: latest.readBytes - baseline.readBytes,
            writeBytes24h: latest.writeBytes - baseline.writeBytes,
            observedHours: observedHours,
            statusText: "24h I/O history ready"
        )
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MacStatusCodexMonitor/disk-io-history.json")
    }

    private func loadSnapshotsOrThrow() throws -> [DiskIOTotalSnapshot] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        do {
            let snapshots = try JSONDecoder.diskSnapshotDecoder.decode([DiskIOTotalSnapshot].self, from: data)
            return snapshots.sorted { $0.timestamp < $1.timestamp }
        } catch {
            throw SnapshotLoadError.corruptStore(error)
        }
    }

    private func nearestBaseline(to target: Date, in snapshots: [DiskIOTotalSnapshot]) -> DiskIOTotalSnapshot? {
        let candidate = snapshots.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }

        guard let candidate,
              abs(candidate.timestamp.timeIntervalSince(target)) <= baselineTolerance else {
            return nil
        }

        return candidate
    }

    private func quarantineCorruptStore() throws {
        let backupURL = storageURL.appendingPathExtension("corrupt")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.moveItem(at: storageURL, to: backupURL)
    }
}

struct CacheGrowthStore: Sendable {
    private let storageURL: URL
    private let retention: TimeInterval = 30 * 24 * 3600
    private let baselineTolerance: TimeInterval = 2 * 3600

    init(storageURL: URL = CacheGrowthStore.defaultStorageURL()) {
        self.storageURL = storageURL
    }

    func record(_ snapshot: CacheSnapshot) throws {
        var snapshots: [CacheSnapshot]
        do {
            snapshots = try loadSnapshotsOrThrow()
        } catch SnapshotLoadError.corruptStore {
            try quarantineCorruptStore()
            snapshots = []
        }

        snapshots.append(snapshot)

        let cutoff = snapshot.timestamp.addingTimeInterval(-retention)
        snapshots = snapshots
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.diskSnapshotEncoder.encode(snapshots)
        try data.write(to: storageURL, options: [.atomic])
    }

    func summary(now: Date) -> CacheGrowthSummary {
        let snapshots = loadSnapshots()
        guard let latest = snapshots.last else {
            return CacheGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "No cache history yet")
        }
        guard let earliest = snapshots.first else {
            return CacheGrowthSummary(latest: latest, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "No cache history yet")
        }

        let target = now.addingTimeInterval(-24 * 3600)
        let observedHours = latest.timestamp.timeIntervalSince(earliest.timestamp) / 3600
        guard observedHours >= 24 else {
            return CacheGrowthSummary(
                latest: latest,
                baseline: earliest,
                growthBytes: nil,
                observedHours: observedHours,
                statusText: String(format: "Learning: %.1fh cache history", observedHours)
            )
        }

        guard let baseline = nearestBaseline(to: target, in: snapshots) else {
            return CacheGrowthSummary(
                latest: latest,
                baseline: nil,
                growthBytes: nil,
                observedHours: observedHours,
                statusText: "Learning: sparse 24h cache history"
            )
        }

        return CacheGrowthSummary(
            latest: latest,
            baseline: baseline,
            growthBytes: Int64(clamping: latest.totalBytes) - Int64(clamping: baseline.totalBytes),
            observedHours: observedHours,
            statusText: "24h cache history ready"
        )
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MacStatusCodexMonitor/cache-snapshots.json")
    }

    private func loadSnapshots() -> [CacheSnapshot] {
        guard let snapshots = try? loadSnapshotsOrThrow() else {
            return []
        }
        return snapshots
    }

    private func loadSnapshotsOrThrow() throws -> [CacheSnapshot] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        do {
            let snapshots = try JSONDecoder.diskSnapshotDecoder.decode([CacheSnapshot].self, from: data)
            return snapshots.sorted { $0.timestamp < $1.timestamp }
        } catch {
            throw SnapshotLoadError.corruptStore(error)
        }
    }

    private func nearestBaseline(to target: Date, in snapshots: [CacheSnapshot]) -> CacheSnapshot? {
        let candidate = snapshots.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }

        guard let candidate,
              abs(candidate.timestamp.timeIntervalSince(target)) <= baselineTolerance else {
            return nil
        }

        return candidate
    }

    private func quarantineCorruptStore() throws {
        let backupURL = storageURL.appendingPathExtension("corrupt")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.moveItem(at: storageURL, to: backupURL)
    }
}

private enum SnapshotLoadError: Error {
    case corruptStore(Error)
}

private extension JSONEncoder {
    static var diskSnapshotEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var diskSnapshotDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
