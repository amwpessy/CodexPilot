import SwiftUI

private struct CockpitTheme: Equatable {
    static let storageKey = "dashboardSportThemeEnabled"

    var sportMode: Bool

    var backgroundTop: Color {
        sportMode ? Color(red: 0.045, green: 0.047, blue: 0.052) : Color(red: 0.965, green: 0.970, blue: 0.978)
    }

    var backgroundBottom: Color {
        sportMode ? Color(red: 0.010, green: 0.011, blue: 0.014) : Color(red: 0.900, green: 0.915, blue: 0.935)
    }

    var panel: Color {
        sportMode ? Color(red: 0.085, green: 0.088, blue: 0.096) : Color(red: 0.925, green: 0.935, blue: 0.950).opacity(0.92)
    }

    var panelRaised: Color {
        sportMode ? Color(red: 0.125, green: 0.128, blue: 0.138) : Color.white.opacity(0.96)
    }

    var carbon: Color {
        sportMode ? Color(red: 0.020, green: 0.022, blue: 0.026) : Color(red: 0.945, green: 0.952, blue: 0.965)
    }

    static let redline = Color(red: 0.91, green: 0.06, blue: 0.045)
    static let amber = Color(red: 1.0, green: 0.58, blue: 0.12)
    static let cyan = Color(red: 0.14, green: 0.78, blue: 0.92)
    static let green = Color(red: 0.12, green: 0.84, blue: 0.34)

    var text: Color {
        sportMode ? Color.white.opacity(0.92) : Color(red: 0.105, green: 0.115, blue: 0.130)
    }

    var secondaryText: Color {
        sportMode ? Color.white.opacity(0.58) : Color(red: 0.390, green: 0.420, blue: 0.460)
    }

