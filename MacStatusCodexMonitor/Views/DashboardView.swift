import SwiftUI

struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mac Status & Codex")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricTile(title: "CPU", value: PercentFormatterUtility.string(state.system.cpuUsage), detail: "Live sample")
                    MetricTile(title: "Memory", value: PercentFormatterUtility.string(state.system.memoryUsedPercent), detail: memoryDetail)
                    MetricTile(title: "Disk", value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent), detail: diskDetail)
                    MetricTile(title: "Codex", value: PercentFormatterUtility.string(state.codexQuota.remainingPercent), detail: codexDetail)
                }

                section("Battery & GPU") {
                    MetricTile(title: "Battery", value: batteryValue, detail: state.system.battery.statusText)
                    MetricTile(title: "GPU", value: gpuValue, detail: gpuDetail)
                }

                section("Disk Growth & Cache") {
                    MetricTile(title: "24h Growth", value: diskGrowthValue, detail: state.diskGrowth.statusText)
                    MetricTile(title: "24h Read", value: diskRead24hValue, detail: diskIODetail)
                    MetricTile(title: "24h Write", value: diskWrite24hValue, detail: diskIODetail)
                    MetricTile(title: "Cache Total", value: ByteFormatterUtility.string(bytes: state.cacheEstimate.totalBytes), detail: "Current cache-like size")
                    MetricTile(title: "24h Cache Growth", value: cacheGrowthValue, detail: cacheGrowthDetail)
                    ForEach(state.cacheEstimate.entries) { entry in
                        HStack {
                            Text(entry.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(ByteFormatterUtility.string(bytes: entry.bytes))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                section("Codex Quota") {
                    MetricTile(title: "Used", value: PercentFormatterUtility.string(state.codexQuota.usedPercent), detail: state.codexQuota.sourceDescription)
                    MetricTile(title: "Reset", value: resetValue, detail: "Plan: \(state.codexQuota.planType ?? "Not reported")")
                    MetricTile(title: "Reset Cards", value: state.codexQuota.extraQuotaDescription, detail: "Credits: \(state.codexQuota.creditsDescription)")
                    MetricTile(title: "Limit", value: state.codexQuota.individualLimitDescription, detail: state.codexQuota.rateLimitReachedType ?? "No rate-limit stop reported")
                }
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private var memoryDetail: String {
        guard let used = state.system.memoryUsedBytes, let total = state.system.memoryTotalBytes else {
            return "Not reported"
        }
        return "\(ByteFormatterUtility.string(bytes: used)) of \(ByteFormatterUtility.string(bytes: total))"
    }

    private var diskDetail: String {
        "\(ByteFormatterUtility.string(bytes: state.system.diskCapacity.availableBytes)) available"
    }

    private var codexDetail: String {
        if let reset = state.codexQuota.resetsAt {
            return "Resets \(reset.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Reset not reported"
    }

    private var batteryValue: String {
        PercentFormatterUtility.string(state.system.battery.percent)
    }

    private var gpuValue: String {
        switch state.system.gpu {
        case let .available(gpu):
            return gpu.name
        case .unavailable:
            return "Unavailable"
        }
    }

    private var gpuDetail: String {
        switch state.system.gpu {
        case let .available(gpu):
            return PercentFormatterUtility.string(gpu.utilizationPercent)
        case let .unavailable(message):
            return message
        }
    }

    private var diskGrowthValue: String {
        guard let growth = state.diskGrowth.growthBytes else {
            return "Learning"
        }
        return ByteFormatterUtility.signedString(bytes: growth)
    }

    private var diskRead24hValue: String {
        guard let bytes = state.system.diskIO.readBytes24h else {
            return "Learning"
        }
        return ByteFormatterUtility.string(bytes: bytes)
    }

    private var diskWrite24hValue: String {
        guard let bytes = state.system.diskIO.writeBytes24h else {
            return "Learning"
        }
        return ByteFormatterUtility.string(bytes: bytes)
    }

    private var diskIODetail: String {
        let readRate = state.system.diskIO.readBytesPerSecond.map(ByteFormatterUtility.rate) ?? "rate learning"
        let writeRate = state.system.diskIO.writeBytesPerSecond.map(ByteFormatterUtility.rate) ?? "rate learning"
        return "\(state.system.diskIO.sourceDescription) / R \(readRate), W \(writeRate)"
    }

    private var cacheGrowthValue: String {
        guard let growth = state.cacheEstimate.growthBytes24h else {
            return "Learning"
        }
        return ByteFormatterUtility.signedString(bytes: growth)
    }

    private var cacheGrowthDetail: String {
        if let share = state.cacheEstimate.growthShareOfDiskGrowth {
            return "\(state.cacheEstimate.statusText) / \(PercentFormatterUtility.string(share)) of disk growth"
        }
        return state.cacheEstimate.statusText
    }

    private var resetValue: String {
        state.codexQuota.resetsAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not reported"
    }
}
