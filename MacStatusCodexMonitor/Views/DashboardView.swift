import SwiftUI

struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBand

                HStack(alignment: .top, spacing: 14) {
                    systemHealthColumn
                        .frame(minWidth: 220, maxWidth: 260)
                    diskAnalysisColumn
                        .frame(minWidth: 300, maxWidth: .infinity)
                    codexColumn
                        .frame(minWidth: 240, maxWidth: 300)
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 920, minHeight: 620)
    }

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mac 状态与 Codex / Mac Status & Codex")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text("采样时间 / Sample \(sampleTimeValue)  |  \(resetContext)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusDot(label: "运行中 / Active", color: .green)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                SummaryPill(
                    title: "处理器 / CPU",
                    value: PercentFormatterUtility.string(state.system.cpuUsage),
                    detail: "实时采样 / Live sample",
                    tint: .blue
                )
                SummaryPill(
                    title: "内存 / Memory",
                    value: PercentFormatterUtility.string(state.system.memoryUsedPercent),
                    detail: memoryDetail,
                    tint: .teal
                )
                SummaryPill(
                    title: "硬盘 / Disk",
                    value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent),
                    detail: diskDetail,
                    tint: .orange
                )
                SummaryPill(
                    title: "Codex 额度 / Quota",
                    value: codexRemainingValue,
                    detail: codexDetail,
                    tint: .indigo
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
    }

    private var systemHealthColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCenterPanel(title: "系统健康 / System Health", subtitle: "核心状态 / Core signals") {
                VStack(spacing: 12) {
                    MetricGauge(
                        title: "处理器 / CPU",
                        value: PercentFormatterUtility.string(state.system.cpuUsage),
                        percent: state.system.cpuUsage,
                        detail: "当前负载 / Current load",
                        tint: .blue
                    )
                    MetricGauge(
                        title: "内存 / Memory",
                        value: PercentFormatterUtility.string(state.system.memoryUsedPercent),
                        percent: state.system.memoryUsedPercent,
                        detail: memoryDetail,
                        tint: .teal
                    )
                    MetricGauge(
                        title: "电池 / Battery",
                        value: batteryValue,
                        percent: state.system.battery.percent,
                        detail: bilingualStatus(state.system.battery.statusText),
                        tint: batteryTint
                    )
                    StatusRow(
                        title: "显卡 / GPU",
                        value: gpuValue,
                        detail: bilingualStatus(gpuDetail),
                        color: gpuIsAvailable ? .green : .secondary
                    )
                }
            }
        }
    }

    private var diskAnalysisColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCenterPanel(title: "硬盘与缓存 / Disk & Cache", subtitle: "24小时变化 / 24h movement") {
                VStack(spacing: 12) {
                    MetricGauge(
                        title: "硬盘使用 / Disk Used",
                        value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent),
                        percent: state.system.diskCapacity.usedPercent,
                        detail: diskUsedDetail,
                        tint: .orange
                    )

                    HStack(spacing: 10) {
                        StatusRow(
                            title: "24小时增长 / 24h Growth",
                            value: diskGrowthValue,
                            detail: bilingualStatus(state.diskGrowth.statusText),
                            color: diskGrowthColor
                        )
                        StatusRow(
                            title: "缓存增长 / Cache Growth",
                            value: cacheGrowthValue,
                            detail: cacheGrowthDetailBilingual,
                            color: cacheGrowthColor
                        )
                    }

                    Divider()

                    HStack(spacing: 10) {
                        StatusRow(
                            title: "24小时读取 / 24h Read",
                            value: diskRead24hValue,
                            detail: readRateDetail,
                            color: .blue
                        )
                        StatusRow(
                            title: "24小时写入 / 24h Write",
                            value: diskWrite24hValue,
                            detail: writeRateDetail,
                            color: .purple
                        )
                    }

                    StatusRow(
                        title: "缓存总量 / Cache Total",
                        value: ByteFormatterUtility.string(bytes: state.cacheEstimate.totalBytes),
                        detail: "可读缓存估算 / Readable cache estimate",
                        color: .orange
                    )

                    if state.cacheEstimate.entries.isEmpty {
                        StatusRow(
                            title: "缓存目录 / Cache Paths",
                            value: "无数据 / No data",
                            detail: "等待下一次扫描 / Waiting for scan",
                            color: .secondary
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(state.cacheEstimate.entries.prefix(5)) { entry in
                                CacheDirectoryRow(path: entry.path, bytes: ByteFormatterUtility.string(bytes: entry.bytes))
                            }
                        }
                    }
                }
            }
        }
    }

    private var codexColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCenterPanel(title: "Codex 额度 / Codex Quota", subtitle: "本地日志信号 / Local log signal") {
                VStack(spacing: 12) {
                    MetricGauge(
                        title: "剩余额度 / Remaining",
                        value: codexRemainingValue,
                        percent: state.codexQuota.remainingPercent,
                        detail: codexDetail,
                        tint: .indigo
                    )
                    MetricGauge(
                        title: "已用额度 / Used",
                        value: PercentFormatterUtility.string(state.codexQuota.usedPercent),
                        percent: state.codexQuota.usedPercent,
                        detail: bilingualStatus(state.codexQuota.sourceDescription),
                        tint: .pink
                    )

                    Divider()

                    StatusRow(
                        title: "重置时间 / Reset",
                        value: resetValue,
                        detail: "计划 / Plan: \(state.codexQuota.planType ?? "Not reported")",
                        color: .blue
                    )
                    StatusRow(
                        title: "重置卡 / Reset Cards",
                        value: state.codexQuota.extraQuotaDescription,
                        detail: "积分 / Credits: \(state.codexQuota.creditsDescription)",
                        color: .indigo
                    )
                    StatusRow(
                        title: "限制状态 / Limit",
                        value: state.codexQuota.individualLimitDescription,
                        detail: state.codexQuota.rateLimitReachedType ?? "未报告限速 / No rate-limit stop reported",
                        color: state.codexQuota.rateLimitReachedType == nil ? .green : .red
                    )
                }
            }
        }
    }

    private var sampleTimeValue: String {
        state.system.timestamp.formatted(date: .abbreviated, time: .standard)
    }

    private var resetContext: String {
        if let reset = state.codexQuota.resetsAt {
            return "重置 / Reset \(reset.formatted(date: .abbreviated, time: .shortened))"
        }
        return "重置未报告 / Reset not reported"
    }

    private var memoryDetail: String {
        guard let used = state.system.memoryUsedBytes, let total = state.system.memoryTotalBytes else {
            return "未报告 / Not reported"
        }
        return "\(ByteFormatterUtility.string(bytes: used)) / \(ByteFormatterUtility.string(bytes: total))"
    }

    private var diskDetail: String {
        "\(ByteFormatterUtility.string(bytes: state.system.diskCapacity.availableBytes)) 可用 / available"
    }

    private var diskUsedDetail: String {
        "\(ByteFormatterUtility.string(bytes: state.system.diskCapacity.availableBytes)) 可用 / \(ByteFormatterUtility.string(bytes: state.system.diskCapacity.totalBytes)) total"
    }

    private var codexDetail: String {
        if let reset = state.codexQuota.resetsAt {
            return "重置 / Reset \(reset.formatted(date: .abbreviated, time: .shortened))"
        }
        return "重置未报告 / Reset not reported"
    }

    private var codexRemainingValue: String {
        PercentFormatterUtility.string(state.codexQuota.remainingPercent)
    }

    private var batteryValue: String {
        PercentFormatterUtility.string(state.system.battery.percent)
    }

    private var batteryTint: Color {
        guard let percent = state.system.battery.percent else {
            return .secondary
        }
        if percent < 20 {
            return .red
        }
        if percent < 50 {
            return .orange
        }
        return .green
    }

    private var gpuValue: String {
        switch state.system.gpu {
        case let .available(gpu):
            return gpu.name
        case .unavailable:
            return "不可用 / Unavailable"
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

    private var gpuIsAvailable: Bool {
        if case .available = state.system.gpu {
            return true
        }
        return false
    }

    private var diskGrowthValue: String {
        guard let growth = state.diskGrowth.growthBytes else {
            return "学习中 / Learning"
        }
        return ByteFormatterUtility.signedString(bytes: growth)
    }

    private var diskGrowthColor: Color {
        guard let growth = state.diskGrowth.growthBytes else {
            return .secondary
        }
        return growth > 0 ? .orange : .green
    }

    private var diskRead24hValue: String {
        guard let bytes = state.system.diskIO.readBytes24h else {
            return "学习中 / Learning"
        }
        return ByteFormatterUtility.string(bytes: bytes)
    }

    private var diskWrite24hValue: String {
        guard let bytes = state.system.diskIO.writeBytes24h else {
            return "学习中 / Learning"
        }
        return ByteFormatterUtility.string(bytes: bytes)
    }

    private var readRateDetail: String {
        let rate = state.system.diskIO.readBytesPerSecond.map(ByteFormatterUtility.rate) ?? "学习中 / learning"
        return "实时读取 / Live read \(rate)"
    }

    private var writeRateDetail: String {
        let rate = state.system.diskIO.writeBytesPerSecond.map(ByteFormatterUtility.rate) ?? "学习中 / learning"
        return "实时写入 / Live write \(rate)"
    }

    private var cacheGrowthValue: String {
        guard let growth = state.cacheEstimate.growthBytes24h else {
            return "学习中 / Learning"
        }
        return ByteFormatterUtility.signedString(bytes: growth)
    }

    private var cacheGrowthColor: Color {
        guard let growth = state.cacheEstimate.growthBytes24h else {
            return .secondary
        }
        return growth > 0 ? .orange : .green
    }

    private var cacheGrowthDetailBilingual: String {
        if let share = state.cacheEstimate.growthShareOfDiskGrowth {
            return "\(bilingualStatus(state.cacheEstimate.statusText)) / \(PercentFormatterUtility.string(share)) 硬盘增长 / disk growth"
        }
        return bilingualStatus(state.cacheEstimate.statusText)
    }

    private var resetValue: String {
        state.codexQuota.resetsAt?.formatted(date: .abbreviated, time: .shortened) ?? "未报告 / Not reported"
    }

    private func bilingualStatus(_ text: String) -> String {
        switch text {
        case "Not reported":
            return "未报告 / Not reported"
        case "Unavailable":
            return "不可用 / Unavailable"
        case "No battery":
            return "无电池 / No battery"
        case "Charging":
            return "充电中 / Charging"
        case "On battery":
            return "电池供电 / On battery"
        case "No disk history yet":
            return "暂无硬盘历史 / No disk history yet"
        case "No disk I/O history yet":
            return "暂无读写历史 / No disk I/O history yet"
        case "No cache history yet":
            return "暂无缓存历史 / No cache history yet"
        case "24h history ready":
            return "24小时历史就绪 / 24h history ready"
        case "24h I/O history ready":
            return "24小时读写历史就绪 / 24h I/O history ready"
        case "24h cache history ready":
            return "24小时缓存历史就绪 / 24h cache history ready"
        case "Disk I/O counters reset":
            return "磁盘计数已重置 / Disk I/O counters reset"
        case "Disk I/O counters unavailable":
            return "磁盘读写计数不可用 / Disk I/O counters unavailable"
        case "IORegistry disk counters":
            return "IORegistry 磁盘计数 / IORegistry disk counters"
        case "local Codex log signal":
            return "本地 Codex 日志 / local Codex log signal"
        case "No local quota event found":
            return "未找到本地额度事件 / No local quota event found"
        case "GPU utilization unavailable through stable public API":
            return "稳定公开 API 不提供 GPU 占用率 / GPU utilization unavailable through stable public API"
        default:
            if text.hasPrefix("Learning:") {
                return "学习中 / \(text)"
            }
            return text
        }
    }
}

private struct StatusCenterPanel<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
        )
    }
}

private struct SummaryPill: View {
    var title: String
    var value: String
    var detail: String
    var tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricGauge: View {
    var title: String
    var value: String
    var percent: Double?
    var detail: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ProgressView(value: progressValue)
                .tint(tint)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var progressValue: Double {
        guard let percent else {
            return 0
        }
        return min(max(percent / 100, 0), 1)
    }
}

private struct StatusRow: View {
    var title: String
    var value: String
    var detail: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CacheDirectoryRow: View {
    var path: String
    var bytes: String

    var body: some View {
        HStack(spacing: 8) {
            Text(path)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(bytes)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.46), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct StatusDot: View {
    var label: String
    var color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