    var hairline: Color {
        sportMode ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    var modeLabel: String {
        sportMode ? "SPORT MODE" : "NORMAL MODE"
    }

    var overlayAccent: Color {
        sportMode ? Self.redline : Color.accentColor
    }

    var dashboardBackground: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DashboardThemeKey: EnvironmentKey {
    static let defaultValue = CockpitTheme(sportMode: false)
}

private extension EnvironmentValues {
    var dashboardTheme: CockpitTheme {
        get { self[DashboardThemeKey.self] }
        set { self[DashboardThemeKey.self] = newValue }
    }
}

struct DashboardView: View {
    @ObservedObject var state: AppState
    @AppStorage(CockpitTheme.storageKey) private var sportThemeEnabled = false

    private var theme: CockpitTheme {
        CockpitTheme(sportMode: sportThemeEnabled)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBand

                HStack(alignment: .top, spacing: 14) {
                    systemHealthColumn
                        .frame(minWidth: 220, maxWidth: 260, alignment: .top)
                    diskAnalysisColumn
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .top)
                    codexColumn
                        .frame(minWidth: 260, maxWidth: 300, alignment: .top)
                }

                cacheColumn
            }
            .padding(18)
        }
        .background(theme.dashboardBackground)
        .environment(\.dashboardTheme, theme)
        .frame(minWidth: 1_040, minHeight: 620)
        .preferredColorScheme(sportThemeEnabled ? .dark : .light)
        .id(sportThemeEnabled)
    }

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sportThemeEnabled ? "CodexPilot Sport Cockpit" : "Codex 驾驶舱 / CodexPilot")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.text)
                    Text("采样时间 / Sample \(sampleTimeValue)  |  \(resetContext)")
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                HStack(spacing: 2) {
                    themeModeButton(title: "Normal 模式", systemImage: "macwindow", sportMode: false)
                    themeModeButton(title: "Sport 模式", systemImage: "gauge.with.dots.needle.67percent", sportMode: true)
                }
                .padding(2)
                .background(theme.panelRaised.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.hairline, lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .help("切换主界面主题 / Toggle dashboard theme")

                Text(theme.modeLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.overlayAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.carbon, in: Capsule())

                StatusDot(label: "运行中 / Active", color: .green)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                SummaryPill(
                    title: "处理器 / CPU",
                    value: PercentFormatterUtility.string(state.system.cpuUsage),
                    detail: "实时采样 / Live sample",
                    progress: normalizedPercent(state.system.cpuUsage),
                    trend: trendValues(\.cpuUsage),
                    tint: CockpitTheme.redline
                )
                SummaryPill(
                    title: "内存 / Memory",
                    value: PercentFormatterUtility.string(state.system.memoryUsedPercent),
                    detail: memoryDetail,
                    progress: normalizedPercent(state.system.memoryUsedPercent),
                    trend: trendValues(\.memoryUsedPercent),
                    tint: CockpitTheme.cyan
                )
                SummaryPill(
                    title: "硬盘 / Disk",
                    value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent),
                    detail: diskDetail,
                    progress: normalizedPercent(state.system.diskCapacity.usedPercent),
                    trend: trendValues(\.diskUsedPercent),
                    tint: CockpitTheme.amber
                )
                SummaryPill(
                    title: "硬盘读写 / Disk I/O",
                    value: diskIOHeaderValue,
                    detail: diskIOHeaderDetail,
                    progress: normalizedPercent(latestDiskIOActivityPercent),
                    trend: trendValues(\.diskIOActivityPercent),
                    tint: CockpitTheme.green
                )
                SummaryPill(
                    title: "电池 / Battery",
                    value: batteryValue,
                    detail: bilingualStatus(state.system.battery.statusText),
                    progress: normalizedPercent(state.system.battery.percent),
                    trend: trendValues(\.batteryPercent),
                    tint: batteryTint
                )
                SummaryPill(
                    title: "Codex 额度 / Quota",
                    value: codexRemainingValue,
                    detail: codexDetail,
                    progress: normalizedPercent(state.codexQuota.remainingPercent),
                    trend: trendValues(\.codexRemainingPercent),
                    tint: .purple
                )
            }
        }
        .padding(16)
        .background(theme.carbon, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear, theme.overlayAccent.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
            .allowsHitTesting(false)
        )
    }

    private func themeModeButton(title: String, systemImage: String, sportMode: Bool) -> some View {
        let selected = sportThemeEnabled == sportMode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                sportThemeEnabled = sportMode
            }
            UserDefaults.standard.set(sportMode, forKey: CockpitTheme.storageKey)
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        }) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(selected ? theme.text : theme.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(width: 112)
                .background(
                    selected ? theme.overlayAccent.opacity(sportMode ? 0.32 : 0.20) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func trendValues(_ keyPath: KeyPath<DashboardTrendSample, Double?>) -> [Double] {
        let points = state.dashboardTrendSamples.compactMap { sample -> Double? in
            guard let value = sample[keyPath: keyPath] else {
                return nil
            }
            return min(max(value / 100, 0), 1)
        }

        guard let first = points.first else {
            return []
        }
        return points.count == 1 ? [first, first] : points
    }

    private func normalizedPercent(_ percent: Double?) -> Double? {
        guard let percent else {
            return nil
        }
        return min(max(percent / 100, 0), 1)
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
                        tint: CockpitTheme.redline
                    )
                    MetricGauge(
                        title: "内存 / Memory",
                        value: PercentFormatterUtility.string(state.system.memoryUsedPercent),
                        percent: state.system.memoryUsedPercent,
                        detail: memoryDetail,
                        tint: CockpitTheme.cyan
                    )
                    MetricGauge(
                        title: "电池 / Battery",
                        value: batteryValue,
                        percent: state.system.battery.percent,
                        detail: bilingualStatus(state.system.battery.statusText),
                        tint: batteryTint
                    )
                }
            }
            .frame(height: 358, alignment: .top)
        }
    }

    private var diskAnalysisColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCenterPanel(title: "硬盘分析 / Disk Analysis", subtitle: "容量与读写 / Capacity & I/O") {
                VStack(spacing: 12) {
                    MetricGauge(
                        title: "硬盘使用 / Disk Used",
                        value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent),
                        percent: state.system.diskCapacity.usedPercent,
                        detail: diskUsedDetail,
                        tint: CockpitTheme.amber
                    )

                    HStack(spacing: 10) {
                        StatusRow(
                            title: "启动后增长 / Since Launch Growth",
                            value: diskGrowthValue,
                            detail: bilingualStatus(state.diskGrowth.statusText),
                            color: diskGrowthColor
                        )
                    }

                    Divider()

                    HStack(spacing: 10) {
                        StatusRow(
                            title: "启动后读取 / Since Launch Read",
                            value: diskRead24hValue,
                            detail: readRateDetail,
                            color: CockpitTheme.cyan
                        )
                        StatusRow(
                            title: "启动后写入 / Since Launch Write",
                            value: diskWrite24hValue,
                            detail: writeRateDetail,
                            color: CockpitTheme.redline
                        )
                    }
                }
            }
            .frame(height: 358, alignment: .top)
        }
    }

    private var cacheColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCenterPanel(title: "缓存清理 / Cache", subtitle: "缓存增长与清理 / Growth & cleanup") {
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 10) {
                            StatusRow(
                                title: "缓存增长 / Cache Growth",
                                value: cacheGrowthValue,
                                detail: cacheGrowthDetailBilingual,
                                color: cacheGrowthColor
                            )
                            StatusRow(
                                title: "缓存总量 / Cache Total",
                            value: ByteFormatterUtility.string(bytes: state.cacheEstimate.totalBytes),
                            detail: "可读缓存估算 / Readable cache estimate",
                            color: CockpitTheme.amber
                        )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            state.cleanCache()
                        }) {
                            Label(cleanCacheTitle, systemImage: "trash")
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CockpitTheme.redline)
                        .controlSize(.small)
                        .disabled(state.isCleaningCache)
                    }

                    if state.cacheEstimate.entries.isEmpty {
                        StatusRow(
                            title: "缓存目录 / Cache Paths",
                            value: "无数据 / No data",
                            detail: "等待下一次扫描 / Waiting for scan",
                            color: .secondary
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
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

                    Button(action: { state.chooseCodexLogDirectory() }) {
                        Label("授权日志目录 / Authorize Logs", systemImage: "folder.badge.gearshape")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .buttonStyle(.bordered)
                    .tint(CockpitTheme.amber)
                    .controlSize(.small)
                }
            }
            .frame(height: 358, alignment: .top)
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
            return CockpitTheme.amber
        }
        return CockpitTheme.green
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
        return growth > 0 ? CockpitTheme.amber : CockpitTheme.green
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

    private var diskIOHeaderValue: String {
        let read = state.system.diskIO.readBytesPerSecond.map { compactRate(bytesPerSecond: $0) } ?? "--"
        let write = state.system.diskIO.writeBytesPerSecond.map { compactRate(bytesPerSecond: $0) } ?? "--"
        return "R \(read) W \(write)"
    }

    private var diskIOHeaderDetail: String {
        "实时读写 / Live disk I/O"
    }

    private var latestDiskIOActivityPercent: Double? {
        state.dashboardTrendSamples.last?.diskIOActivityPercent
    }

    private func compactRate(bytesPerSecond: UInt64) -> String {
        let full = ByteFormatterUtility.rate(bytesPerSecond: bytesPerSecond)
        return full
            .replacingOccurrences(of: " KB/s", with: "K/s")
            .replacingOccurrences(of: " MB/s", with: "M/s")
            .replacingOccurrences(of: " GB/s", with: "G/s")
            .replacingOccurrences(of: " TB/s", with: "T/s")
            .replacingOccurrences(of: " B/s", with: "B/s")
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
        return growth > 0 ? CockpitTheme.amber : CockpitTheme.green
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

    private var cleanCacheTitle: String {
        state.isCleaningCache ? "清理中 / Cleaning" : "清理缓存 / Clean"
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
        case "Since launch disk history ready":
            return "本次启动硬盘历史就绪 / Since launch disk history ready"
        case "Since launch I/O ready":
            return "本次启动读写就绪 / Since launch I/O ready"
        case "Since launch cache history ready":
            return "本次启动缓存历史就绪 / Since launch cache history ready"
        case "Cache cleaned":
            return "缓存已清理 / Cache cleaned"
        case "Cache clean incomplete":
            return "缓存清理未完成 / Cache clean incomplete"
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
        case "No Codex JSONL files found":
            return "未找到 Codex JSONL 日志 / No Codex JSONL files found"
        case "No Codex quota event found in local logs":
            return "本地日志中未找到 Codex 额度事件 / No Codex quota event found in local logs"
        case "Codex log authorization failed":
            return "Codex 日志授权失败 / Codex log authorization failed"
        default:
            if text.hasPrefix("Learning:") {
                return "学习中 / \(text)"
            }
            return text
        }
    }
}

