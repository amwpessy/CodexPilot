import Foundation

final class DiskGrowthStore {
    private let storageURL: URL
    private let retention: TimeInterval = 30 * 24 * 3600

    init(storageURL: URL = DiskGrowthStore.defaultStorageURL()) {
        self.storageURL = storageURL
    }

    func record(_ snapshot: DiskSnapshot) throws {
        var snapshots = loadSnapshots()
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
        guard let data = try? Data(contentsOf: storageURL),
              let snapshots = try? JSONDecoder.diskSnapshotDecoder.decode([DiskSnapshot].self, from: data) else {
            return []
        }

        return snapshots.sorted { $0.timestamp < $1.timestamp }
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

        let baseline = snapshots.last(where: { $0.timestamp <= target }) ?? earliest
        let growth = Int64(baseline.availableBytes) - Int64(latest.availableBytes)

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
