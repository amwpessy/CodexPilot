import AppKit
import Combine

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let state: AppState
    private var cancellables: Set<AnyCancellable> = []
    private var labels: [NSTouchBarItem.Identifier: NSTextField] = [:]

    static let cpu = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.cpu")
    static let memory = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.memory")
    static let disk = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.disk")
    static let battery = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.battery")
    static let codex = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.codex")

    init(state: AppState) {
        self.state = state
        super.init()
        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateLabels()
                }
            }
            .store(in: &cancellables)
    }

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [Self.cpu, Self.memory, Self.disk, Self.battery, Self.codex]
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let label = NSTextField(labelWithString: text(for: identifier))
        label.alignment = .center
        item.view = label
        labels[identifier] = label
        return item
    }

    private func updateLabels() {
        for (identifier, label) in labels {
            label.stringValue = text(for: identifier)
        }
    }

    private func text(for identifier: NSTouchBarItem.Identifier) -> String {
        switch identifier {
        case Self.cpu:
            return "CPU \(PercentFormatterUtility.string(state.system.cpuUsage))"
        case Self.memory:
            return "Mem \(PercentFormatterUtility.string(state.system.memoryUsedPercent))"
        case Self.disk:
            if let growth = state.diskGrowth.growthBytes {
                return "Disk \(ByteFormatterUtility.signedString(bytes: growth))"
            }
            return "Disk Learning"
        case Self.battery:
            return "Batt \(PercentFormatterUtility.string(state.system.battery.percent))"
        case Self.codex:
            return "Codex \(PercentFormatterUtility.string(state.codexQuota.remainingPercent))"
        default:
            return ""
        }
    }
}
