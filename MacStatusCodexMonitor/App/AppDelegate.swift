import Combine
import AppKit
import SwiftUI

struct MenuBarStatusSnapshot: Equatable {
    var title: String
    var label: String
    var percentText: String
    var progress: Double
    var color: NSColor
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private let scheduler: MonitoringScheduler
    private let statusTitleSink: ((String) -> Void)?
    private let appActivationSink: (() -> Void)?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?
    private var touchBarController: TouchBarController?
    private var menuBarStatusView: MenuBarStatusProgressView?
    private var stateSubscription: AnyCancellable?
    private var menuBarRotationTimer: Timer?
    private var menuBarMetricIndex = 0
    private var menuBarTitleUpdateScheduled = false
    @MainActor
    private var communityAccount: CommunityAccountStore {
        CommunityAccountStore.shared
    }

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
        observeDashboardThemeChanges()
        startMenuBarRotationTimer()
        showDashboard()
        startMonitoringScheduler()
        communityAccount.setForeground(true)
        Task { [communityAccount] in
            await communityAccount.restoreSession()
        }
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
        menuBarRotationTimer?.invalidate()
        menuBarRotationTimer = nil
        communityAccount.setForeground(false)
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
        stateSubscription = nil
    }

    @MainActor
    func showDashboard() {
        let state = ensureState()
        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 660),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Codex 驾驶舱 / CodexPilot"
            window.contentView = NSHostingView(rootView: DashboardView(state: state))
            window.delegate = self
            window.isReleasedWhenClosed = false
            dashboardWindow = window
            window.center()
        }
        if dashboardWindow?.isMiniaturized == true {
            dashboardWindow?.deminiaturize(nil)
        }
        dashboardWindow?.makeKeyAndOrderFront(nil)
        activateApp()
    }

    @MainActor
    func dashboardWindowForTesting() -> NSWindow? {
        dashboardWindow
    }

    @MainActor
    private func installMenuBarItem(state: AppState) {
        let item = NSStatusBar.system.statusItem(withLength: 69)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        if let button = item.button {
            button.title = ""
            let statusView = MenuBarStatusProgressView()
            statusView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(statusView)
            NSLayoutConstraint.activate([
                statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
                statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
                statusView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                statusView.heightAnchor.constraint(equalToConstant: 22)
            ])
            menuBarStatusView = statusView
        }
        updateMenuBarTitle()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(state: state) { [weak self] in
            self?.popover?.performClose(nil)
            DispatchQueue.main.async { [weak self] in
                self?.showDashboard()
            }
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
        let snapshot = currentMenuBarStatusSnapshot()
        statusTitleSink?(snapshot.title)
        statusItem?.button?.toolTip = snapshot.title
        if let menuBarStatusView {
            menuBarStatusView.update(snapshot: snapshot)
            statusItem?.button?.title = ""
        } else {
            statusItem?.button?.title = snapshot.title
        }
    }

    @MainActor
    func currentMenuBarStatusSnapshot() -> MenuBarStatusSnapshot {
        menuBarStatusSnapshot(for: ensureState())
    }

    @MainActor
    func menuBarStatusItemLengthForTesting() -> CGFloat? {
        statusItem?.length
    }

    @MainActor
    func monitoringRefreshIntervalForTesting() -> TimeInterval? {
        scheduler.currentInterval
    }

    @MainActor
    private func menuBarStatusSnapshot(for state: AppState) -> MenuBarStatusSnapshot {
        let metrics = menuBarStatusMetrics(for: state)
        let index = min(menuBarMetricIndex, metrics.count - 1)
        let metric = metrics[index]
        let percentText = PercentFormatterUtility.string(metric.percent)
        let progress = min(max((metric.percent ?? 0) / 100, 0), 1)
        return MenuBarStatusSnapshot(
            title: "\(metric.label) \(percentText)",
            label: metric.label,
            percentText: percentText,
            progress: progress,
            color: metric.color
        )
    }

    @MainActor
    private func menuBarStatusMetrics(for state: AppState) -> [(label: String, percent: Double?, color: NSColor)] {
        [
            ("CPU", state.system.cpuUsage, .systemBlue),
            ("Mem", state.system.memoryUsedPercent, .systemTeal),
            ("Disk", state.system.diskCapacity.usedPercent, diskColor(percent: state.system.diskCapacity.usedPercent)),
            ("Bat", state.system.battery.percent, batteryColor(percent: state.system.battery.percent)),
            ("Cod", state.codexQuota.remainingPercent, codexColor(percent: state.codexQuota.remainingPercent))
        ]
    }

    @MainActor
    private func diskColor(percent: Double?) -> NSColor {
        guard let percent else {
            return .secondaryLabelColor
        }
        if percent >= 90 {
            return .systemRed
        }
        if percent >= 75 {
            return .systemOrange
        }
        return .systemGreen
    }

    @MainActor
    private func batteryColor(percent: Double?) -> NSColor {
        guard let percent else {
            return .secondaryLabelColor
        }
        if percent < 20 {
            return .systemRed
        }
        if percent < 50 {
            return .systemOrange
        }
        return .systemGreen
    }

    @MainActor
    private func codexColor(percent: Double?) -> NSColor {
        guard let percent else {
            return .systemRed
        }
        if percent < 15 {
            return .systemRed
        }
        if percent < 35 {
            return .systemOrange
        }
        return .systemPurple
    }

    @MainActor
    private func startMenuBarRotationTimer() {
        menuBarRotationTimer?.invalidate()
        menuBarRotationTimer = Timer.scheduledTimer(
            timeInterval: 4,
            target: self,
            selector: #selector(menuBarRotationTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @MainActor
    @objc private func menuBarRotationTimerFired(_ timer: Timer) {
        advanceMenuBarStatusMetric()
    }

    @MainActor
    private func observeDashboardThemeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dashboardThemeDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @MainActor
    @objc private func dashboardThemeDidChange(_ notification: Notification) {
        startMonitoringScheduler()
    }

    @MainActor
    private func startMonitoringScheduler() {
        let interval = monitoringRefreshInterval
        guard scheduler.currentInterval != interval else {
            return
        }
        scheduler.start(interval: interval) { [weak self] in
            Task { @MainActor in
                self?.ensureState().refresh()
                self?.updateMenuBarTitle()
            }
        }
    }

    private var monitoringRefreshInterval: TimeInterval {
        let sportMode = UserDefaults.standard.object(forKey: "dashboardSportThemeEnabled") as? Bool ?? false
        return sportMode ? 1 : 120
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

extension AppDelegate: NSWindowDelegate {
    @MainActor
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === dashboardWindow else {
            return
        }
        dashboardWindow?.delegate = nil
        dashboardWindow = nil
    }
}

final class MenuBarStatusProgressView: NSView {
    private let labelField = NSTextField(labelWithString: "")
    private let percentField = NSTextField(labelWithString: "")
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private var progress: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(snapshot: MenuBarStatusSnapshot) {
        labelField.stringValue = snapshot.label
        percentField.stringValue = snapshot.percentText
        progress = snapshot.progress
        fillLayer.backgroundColor = snapshot.color.cgColor
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let percentWidth = min(CGFloat(29), bounds.width * 0.48)
        let labelWidth = max(0, bounds.width - percentWidth - 2)
        labelField.alignment = .left
        labelField.frame = NSRect(x: 0, y: bounds.height - 14, width: labelWidth, height: 13)
        percentField.isHidden = false
        percentField.frame = NSRect(x: bounds.width - percentWidth, y: bounds.height - 14, width: percentWidth, height: 13)

        let barY: CGFloat = 3
        let barHeight: CGFloat = 5
        let barWidth = max(0, bounds.width)
        trackLayer.frame = NSRect(x: 0, y: barY, width: barWidth, height: barHeight)
        fillLayer.frame = NSRect(x: 0, y: barY, width: barWidth * progress, height: barHeight)
        trackLayer.cornerRadius = barHeight / 2
        fillLayer.cornerRadius = barHeight / 2
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        trackLayer.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.38).cgColor
        fillLayer.backgroundColor = NSColor.systemBlue.cgColor
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)

        for field in [labelField, percentField] {
            field.font = .monospacedSystemFont(ofSize: 8, weight: .semibold)
            field.textColor = .labelColor
            field.lineBreakMode = .byTruncatingTail
            addSubview(field)
        }
        percentField.alignment = .right
    }

    var labelTextForTesting: String {
        labelField.stringValue
    }

    var percentTextForTesting: String {
        percentField.stringValue
    }

    var isPercentVisibleForTesting: Bool {
        !percentField.isHidden
    }
}
