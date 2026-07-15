import AppKit
import Combine

enum TouchBarMetric: CaseIterable {
    case cpu
    case memory
    case disk
    case battery
    case codex
}

struct TouchBarMetricSnapshot {
    var text: String
    var progress: Double
    var color: NSColor
}

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let state: AppState
    private var cancellables: Set<AnyCancellable> = []
    private weak var statusStripView: TouchBarStatusStripView?

    static let statusStrip = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.statusStrip")

    init(state: AppState) {
        self.state = state
        super.init()
        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusStrip()
                }
            }
            .store(in: &cancellables)
    }

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = "local.MacStatusCodexMonitor.touchbar"
        touchBar.defaultItemIdentifiers = [Self.statusStrip]
        touchBar.customizationAllowedItemIdentifiers = [Self.statusStrip]
        touchBar.customizationRequiredItemIdentifiers = [Self.statusStrip]
        touchBar.principalItemIdentifier = Self.statusStrip
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Self.statusStrip else {
            return nil
        }

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "Mac Status & Codex"

        let view = TouchBarStatusStripView()
        view.update(metrics: currentMetrics())
        item.view = view
        statusStripView = view
        return item
    }

    private func updateStatusStrip() {
        statusStripView?.update(metrics: currentMetrics())
    }

    private func currentMetrics() -> [TouchBarMetric: TouchBarMetricSnapshot] {
        [
            .cpu: TouchBarMetricSnapshot(
                text: "CPU \(PercentFormatterUtility.string(state.system.cpuUsage))",
                progress: progressPercent(state.system.cpuUsage),
                color: .systemBlue
            ),
            .memory: TouchBarMetricSnapshot(
                text: "Mem \(PercentFormatterUtility.string(state.system.memoryUsedPercent))",
                progress: progressPercent(state.system.memoryUsedPercent),
                color: .systemTeal
            ),
            .disk: TouchBarMetricSnapshot(
                text: "Disk \(PercentFormatterUtility.string(state.system.diskCapacity.usedPercent))",
                progress: progressPercent(state.system.diskCapacity.usedPercent),
                color: diskColor
            ),
            .battery: TouchBarMetricSnapshot(
                text: "Batt \(PercentFormatterUtility.string(state.system.battery.percent))",
                progress: progressPercent(state.system.battery.percent),
                color: batteryColor
            ),
            .codex: TouchBarMetricSnapshot(
                text: "Codex \(PercentFormatterUtility.string(state.codexQuota.remainingPercent))",
                progress: progressPercent(state.codexQuota.remainingPercent),
                color: codexColor
            )
        ]
    }

    private var diskColor: NSColor {
        let used = state.system.diskCapacity.usedPercent
        if used >= 90 {
            return .systemRed
        }
        if used >= 75 {
            return .systemOrange
        }
        return .systemGreen
    }

    private var batteryColor: NSColor {
        guard let percent = state.system.battery.percent else {
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

    private var codexColor: NSColor {
        guard let remaining = state.codexQuota.remainingPercent else {
            return .systemRed
        }
        if remaining < 15 {
            return .systemRed
        }
        if remaining < 35 {
            return .systemOrange
        }
        return .systemPurple
    }

    private func progressPercent(_ percent: Double?) -> Double {
        guard let percent else {
            return 0
        }
        return min(max(percent / 100, 0), 1)
    }
}

@MainActor
final class TouchBarStatusStripView: NSStackView {
    private var segments: [TouchBarMetric: TouchBarMetricSegmentView] = [:]

    init() {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        distribution = .fillEqually
        spacing = 8
        translatesAutoresizingMaskIntoConstraints = false

        for metric in TouchBarMetric.allCases {
            let segment = TouchBarMetricSegmentView()
            segments[metric] = segment
            addArrangedSubview(segment)
            segment.widthAnchor.constraint(greaterThanOrEqualToConstant: 92).isActive = true
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(metrics: [TouchBarMetric: TouchBarMetricSnapshot]) {
        for metric in TouchBarMetric.allCases {
            guard let snapshot = metrics[metric] else {
                continue
            }
            segments[metric]?.update(snapshot)
        }
    }

    func labelText(for metric: TouchBarMetric) -> String? {
        segments[metric]?.labelText
    }

    func progress(for metric: TouchBarMetric) -> Double? {
        segments[metric]?.progress
    }

    func barColor(for metric: TouchBarMetric) -> NSColor? {
        segments[metric]?.barColor
    }
}

@MainActor
private final class TouchBarMetricSegmentView: NSStackView {
    private let label = NSTextField(labelWithString: "")
    private let progressBar = ColoredProgressBarView()

    var labelText: String {
        label.stringValue
    }

    var progress: Double {
        progressBar.progress
    }

    var barColor: NSColor {
        progressBar.barColor
    }

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        distribution = .fill
        spacing = 3
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        addArrangedSubview(label)
        addArrangedSubview(progressBar)
        progressBar.heightAnchor.constraint(equalToConstant: 4).isActive = true
        progressBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 86).isActive = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ snapshot: TouchBarMetricSnapshot) {
        label.stringValue = snapshot.text
        progressBar.progress = snapshot.progress
        progressBar.barColor = snapshot.color
    }
}

@MainActor
private final class ColoredProgressBarView: NSView {
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()

    var progress: Double = 0 {
        didSet {
            progress = min(max(progress, 0), 1)
            needsLayout = true
        }
    }

    var barColor: NSColor = .systemBlue {
        didSet {
            fillLayer.backgroundColor = barColor.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = false

        trackLayer.cornerRadius = 2
        trackLayer.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        fillLayer.cornerRadius = 2
        fillLayer.backgroundColor = barColor.cgColor

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        trackLayer.frame = bounds
        fillLayer.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width * progress,
            height: bounds.height
        )
    }
}
