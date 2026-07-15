import Combine
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private let scheduler: MonitoringScheduler
    private let statusTitleSink: ((String) -> Void)?
    private let appActivationSink: (() -> Void)?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?
    private var touchBarController: TouchBarController?
    private var stateSubscription: AnyCancellable?
    private var menuBarRotationTimer: Timer?
    private var menuBarMetricIndex = 0
    private var menuBarTitleUpdateScheduled = false

    override init() {
        self.state = nil
        self.scheduler = MonitoringScheduler()
        self.statusTitleSink = nil
        self.appActivationSink = nil
        super.init()
    }

    @MainActor
    init(state: AppState,
         scheduler: MonitoringScheduler = MonitoringScheduler(),
         statusTitleSink: ((String) -> Void)? = nil,
         appActivationSink: (() -> Void)? = nil) {
        self.state = state
        self.scheduler = scheduler
        self.statusTitleSink = statusTitleSink
        self.appActivationSink = appActivationSink
        super.init()
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = ensureState()
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem(state: state)
        let touchController = TouchBarController(state: state)
        touchBarController = touchController
        NSApp.touchBar = touchController.makeTouchBar()
        observeStateForMenuBarTitle()
        startMenuBarRotationTimer()
        scheduler.start(interval: 120) { [weak self] in
            Task { @MainActor in
                self?.ensureState().refresh()
                self?.updateMenuBarTitle()
            }
        }
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
        menuBarRotationTimer?.invalidate()
        menuBarRotationTimer = nil
        stateSubscription = nil
    }

    @MainActor
    func showDashboard() {
        let state = ensureState()
        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mac Status & Codex"
            window.contentView = NSHostingView(rootView: DashboardView(state: state))
            dashboardWindow = window
        }
        dashboardWindow?.center()
        dashboardWindow?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    @MainActor
    private func installMenuBarItem(state: AppState) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        updateMenuBarTitle()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 260, height: 220)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(state: state) { [weak self] in
            self?.popover?.performClose(nil)
            self?.showDashboard()
        })
        self.popover = popover
    }

    @MainActor
    func observeStateForMenuBarTitle() {
        let state = ensureState()
        stateSubscription = state.objectWillChange.sink { [weak self] _ in
            self?.scheduleMenuBarTitleUpdate()
        }
    }

    @MainActor
    func advanceMenuBarStatusMetric() {
        let metrics = menuBarStatusMetrics(for: ensureState())
        guard !metrics.isEmpty else {
            return
        }
        menuBarMetricIndex = (menuBarMetricIndex + 1) % metrics.count
        updateMenuBarTitle()
    }

    @MainActor
    private func scheduleMenuBarTitleUpdate() {
        guard !menuBarTitleUpdateScheduled else {
            return
        }
        menuBarTitleUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.menuBarTitleUpdateScheduled = false
            self.updateMenuBarTitle()
        }
    }

    @MainActor
    private func updateMenuBarTitle() {
        let state = ensureState()
        let title = menuBarTitle(for: state)
        statusTitleSink?(title)
        statusItem?.button?.title = title
    }

    @MainActor
    private func menuBarTitle(for state: AppState) -> String {
        let metrics = menuBarStatusMetrics(for: state)
        let index = min(menuBarMetricIndex, metrics.count - 1)
        let metric = metrics[index]
        return "\(metric.label) \(progressBar(percent: metric.percent)) \(PercentFormatterUtility.string(metric.percent))"
    }

    @MainActor
    private func menuBarStatusMetrics(for state: AppState) -> [(label: String, percent: Double?)] {
        [
            ("CPU", state.system.cpuUsage),
            ("Mem", state.system.memoryUsedPercent),
            ("Disk", state.system.diskCapacity.usedPercent),
            ("Batt", state.system.battery.percent),
            ("Codex", state.codexQuota.remainingPercent)
        ]
    }

    @MainActor
    private func progressBar(percent: Double?) -> String {
        guard let percent else {
            return "▱▱▱▱▱"
        }
        let filled = Int((min(max(percent, 0), 100) / 20).rounded(.toNearestOrAwayFromZero))
        return String(repeating: "▰", count: filled) + String(repeating: "▱", count: 5 - filled)
    }

    @MainActor
    private func startMenuBarRotationTimer() {
        menuBarRotationTimer?.invalidate()
        menuBarRotationTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMenuBarStatusMetric()
            }
        }
    }

    @MainActor
    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            activateApp()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @MainActor
    private func activateApp() {
        if let appActivationSink {
            appActivationSink()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private func ensureState() -> AppState {
        if let state {
            return state
        }
        let newState = AppState()
        state = newState
        return newState
    }
}
