import AppKit
import SwiftUI

struct MenuBarCockpitMetric: Identifiable {
    var id: String { title }
    var title: String
    var subtitle: String
    var value: String
    var progress: Double
    var tint: Color
}

struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState
    var openDashboard: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.cockpitMetrics(for: state)) { metric in
                    CockpitMetricCard(metric: metric)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: openDashboard) {
                    Label("打开 / Open", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: { NSApp.terminate(nil) }) {
                    Label("退出 / Quit", systemImage: "power")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("林猫驾驶舱")
                    .font(.headline)
                Text("Lynncat Pilot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("运行中")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @MainActor
    static func cockpitMetrics(for state: AppState) -> [MenuBarCockpitMetric] {
        [
            MenuBarCockpitMetric(
                title: "CPU",
                subtitle: "处理器",
                value: PercentFormatterUtility.string(state.system.cpuUsage),
                progress: progressPercent(state.system.cpuUsage),
                tint: .blue
            ),
            MenuBarCockpitMetric(
                title: "Mem",
                subtitle: "内存",
                value: PercentFormatterUtility.string(state.system.memoryUsedPercent),
                progress: progressPercent(state.system.memoryUsedPercent),
                tint: .teal
            ),
            MenuBarCockpitMetric(
                title: "Disk",
                subtitle: "硬盘已用",
                value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent),
                progress: progressPercent(state.system.diskCapacity.usedPercent),
                tint: diskTint(percent: state.system.diskCapacity.usedPercent)
            ),
            MenuBarCockpitMetric(
                title: "Codex",
                subtitle: "剩余额度",
                value: PercentFormatterUtility.string(state.codexQuota.remainingPercent),
                progress: progressPercent(state.codexQuota.remainingPercent),
                tint: codexTint(percent: state.codexQuota.remainingPercent)
            )
        ]
    }

    private static func progressPercent(_ percent: Double?) -> Double {
        guard let percent else {
            return 0
        }
        return min(max(percent / 100, 0), 1)
    }

    private static func diskTint(percent: Double?) -> Color {
        guard let percent else {
            return .secondary
        }
        if percent >= 90 {
            return .red
        }
        if percent >= 75 {
            return .orange
        }
        return .green
    }

    private static func codexTint(percent: Double?) -> Color {
        guard let percent else {
            return .red
        }
        if percent < 15 {
            return .red
        }
        if percent < 35 {
            return .orange
        }
        return .purple
    }
}

private struct CockpitMetricCard: View {
    var metric: MenuBarCockpitMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(metric.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(metric.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(metric.value)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            ProgressView(value: metric.progress)
                .tint(metric.tint)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
        )
    }
}