private struct StatusCenterPanel<Content: View>: View {
    @Environment(\.dashboardTheme) private var theme

    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.055), Color.clear, theme.overlayAccent.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
            .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 8)
    }
}

private struct SummaryPill: View {
    @Environment(\.dashboardTheme) private var theme

    var title: String
    var value: String
    var detail: String
    var progress: Double?
    var trend: [Double]
    var tint: Color

    var body: some View {
        Group {
            if theme.sportMode {
                SportSummaryGauge(
                    title: title,
                    value: value,
                    detail: detail,
                    progress: progress,
                    tint: tint
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(value)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        SparklineView(points: trend, tint: tint)
                            .frame(height: 24)

                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panelRaised.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct SportSummaryGauge: View {
    @Environment(\.dashboardTheme) private var theme

    var title: String
    var value: String
    var detail: String
    var progress: Double?
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(shortTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            ZStack {
                GaugeTicks(tickCount: 19)
                    .stroke(theme.hairline.opacity(0.88), lineWidth: 1)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)

                GaugeArc(progress: 1)
                    .stroke(theme.carbon, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .padding(.horizontal, 10)
                    .padding(.top, 5)

                GaugeArc(progress: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.45), tint, CockpitTheme.redline.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 5)

                GaugeNeedle(progress: progressValue)
                    .fill(tint.opacity(progress == nil ? 0.32 : 0.95))
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                Circle()
                    .fill(theme.panelRaised)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(tint.opacity(0.65), lineWidth: 1))
                    .offset(y: 19)
            }
            .frame(height: 54)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var progressValue: Double {
        min(max(progress ?? 0, 0), 1)
    }

    private var shortTitle: String {
        title.components(separatedBy: " / ").first ?? title
    }
}

private struct GaugeArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        let radius = min(rect.width * 0.44, rect.height * 0.95)
        let start = Angle.degrees(205)
        let end = Angle.degrees(205 + 130 * clamped)
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}

private struct GaugeTicks: Shape {
    var tickCount: Int

    func path(in rect: CGRect) -> Path {
        let count = max(tickCount, 2)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        let outerRadius = min(rect.width * 0.46, rect.height * 0.98)
        let innerRadius = outerRadius - 5
        var path = Path()

        for index in 0..<count {
            let fraction = Double(index) / Double(count - 1)
            let angle = CGFloat((205 + 130 * fraction) * .pi / 180)
            let outer = CGPoint(
                x: center.x + cos(angle) * outerRadius,
                y: center.y + sin(angle) * outerRadius
            )
            let inner = CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            )
            path.move(to: inner)
            path.addLine(to: outer)
        }

        return path
    }
}

private struct GaugeNeedle: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        let radius = min(rect.width * 0.38, rect.height * 0.78)
        let angle = CGFloat((205 + 130 * clamped) * .pi / 180)
        let tip = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
        let left = CGPoint(
            x: center.x + cos(angle + .pi / 2) * 3,
            y: center.y + sin(angle + .pi / 2) * 3
        )
        let right = CGPoint(
            x: center.x + cos(angle - .pi / 2) * 3,
            y: center.y + sin(angle - .pi / 2) * 3
        )

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }
}

