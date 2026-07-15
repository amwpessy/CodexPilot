import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let scheduler = MonitoringScheduler()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem()
        scheduler.start(interval: 30) { [weak self] in
            Task { @MainActor in
                self?.state.refresh()
                self?.updateMenuBarTitle()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
    }

    func showDashboard() {
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

    private func installMenuBarItem() {
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

    private func updateMenuBarTitle() {
        let cpu = PercentFormatterUtility.string(state.system.cpuUsage)
        let codex = PercentFormatterUtility.string(state.codexQuota.remainingPercent)
        statusItem?.button?.title = "CPU \(cpu) Codex \(codex)"
    }

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
}
