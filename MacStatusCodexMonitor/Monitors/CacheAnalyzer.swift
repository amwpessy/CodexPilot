import Foundation

struct CacheAnalyzer: Sendable {
    private let directories: [URL]
    private let cleanableDirectories: [URL]

    init(
        directories: [URL] = CacheAnalyzer.defaultDirectories(),
        cleanableDirectories: [URL] = CacheAnalyzer.defaultCleanableDirectories()
    ) {
        self.directories = directories
        self.cleanableDirectories = cleanableDirectories
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

    func clean() throws -> CacheCleanResult {
        let fileManager = FileManager.default
        var removedBytes: UInt64 = 0
        var removedItemCount = 0
        var failures: [CacheCleanResult.Failure] = []

        for directory in cleanableDirectories {
            guard fileManager.fileExists(atPath: directory.path) else {
                continue
            }

            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: []
                )
            } catch {
                failures.append(CacheCleanResult.Failure(path: directory.path, message: error.localizedDescription))
                continue
            }

            for item in contents {
                let bytes = itemSize(item)
                do {
                    try fileManager.removeItem(at: item)
                    removedBytes += bytes
                    removedItemCount += 1
                } catch {
                    failures.append(CacheCleanResult.Failure(path: item.path, message: error.localizedDescription))
                }
            }
        }

        return CacheCleanResult(
            removedBytes: removedBytes,
            removedItemCount: removedItemCount,
            failures: failures
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

    private func itemSize(_ url: URL) -> UInt64 {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
           values.isRegularFile == true,
           let size = values.fileSize {
            return UInt64(max(0, size))
        }
        return directorySize(url)
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

    static func defaultCleanableDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
        ]
    }
}
