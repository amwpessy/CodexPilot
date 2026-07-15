import Combine
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private let scheduler: MonitoringScheduler
    private let statusTitleSink: ((String) -> Void)?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?
    private var touchBarController: TouchBarController?
    private var stateSubscription: AnyCancellable?
    private var menuBarTitleUpdateScheduled = false

    override init() {
        self.state = nil
        self.scheduler = MonitoringScheduler()
        self.statusTitleSink = nil
        super.init()
    }

    @MainActor
    init(state: AppState,
         scheduler: MonitoringScheduler = MonitoringScheduler(),
         statusTitleSink: ((String) -> Void)? = nil) {
        self.state = state
        self.scheduler = scheduler
        self.statusTitleSink = statusTitleSink
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
        NSApp.activate(ignoringOtherApps: true)
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
        let cpu = PercentFormatterUtility.string(state.system.cpuUsage)
        let memory = PercentFormatterUtility.string(state.system.memoryUsedPercent)
        let disk = PercentFormatterUtility.string(state.system.diskCapacity.usedPercent)
        let battery = PercentFormatterUtility.string(state.system.battery.percent)
        let codex = PercentFormatterUtility.string(state.codexQuota.remainingPercent)
        return "CPU \(cpu) Mem \(memory) Disk \(disk) Batt \(battery) Codex \(codex)"
    }

    @MainActor
    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
