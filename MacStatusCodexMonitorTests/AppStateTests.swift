import AppKit
import XCTest
@testable import MacStatusCodexMonitor

@MainActor
final class AppStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "dashboardSportThemeEnabled")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "dashboardSportThemeEnabled")
        super.tearDown()
    }

    func testSessionUptimeFormatterReportsMinutesHoursAndDays() {
        let startedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            SessionUptimeFormatter.string(startedAt: startedAt, now: startedAt.addingTimeInterval(59)),
            "启动后计时 0分钟 / Session 0m"
        )
        XCTAssertEqual(
            SessionUptimeFormatter.string(startedAt: startedAt, now: startedAt.addingTimeInterval(2 * 3600 + 17 * 60)),
            "启动后计时 2小时 17分 / Session 2h 17m"
        )
        XCTAssertEqual(
            SessionUptimeFormatter.string(startedAt: startedAt, now: startedAt.addingTimeInterval(26 * 3600 + 3 * 60)),
            "启动后计时 1天 2小时 3分 / Session 1d 2h 3m"
        )
    }

    func testAppLaunchShowsDashboardAndActivatesApp() {
        let activated = expectation(description: "activated")
        activated.expectedFulfillmentCount = 2
        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 10),
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 30), cpuUsage: 12)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
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

        let originalWindow = delegate.dashboardWindowForTesting()
        XCTAssertNotNil(originalWindow)
        originalWindow?.orderOut(nil)
        XCTAssertFalse(originalWindow?.isVisible ?? true)

        delegate.showDashboard()

        wait(for: [activated], timeout: 1.0)
        XCTAssertTrue(delegate.dashboardWindowForTesting() === originalWindow)
        XCTAssertTrue(originalWindow?.isVisible ?? false)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }

    func testSportThemeSwitchesMonitoringRefreshIntervalToOneSecond() {
        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 10)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            codexReader: StubCodexQuotaReader(result: .unavailable)
        )
        let delegate = AppDelegate(state: state, appActivationSink: {})

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertEqual(delegate.monitoringRefreshIntervalForTesting(), 120)

        UserDefaults.standard.set(true, forKey: "dashboardSportThemeEnabled")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)

        let intervalUpdated = expectation(description: "intervalUpdated")
        DispatchQueue.main.async {
            XCTAssertEqual(delegate.monitoringRefreshIntervalForTesting(), 1)
            intervalUpdated.fulfill()
        }
        wait(for: [intervalUpdated], timeout: 1.0)
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
            codexReader: StubCodexQuotaReader(result: refreshedQuota)
        )
        let delegate = AppDelegate(state: state, statusTitleSink: { title in
            observedTitles.append(title)
            if title == "CPU 40%" {
                titleUpdated.fulfill()
            }
        })

        delegate.observeStateForMenuBarTitle()
        state.refresh()

        await fulfillment(of: [titleUpdated], timeout: 2.0)

        XCTAssertEqual(observedTitles.last, "CPU 40%")
        let menuSnapshot = delegate.currentMenuBarStatusSnapshot()
        XCTAssertEqual(menuSnapshot.title, "CPU 40%")
        XCTAssertEqual(menuSnapshot.progress, 0.4, accuracy: 0.001)
        XCTAssertEqual(menuSnapshot.color, .systemBlue)
    }

    func testMenuBarTitleRotatesOneMetricAtATime() {
        let titleUpdated = expectation(description: "titleUpdated")
        titleUpdated.expectedFulfillmentCount = 2
        var observedTitles: [String] = []

        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 40),
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 20), cpuUsage: 40)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
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
            if title == "CPU 40%" || title == "Mem 50%" {
                titleUpdated.fulfill()
            }
        })

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.advanceMenuBarStatusMetric()

        wait(for: [titleUpdated], timeout: 1.0)

        XCTAssertEqual(observedTitles.suffix(2), ["CPU 40%", "Mem 50%"])
        let menuSnapshot = delegate.currentMenuBarStatusSnapshot()
        XCTAssertEqual(menuSnapshot.title, "Mem 50%")
        XCTAssertEqual(menuSnapshot.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(menuSnapshot.color, .systemTeal)
        XCTAssertEqual(delegate.menuBarStatusItemLengthForTesting(), 69)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }

    func testMenuBarStatusViewShowsPercentAtExpandedWidth() {
        let view = MenuBarStatusProgressView(frame: NSRect(x: 0, y: 0, width: 59, height: 22))
        view.update(snapshot: MenuBarStatusSnapshot(
            title: "CPU 40%",
            label: "CPU",
            percentText: "40%",
            progress: 0.4,
            color: .systemBlue
        ))

        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.labelTextForTesting, "CPU")
        XCTAssertEqual(view.percentTextForTesting, "40%")
        XCTAssertTrue(view.isPercentVisibleForTesting)
    }

    func testMenuBarPopoverBuildsCockpitMetricCards() async {
        let refreshed = expectation(description: "refreshed")
        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [
                makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 40)
            ]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            codexReader: StubCodexQuotaReader(result: CodexQuotaSnapshot(
                sourceDescription: "local",
                freshness: Date(timeIntervalSince1970: 10),
                limitID: "codex",
                usedPercent: 25,
                remainingPercent: 75,
                resetsAt: nil,
                windowMinutes: 60,
                planType: "team",
                creditsDescription: "Credits available",
                individualLimitDescription: "Not reported",
                rateLimitReachedType: nil
            ))
        )

        state.refresh()
        Task {
            while true {
                if state.codexQuota.remainingPercent == 75 {
                    refreshed.fulfill()
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        await fulfillment(of: [refreshed], timeout: 2.0)

        let metrics = MenuBarPopoverView.cockpitMetrics(for: state)

        XCTAssertEqual(metrics.map(\.title), ["CPU", "Mem", "Disk", "Codex"])
        XCTAssertEqual(metrics.map(\.value), ["40%", "50%", "70%", "75%"])
        XCTAssertEqual(metrics.map(\.progress), [0.4, 0.5, 0.7, 0.75])
    }

    func testRefreshRunsHeavyWorkOffMainActorAndPublishesSnapshot() async {
        let workRanOffMainActor = expectation(description: "workRanOffMainActor")
        workRanOffMainActor.expectedFulfillmentCount = 2

        let updated = expectation(description: "updated")
        let initialSnapshot = makeSystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 10),
            cpuUsage: 10,
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 500),
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
            cpuUsage: 40,
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 300),
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
        let expectedGrowth = DiskGrowthSummary(
            latest: DiskSnapshot(timestamp: refreshedSnapshot.timestamp, availableBytes: 300, totalBytes: 1_000),
            baseline: nil,
            growthBytes: 25,
            observedHours: 2,
            statusText: "ready"
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

        let systemSnapshotCalls = LockedBox(0)
        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [initialSnapshot, refreshedSnapshot]) {
                let shouldCheckBackgroundRefresh = systemSnapshotCalls.withLock { calls in
                    calls += 1
                    return calls > 1
                }
                guard shouldCheckBackgroundRefresh else {
                    return
                }
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
        XCTAssertEqual(state.diskGrowth.growthBytes, 200)
        XCTAssertEqual(state.diskGrowth.statusText, "Since launch disk history ready")
        XCTAssertEqual(state.codexQuota.limitID, expectedQuota.limitID)
        XCTAssertEqual(state.dashboardTrendSamples.map(\.timestamp), [initialSnapshot.timestamp, refreshedSnapshot.timestamp])
        XCTAssertEqual(state.dashboardTrendSamples.last?.cpuUsage, 40)
        XCTAssertEqual(state.dashboardTrendSamples.last?.memoryUsedPercent, 50)
        XCTAssertEqual(state.dashboardTrendSamples.last?.diskUsedPercent ?? -1, 70, accuracy: 0.001)
        XCTAssertEqual(state.dashboardTrendSamples.last?.diskReadBytesPerSecond, 60)
        XCTAssertEqual(state.dashboardTrendSamples.last?.diskWriteBytesPerSecond, 90)
        XCTAssertEqual(state.dashboardTrendSamples.last?.diskIOActivityPercent ?? -1, 0.000143, accuracy: 0.000001)
        XCTAssertEqual(state.dashboardTrendSamples.last?.batteryPercent, 80)
        XCTAssertEqual(state.dashboardTrendSamples.last?.codexRemainingPercent, 55)
    }

    func testRefreshPublishesDiskIOSinceLaunchAndRates() async {
        let updated = expectation(description: "updated")
        let initialSnapshot = makeSystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 10),
            cpuUsage: 10,
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 500),
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
            diskCapacity: DiskCapacity(totalBytes: 1_000, availableBytes: 300),
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
            readBytes24h: 99_999,
            writeBytes24h: 88_888,
            observedHours: 24,
            statusText: "24h I/O history ready"
        )

        let state = AppState(
            systemMonitor: StubSystemMonitor(snapshots: [initialSnapshot, refreshedSnapshot]),
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            diskIOStore: StubDiskIOHistoryStore(summary: ioSummary),
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

        XCTAssertEqual(state.diskGrowth.growthBytes, 200)
        XCTAssertEqual(state.diskGrowth.statusText, "Since launch disk history ready")
        XCTAssertEqual(state.system.diskIO.readBytes24h, 600)
        XCTAssertEqual(state.system.diskIO.writeBytes24h, 900)
        XCTAssertEqual(state.system.diskIO.readBytesPerSecond, 60)
        XCTAssertEqual(state.system.diskIO.writeBytesPerSecond, 90)
        XCTAssertEqual(state.system.diskIO.sourceDescription, "Since launch I/O ready")
    }

    func testRefreshSkipsOverlappingWork() async {
        let workStarted = expectation(description: "workStarted")
        let refreshPublished = expectation(description: "refreshPublished")
        let gate = LockedGate()
        let snapshotCalls = LockedBox(0)
        let refreshCalls = LockedBox(0)

        let state = AppState(
            systemMonitor: StubSystemMonitor(
                snapshots: [makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 10), cpuUsage: 1),
                            makeSystemSnapshot(timestamp: Date(timeIntervalSince1970: 20), cpuUsage: 2)]
            ) {
                let callIndex = snapshotCalls.withLock {
                    $0 += 1
                    return $0
                }
                guard callIndex > 1 else {
                    return
                }
                refreshCalls.withLock { $0 += 1 }
                workStarted.fulfill()
                gate.wait()
            },
            diskStore: StubDiskGrowthStore(
                growthSummary: DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "none")
            ),
            codexReader: StubCodexQuotaReader(result: .unavailable)
        )

        state.refresh()
        await fulfillment(of: [workStarted], timeout: 2.0)

        state.refresh()
        gate.open()

        Task {
            while true {
                if state.system.cpuUsage == 2 {
                    refreshPublished.fulfill()
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        await fulfillment(of: [refreshPublished], timeout: 2.0)

        XCTAssertEqual(refreshCalls.withLock { $0 }, 1)
    }

    private func makeSystemSnapshot(
        timestamp: Date,
        cpuUsage: Double?,
        diskCapacity: DiskCapacity = DiskCapacity(totalBytes: 1_000, availableBytes: 300),
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
            diskCapacity: diskCapacity,
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
        return snapshots.withLock {
            guard $0.count > 1 else {
                return $0[0]
            }
            return $0.removeFirst()
        }
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
