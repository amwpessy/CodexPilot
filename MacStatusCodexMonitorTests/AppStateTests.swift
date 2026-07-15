import AppKit
import XCTest
@testable import MacStatusCodexMonitor

@MainActor
final class AppStateTests: XCTestCase {
    func testMenuBarClickActivatesAppWhenOpeningPopover() {
        let activated = expectation(description: "activated")
        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 10)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            cacheStore: StubCacheGrowthStore(summaryResult: CacheGrowthSummary(
                latest: nil,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "cache"
            )),
            cacheAnalyzer: StubCacheAnalyzer(result: CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")),
            codexReader: StubCodexQuotaReader(result: CodexQuotaSnapshot(
                sourceDescription: "Not reported",
                freshness: nil,
                limitID: nil,
                usedPercent: nil,
                remainingPercent: nil,
                resetsAt: nil,
                windowMinutes: nil,
                planType: nil,
                creditsDescription: "Not reported",
                individualLimitDescription: "Not reported",
                rateLimitReachedType: nil
            ))
        )
        let delegate = AppDelegate(state: state, appActivationSink: {
            activated.fulfill()
        })

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.perform(NSSelectorFromString("togglePopover"))

        wait(for: [activated], timeout: 1.0)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }

    func testAppDelegateUpdatesMenuBarTitleWithSingleMetricProgressAfterAsyncRefreshPublishes() async {
        let refreshedSnapshot = makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 20), cpuUsage: 40)
        let refreshedQuota = CodexQuotaSnapshot(
            sourceDescription: "local",
            freshness: refreshedSnapshot.timestamp,
            limitID: "codex",
            usedPercent: 75,
            remainingPercent: 25,
            resetsAt: nil,
            windowMinutes: 60,
            planType: "team",
            creditsDescription: "Credits available",
            individualLimitDescription: "Not reported",
            rateLimitReachedType: nil
        )
        let titleUpdated = expectation(description: "titleUpdated")
        var observedTitles: [String] = []

        let state = AppState(
            systemMonitor: StubSystemMonitor(
                snapshots: [
                    makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 10),
                    refreshedSnapshot
                ]
            ),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            cacheStore: StubCacheGrowthStore(summaryResult: CacheGrowthSummary(
                latest: nil,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "cache"
            )),
            cacheAnalyzer: StubCacheAnalyzer(result: CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")),
            codexReader: StubCodexQuotaReader(result: refreshedQuota)
        )
        let delegate = AppDelegate(state: state, statusTitleSink: { title in
            observedTitles.append(title)
            if title == "CPU ▰▰▱▱▱ 40%" {
                titleUpdated.fulfill()
            }
        })

        delegate.observeStateForMenuBarTitle()
        state.refresh()

        await fulfillment(of: [titleUpdated], timeout: 2.0)

        XCTAssertEqual(observedTitles.last, "CPU ▰▰▱▱▱ 40%")
    }

    func testMenuBarTitleRotatesOneMetricAtATime() {
        let titleUpdated = expectation(description: "titleUpdated")
        titleUpdated.expectedFulfillmentCount = 2
        var observedTitles: [String] = []

        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 40)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            cacheStore: StubCacheGrowthStore(summaryResult: CacheGrowthSummary(
                latest: nil,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "cache"
            )),
            cacheAnalyzer: StubCacheAnalyzer(result: CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")),
            codexReader: StubCodexQuotaReader(result: CodexQuotaSnapshot(
                sourceDescription: "local",
                freshness: Date(timeIntervalSince1970: 10),
                limitID: "codex",
                usedPercent: 75,
                remainingPercent: 25,
                resetsAt: nil,
                windowMinutes: 60,
                planType: "team",
                creditsDescription: "Credits available",
                individualLimitDescription: "Not reported",
                rateLimitReachedType: nil
            ))
        )
        let delegate = AppDelegate(state: state, statusTitleSink: { title in
            observedTitles.append(title)
            if title == "CPU ▰▰▱▱▱ 40%" || title == "Mem ▰▰▰▱▱ 50%" {
                titleUpdated.fulfill()
            }
        })

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.advanceMenuBarStatusMetric()

        wait(for: [titleUpdated], timeout: 1.0)

        XCTAssertEqual(observedTitles.suffix(2), ["CPU ▰▰▱▱▱ 40%", "Mem ▰▰▰▱▱ 50%"])
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }

    func testRefreshRunsHeavyWorkOffMainActorAndPublishesSnapshot() async {
        let workRanOffMainActor = expectation(description: "workRanOffMainActor")
        workRanOffMainActor.expectedFulfillmentCount = 4

        let updated = expectation(description: "updated")
        let initialSnapshot = makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 10)
        let refreshedSnapshot = makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 20), cpuUsage: 40)
        let expectedGrowth = DiskGrowthSummary(
            latest: DiskSnapshot(timestamp: refreshedSnapshot.timestamp, availableBytes: 300, totalBytes: 1_000),
            baseline: nil,
            growthBytes: 25,
            observedHours: 2,
            statusText: "ready"
        )
        let expectedCache = CacheEstimate(
            totalBytes: 512,
            entries: [CacheEstimate.Entry(path: "/tmp/cache", bytes: 512)],
            scannedAt: refreshedSnapshot.timestamp,
            statusText: "cache"
        )
        let expectedQuota = CodexQuotaSnapshot(
            sourceDescription: "local",
            freshness: refreshedSnapshot.timestamp,
            limitID: "codex",
            usedPercent: 45,
            remainingPercent: 55,
            resetsAt: nil,
            windowMinutes: 60,
            planType: "team",
            creditsDescription: "Credits available",
            individualLimitDescription: "Not reported",
            rateLimitReachedType: nil
        )

        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [initialSnapshot, refreshedSnapshot]) {
                XCTAssertFalse(Thread.isMainThread)
                workRanOffMainActor.fulfill()
            },
            diskStore: StubDiskGrowthStore(
                growthSummary: expectedGrowth,
                recordHook: { _ in
                    XCTAssertFalse(Thread.isMainThread)
                    workRanOffMainActor.fulfill()
                },
                growthHook: {
                    XCTAssertFalse(Thread.isMainThread)
                    workRanOffMainActor.fulfill()
                }
            ),
            cacheStore: StubCacheGrowthStore(summaryResult: CacheGrowthSummary(
                latest: nil,
                baseline: nil,
                growthBytes: nil,
                observedHours: 0,
                statusText: "cache"
            )),
            cacheAnalyzer: StubCacheAnalyzer(result: expectedCache) {
                XCTAssertFalse(Thread.isMainThread)
                workRanOffMainActor.fulfill()
            },
            codexReader: StubCodexQuotaReader(result: expectedQuota)
        )

        state.refresh()
        XCTAssertEqual(state.system.timestamp, initialSnapshot.timestamp)

        Task {
            while true {
                if state.system.timestamp == refreshedSnapshot.timestamp {
                    updated.fulfill()
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        await fulfillment(of: [workRanOffMainActor, updated], timeout: 2.0)

        XCTAssertEqual(state.system.timestamp, refreshedSnapshot.timestamp)
        XCTAssertEqual(state.system.cpuUsage ?? -1, 40, accuracy: 0.001)
        XCTAssertEqual(state.diskGrowth, expectedGrowth)
        XCTAssertEqual(state.cacheEstimate, expectedCache)
        XCTAssertEqual(state.codexQuota.limitID, expectedQuota.limitID)
    }

    func testRefreshPublishesDiskIOHistoryAndRates() async {
        let updated = expectation(description: "updated")
        let initialSnapshot = makeSystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 10),
            cpuUsage: 10,
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "stub",
                totalReadBytes: 1_000,
                totalWriteBytes: 2_000
            )
        )
        let refreshedSnapshot = makeSystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 20),
            cpuUsage: 20,
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "stub",
                totalReadBytes: 1_600,
                totalWriteBytes: 2_900
            )
        )
        let ioSummary = DiskIOHistorySummary(
            latest: DiskIOTotalSnapshot(timestamp: refreshedSnapshot.timestamp, readBytes: 1_600, writeBytes: 2_900),
            baseline: DiskIOTotalSnapshot(timestamp: refreshedSnapshot.timestamp.addingTimeInterval(-24 * 3600), readBytes: 100, writeBytes: 500),
            readBytes24h: 1_500,
            writeBytes24h: 2_400,
            observedHours: 24,
            statusText: "24h I/O history ready"
        )

        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [initialSnapshot, refreshedSnapshot]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            diskIOStore: StubDiskIOHistoryStore(summary: ioSummary),
            cacheStore: StubCacheGrowthStore(),
            cacheAnalyzer: StubCacheAnalyzer(result: CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")),
            codexReader: StubCodexQuotaReader(result: .unavailable)
        )

        state.refresh()
        Task {
            while true {
                if state.system.timestamp == refreshedSnapshot.timestamp {
                    updated.fulfill()
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        await fulfillment(of: [updated], timeout: 2.0)

        XCTAssertEqual(state.system.diskIO.readBytes24h, 1_500)
        XCTAssertEqual(state.system.diskIO.writeBytes24h, 2_400)
        XCTAssertEqual(state.system.diskIO.readBytesPerSecond, 60)
        XCTAssertEqual(state.system.diskIO.writeBytesPerSecond, 90)
        XCTAssertEqual(state.system.diskIO.sourceDescription, "24h I/O history ready")
    }

    func testRefreshSkipsOverlappingWork() async {
        let workStarted = expectation(description: "workStarted")
        let releaseWork = expectation(description: "releaseWork")
        let gate = LockedGate()
        var refreshCalls = 0

        let state = AppState(
            systemMonitor: StubSystemMonitor(
                snapshots: [makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 1),
                            makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 20), cpuUsage: 2)]
            ) {
                refreshCalls += 1
                workStarted.fulfill()
                gate.wait()
            },
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            cacheStore: StubCacheGrowthStore(),
            cacheAnalyzer: StubCacheAnalyzer(result: CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "none")),
            codexReader: StubCodexQuotaReader(result: .unavailable)
        )

        state.refresh()
        await fulfillment(of: [workStarted], timeout: 2.0)

        state.refresh()
        gate.open()
        releaseWork.fulfill()

        await fulfillment(of: [releaseWork], timeout: 2.0)

        XCTAssertEqual(refreshCalls, 1)
    }

    private func makeSystemSnapshot(
        timestamp: Date,
        cpuUsage: Double?,
        diskIO: DiskIOSnapshot = DiskIOSnapshot(
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil,
            readBytes24h: nil,
            writeBytes24h: nil,
            sourceDescription: "stub"
        )
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: timestamp,
            cpuUsage: cpuUsage,
            memoryUsedPercent: 50,
            memoryUsedBytes: 512,
            memoryTotalBytes: 1_024,
            battery: BatterySnapshot(percent: 80, isCharging: true, timeRemainingMinutes: nil, statusText: "Charging"),
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 300),
            diskIO: diskIO,
            gpu: .unavailable("stub")
        )
    }
}