private struct MetricGauge: View {
    @Environment(\.dashboardTheme) private var theme

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
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ZStack(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(theme.carbon)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progressValue))
                }
            }
            .frame(height: 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(Capsule())

            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(2)
        }
        .padding(10)
        .background(theme.panelRaised.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var progressValue: Double {
        guard let percent else {
            return 0
        }
        return min(max(percent / 100, 0), 1)
    }
}

private struct StatusRow: View {
    @Environment(\.dashboardTheme) private var theme

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
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Text(value)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panelRaised.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct SparklineView: View {
    @Environment(\.dashboardTheme) private var theme

    var points: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let normalized = normalizedPoints
            ZStack {
                Path { path in
                    let y = proxy.size.height * 0.5
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Path { path in
                    guard let first = normalized.first else {
                        return
                    }
                    path.move(to: point(for: first, index: 0, size: proxy.size, count: normalized.count))
                    for index in normalized.dropFirst().indices {
                        path.addLine(to: point(for: normalized[index], index: index, size: proxy.size, count: normalized.count))
                    }
                }
                .stroke(
                    LinearGradient(colors: [tint.opacity(0.55), tint], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private var normalizedPoints: [Double] {
        let clipped = points.map { min(max($0, 0), 1) }
        guard let first = clipped.first else {
            return [0.5, 0.5]
        }
        return clipped.count == 1 ? [first, first] : clipped
    }

    private func point(for value: Double, index: Int, size: CGSize, count: Int) -> CGPoint {
        let denominator = max(count - 1, 1)
        let x = size.width * CGFloat(index) / CGFloat(denominator)
        let y = size.height * CGFloat(1 - value)
        return CGPoint(x: x, y: y)
    }
}

private struct CacheDirectoryRow: View {
    @Environment(\.dashboardTheme) private var theme

    var path: String
    var bytes: String

    var body: some View {
        HStack(spacing: 8) {
            Text(path)
                .font(.caption)
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(bytes)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.panelRaised.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct StatusDot: View {
    @Environment(\.dashboardTheme) private var theme

    var label: String
    var color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.panelRaised.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
