import Foundation

struct CacheAnalyzer: Sendable {
    private let directories: [URL]

    init(directories: [URL] = CacheAnalyzer.defaultDirectories()) {
        self.directories = directories
    }

    func estimate() -> CacheEstimate {
        let entries = directories.compactMap { directory -> CacheEstimate.Entry? in
            let bytes = directorySize(directory)
            guard bytes > 0 else {
                return nil
            }

            return CacheEstimate.Entry(path: directory.path, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }

        let total = entries.reduce(UInt64(0)) { partialResult, entry in
            partialResult + entry.bytes
        }

        return CacheEstimate(
            totalBytes: total,
            entries: Array(entries.prefix(8)),
            scannedAt: Date(),
            statusText: "User-cache estimate"
        )
    }

    private func directorySize(_ url: URL) -> UInt64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else {
                continue
            }

            total += UInt64(max(0, size))
        }

        return total
    }

    static func defaultDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
        ]
    }
}