private final class StubSystemMonitor: SystemMonitoring {
    private let snapshots: LockedBox<[SystemSnapshot]>
    private let hook: @Sendable () -> Void

    init(snapshots: [SystemSnapshot], hook: @escaping @Sendable () -> Void = {}) {
        self.snapshots = LockedBox(snapshots)
        self.hook = hook
    }

    func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot {
        hook()
        return snapshots.withLock { $0.removeFirst() }
    }
}

private struct StubDiskGrowthStore: DiskGrowthStoring {
    var growthSummary: DiskGrowthSummary
    var recordHook: @Sendable (DiskSnapshot) throws -> Void = { _ in }
    var growthHook: @Sendable () -> Void = {}

    func record(_ snapshot: DiskSnapshot) throws {
        try recordHook(snapshot)
    }

    func growthSummary(now: Date) -> DiskGrowthSummary {
        growthHook()
        return growthSummary
    }
}

private struct StubDiskIOHistoryStore: DiskIOHistoryStoring {
    var summary: DiskIOHistorySummary
    var recordHook: @Sendable (DiskIOTotalSnapshot) throws -> Void = { _ in }

    func record(_ snapshot: DiskIOTotalSnapshot) throws {
        try recordHook(snapshot)
    }

    func summary(now: Date) -> DiskIOHistorySummary {
        summary
    }
}

private struct StubCacheGrowthStore: CacheGrowthStoring {
    var summaryResult = CacheGrowthSummary(
        latest: nil,
        baseline: nil,
        growthBytes: nil,
        observedHours: 0,
        statusText: "cache history"
    )
    var recordHook: @Sendable (CacheSnapshot) throws -> Void = { _ in }

    func record(_ snapshot: CacheSnapshot) throws {
        try recordHook(snapshot)
    }

    func summary(now: Date) -> CacheGrowthSummary {
        summaryResult
    }
}

private struct StubCacheAnalyzer: CacheAnalyzing {
    var result: CacheEstimate
    var hook: @Sendable () -> Void = {}

    func estimate() -> CacheEstimate {
        hook()
        return result
    }
}

private struct StubCodexQuotaReader: CodexQuotaReading {
    var result: CodexQuotaSnapshot

    func latestQuotaSnapshot() -> CodexQuotaSnapshot {
        result
    }
}

private final class LockedGate {
    private let semaphore = DispatchSemaphore(value: 0)

    func wait() {
        semaphore.wait()
    }

    func open() {
        semaphore.signal()
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ storage: Value) {
        self.storage = storage
    }

    @discardableResult
    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }
}
