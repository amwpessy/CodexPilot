import SwiftUI

struct ShuihuCardGameView: View {
    @ObservedObject private var account = CommunityAccountStore.shared
    @State private var filter: CollectionFilter = .all
    @State private var selectedCardID: Int?
    @State private var lastReceipt: ShuihuDrawReceipt?
    @State private var isDrawing = false
    @State private var cardRotation = 0.0
    @State private var feedback: String?

    let onOpenCommunity: () -> Void

    private let contentHeight: CGFloat = 484

    var body: some View {
        VStack(spacing: 0) {
            scoreRail
            Divider().overlay(Color.black.opacity(0.16))

            HStack(alignment: .top, spacing: 14) {
                drawStage
                    .frame(width: 350, height: contentHeight, alignment: .top)

                collectionPanel
                    .frame(maxWidth: .infinity, minHeight: contentHeight, maxHeight: contentHeight, alignment: .top)
            }
            .frame(height: contentHeight, alignment: .top)
            .padding(14)

            Text("积分仅供娱乐且不可兑换现金。108 张卡出现概率相同；属性为依据小说事迹的相对评分，并非官方数值。 / Points have no cash value. All 108 cards have equal odds; ratings are editorial estimates based on the novel.")
                .font(.system(size: 10))
                .foregroundStyle(Color.black.opacity(0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.89, blue: 0.72),
                    Color(red: 0.84, green: 0.77, blue: 0.58),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.25)))
        .frame(height: 630)
        .environment(\.colorScheme, .light)
        .task(id: account.account?.id) {
            guard account.isAuthenticated else { return }
            await account.refreshShuihuStatus()
            selectInitialCard()
        }
        .onChange(of: account.shuihuStatus?.uniqueCount) { _ in
            selectInitialCard()
        }
    }

    private var scoreRail: some View {
        HStack(spacing: 0) {
            ShuihuScoreMetric(
                icon: "seal.fill",
                title: "账户积分 / Points",
                value: format(account.account?.pointsBalance ?? 0),
                tint: Color(red: 0.68, green: 0.08, blue: 0.08)
            )
            railDivider
            ShuihuScoreMetric(
                icon: "rectangle.stack.fill",
                title: "已集齐 / Unique",
                value: "\(status?.uniqueCount ?? 0) / \(ShuihuCardCatalog.all.count)",
                tint: Color(red: 0.05, green: 0.35, blue: 0.32)
            )
            railDivider
            ShuihuScoreMetric(
                icon: "clock.fill",
                title: "今日抽卡 / Draws Today",
                value: "\(status?.drawsUsed ?? 0) / \(status?.dailyLimit ?? ShuihuCardCatalog.dailyDrawLimit)",
                tint: Color(red: 0.10, green: 0.28, blue: 0.58)
            )
            railDivider

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("聚义进度 / Set Progress", systemImage: "star.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.58))
                    Spacer()
                    Text("\(Int(collectionProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.68, green: 0.08, blue: 0.08))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.42, blue: 0.36),
                                        Color(red: 0.91, green: 0.58, blue: 0.06),
                                        Color(red: 0.72, green: 0.07, blue: 0.07),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(3, proxy.size.width * collectionProgress))
                    }
                }
                .frame(height: 7)
                Text(status?.rewardClaimed == true
                     ? "百万积分奖励已领取 / Reward claimed"
                     : "集齐奖励 \(format(ShuihuCardCatalog.completionReward)) 分 / Completion reward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.54))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 66)

            Button {
                Task { await account.refreshShuihuStatus() }
            } label: {
                Image(systemName: account.isShuihuSyncing ? "hourglass" : "arrow.clockwise")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.black.opacity(0.72))
            .disabled(!account.isAuthenticated || account.isShuihuSyncing)
            .help("同步卡册 / Refresh collection")
            .padding(.trailing, 12)
        }
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.52))
    }

    private var railDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.14))
            .frame(width: 1, height: 42)
    }

    private var drawStage: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("聚义抽卡台")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    Text("HERO MUSTER · EQUAL ODDS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                Spacer()
                Text("★ \(format(ShuihuCardCatalog.drawCost)) 积分")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            }

            ZStack {
                Color.black.opacity(0.08)

                ZStack {
                    ShuihuCardBack()
                        .opacity(cardRotation < 90 ? 1 : 0)
                    if let card = displayedCard {
                        ShuihuCardFace(
                            card: card,
                            copies: status?.copies(of: card.id) ?? max(lastReceipt?.copies ?? 0, 1),
                            compact: false
                        )
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(cardRotation >= 90 ? 1 : 0)
                    }
                }
                .frame(width: 210, height: 300)
                .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 7)

                if isDrawing {
                    VStack {
                        RetroScanline()
                            .frame(width: 204, height: 3)
                        Spacer()
                    }
                    .padding(.top, 22)
                    .transition(.opacity)
                }
            }
            .frame(height: 318)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.18)))

            if let feedback {
                Text(feedback)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(feedbackTint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 30)
            } else {
                Text(drawHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }

            Button(action: drawCard) {
                HStack(spacing: 8) {
                    Image(systemName: isDrawing ? "sparkles" : "rectangle.stack.badge.plus")
                    Text(drawButtonTitle)
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.70, green: 0.07, blue: 0.06))
            .disabled(!canDraw)

            if !account.isAuthenticated {
                Button(action: onOpenCommunity) {
                    Label("前往登录 / Go to Sign In", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.link)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.16)))
    }

    private var collectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("水浒一百单八将卡册 / Water Margin 108")
                        .font(.system(size: 17, weight: .bold))
                    Text("天罡 36 · 地煞 72 · 重复卡保留张数")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                Spacer()
                Picker("筛选 / Filter", selection: $filter) {
                    ForEach(CollectionFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 270)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 132), spacing: 10)],
                    spacing: 12
                ) {
                    ForEach(filteredCards) { card in
                        collectionCardButton(card)
                    }
                }
                .padding(2)
            }
            .frame(height: 400)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.10)))
        }
        .padding(14)
        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.16)))
    }

    private var status: ShuihuCollectionStatus? {
        account.shuihuStatus
    }

    private var filteredCards: [ShuihuCardDefinition] {
        ShuihuCardCatalog.all.filter { card in
            let collected = (status?.copies(of: card.id) ?? 0) > 0
            switch filter {
            case .all: return true
            case .collected: return collected
            case .missing: return !collected
            }
        }
    }

    private var displayedCard: ShuihuCardDefinition? {
        if let cardID = lastReceipt?.cardId {
            return ShuihuCardCatalog.definition(id: cardID)
        }
        if let selectedCardID {
            return ShuihuCardCatalog.definition(id: selectedCardID)
        }
        return nil
    }

    private func collectionCardButton(_ card: ShuihuCardDefinition) -> some View {
        let copies = status?.copies(of: card.id) ?? 0
        return Button {
            guard copies > 0 else { return }
            selectedCardID = card.id
            lastReceipt = nil
            cardRotation = 180
            feedback = nil
        } label: {
            Group {
                if copies > 0 {
                    ShuihuCardFace(card: card, copies: copies, compact: true)
                } else {
                    ShuihuLockedCard(card: card)
                }
            }
        }
        .buttonStyle(.plain)
        .help(copies > 0 ? "\(card.nickname) \(card.name) · \(copies) 张" : "尚未获得 / Not collected")
    }

    private var collectionProgress: Double {
        Double(status?.uniqueCount ?? 0) / Double(ShuihuCardCatalog.all.count)
    }

    private var canDraw: Bool {
        account.isAuthenticated
            && status != nil
            && !account.isShuihuSyncing
            && !isDrawing
            && (status?.drawsRemaining ?? 0) > 0
            && (account.account?.pointsBalance ?? 0) >= ShuihuCardCatalog.drawCost
    }

    private var drawButtonTitle: String {
        if isDrawing { return "聚义星光中… / Drawing…" }
        return "消耗 1,000 积分抽一张 / Draw One Card"
    }

    private var drawHint: String {
        if account.isRestoring || (account.isAuthenticated && status == nil) {
            return "正在同步卡册 / Syncing collection"
        }
        if !account.isAuthenticated {
            return "登录后可使用账户积分抽卡 / Sign in to draw"
        }
        if (status?.drawsRemaining ?? 0) <= 0 {
            return "今日 10 次已用完，中国时区 00:00 重置 / Daily limit reached"
        }
        if (account.account?.pointsBalance ?? 0) < ShuihuCardCatalog.drawCost {
            return "积分不足 1,000 / Not enough points"
        }
        return "今日剩余 \(status?.drawsRemaining ?? 0) 次 · 每位武将概率 1/108"
    }

    private var feedbackTint: Color {
        lastReceipt?.rewardGranted == true
            ? Color(red: 0.68, green: 0.08, blue: 0.08)
            : Color(red: 0.08, green: 0.32, blue: 0.28)
    }

    private func selectInitialCard() {
        guard selectedCardID == nil else { return }
        if let first = status?.collection.first(where: { $0.copies > 0 }) {
            selectedCardID = first.cardId
            cardRotation = 180
        }
    }

    private func drawCard() {
        guard canDraw else { return }
        let requestID = UUID().uuidString.lowercased()
        isDrawing = true
        lastReceipt = nil
        feedback = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            cardRotation = 0
        }

        Task {
            do {
                let receipt = try await account.drawShuihuCard(requestID: requestID)
                lastReceipt = receipt
                selectedCardID = receipt.cardId
                withAnimation(.easeInOut(duration: 0.62)) {
                    cardRotation = 180
                }
                try? await Task.sleep(nanoseconds: 650_000_000)
                if receipt.rewardGranted {
                    feedback = "聚义圆满！已获得 1,000,000 积分 / Collection complete!"
                } else if receipt.isNew {
                    feedback = "新武将入册！第 \(receipt.uniqueCount) / 108 张"
                } else {
                    feedback = "重复卡 · 当前共 \(receipt.copies) 张 / Duplicate"
                }
            } catch let error as CommunityServiceError {
                feedback = drawErrorMessage(error)
                cardRotation = displayedCard == nil ? 0 : 180
            } catch {
                feedback = "网络连接失败，请重试 / Network error"
                cardRotation = displayedCard == nil ? 0 : 180
            }
            isDrawing = false
        }
    }

    private func drawErrorMessage(_ error: CommunityServiceError) -> String {
        switch error {
        case let .server(_, code) where code == "insufficient_points":
            return "积分不足 1,000 / Not enough points"
        case let .server(_, code) where code == "daily_draw_limit":
            return "今日 10 次已用完 / Daily draw limit reached"
        case let .server(_, code) where code == "login_required":
            return "登录已失效，请重新登录 / Session expired"
        default:
            return "抽卡暂时失败，请重试 / Draw failed"
        }
    }

    private func format(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

private enum CollectionFilter: String, CaseIterable, Identifiable {
    case all
    case collected
    case missing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部 / All"
        case .collected: return "已获得 / Owned"
        case .missing: return "未获得 / Missing"
        }
    }
}

private struct ShuihuScoreMetric: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.52))
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(minWidth: 145, minHeight: 66, alignment: .leading)
    }
}

private struct ShuihuCardFace: View {
    let card: ShuihuCardDefinition
    let copies: Int
    let compact: Bool

    private var palette: ShuihuCardPalette {
        ShuihuCardPalette(index: card.rank)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 248
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 5 : 7)
                    .fill(palette.paper)

                RetroSunburst(primary: palette.primary, secondary: palette.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7))

                VStack(spacing: compact ? 3 * scale : 6) {
                    cardHeader(scale: scale)
                    retroPortrait(scale: scale)

                    Text("\(card.nickname) · \(card.name)")
                        .font(.system(size: compact ? 12 : 20, weight: .black, design: .rounded))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    if !compact {
                        Text(card.signature)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.ink.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        HStack(spacing: 4) {
                            Label(card.weapon, systemImage: weaponSymbol)
                            Spacer(minLength: 4)
                            Text(card.role)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.ink.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                        attributeGrid
                    } else {
                        HStack(spacing: 4) {
                            Text("统\(card.command)")
                            Text("武\(card.might)")
                            Text("智\(card.wisdom)")
                            Text("魅\(card.charisma)")
                        }
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(palette.ink.opacity(0.82))
                    }
                }
                .padding(compact ? 6 : 11)
            }
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 5 : 7)
                    .stroke(palette.ink, lineWidth: compact ? 2 : 3)
            )
            .overlay(alignment: .bottomTrailing) {
                Text("×\(copies)")
                    .font(.system(size: compact ? 9 : 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 5 : 7)
                    .padding(.vertical, 3)
                    .background(palette.ink, in: RoundedRectangle(cornerRadius: 3))
                    .padding(compact ? 5 : 8)
            }
        }
        .aspectRatio(0.70, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.star)，\(card.nickname)\(card.name)，统御\(card.command)，武力\(card.might)，智力\(card.wisdom)，魅力\(card.charisma)，共\(copies)张")
    }

    private func cardHeader(scale: CGFloat) -> some View {
        HStack(alignment: .center) {
            Text(String(format: "%03d", card.rank))
                .font(.system(size: compact ? 8 : 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 4 : 7)
                .padding(.vertical, compact ? 2 : 4)
                .background(palette.ink, in: RoundedRectangle(cornerRadius: 3))
            Text(card.star)
                .font(.system(size: compact ? 8 : 12, weight: .black))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Spacer()
            Image(systemName: card.isHeavenlySpirit ? "star.fill" : "sparkle")
                .foregroundStyle(palette.accent)
                .font(.system(size: compact ? 9 : 14, weight: .black))
        }
    }

    private func retroPortrait(scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.secondary.opacity(0.92))
            HalftoneDots(color: palette.ink.opacity(0.20))

            Image(systemName: weaponSymbol)
                .font(.system(size: compact ? 36 : 72, weight: .black))
                .foregroundStyle(palette.primary.opacity(0.28))
                .rotationEffect(.degrees(card.rank.isMultiple(of: 2) ? -18 : 18))
                .offset(x: card.rank.isMultiple(of: 2) ? -28 * scale : 28 * scale)

            RetroHeroPortrait(card: card, palette: palette)
                .padding(.top, compact ? 5 : 8)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(compact ? 1.22 : 1.30, contentMode: .fit)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.ink, lineWidth: compact ? 1.5 : 2.5))
    }

    private var attributeGrid: some View {
        HStack(spacing: 4) {
            attribute("统", "CMD", card.command, palette.primary)
            attribute("武", "MGT", card.might, palette.accent)
            attribute("智", "WIS", card.wisdom, palette.secondary)
            attribute("魅", "CHA", card.charisma, Color(red: 0.73, green: 0.12, blue: 0.22))
        }
    }

    private func attribute(_ chinese: String, _ english: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(chinese) \(value)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
            Text(english)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .opacity(0.62)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(palette.ink.opacity(0.12))
                    Rectangle()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 3)
        }
        .foregroundStyle(palette.ink)
        .frame(maxWidth: .infinity)
    }

    private var weaponSymbol: String {
        let value = card.weapon
        if value.contains("弓") || value.contains("弩") || value.contains("箭") { return "scope" }
        if value.contains("扇") || value.contains("令旗") || value.contains("帅旗") { return "flag.fill" }
        if value.contains("炮") || value.contains("雷") { return "burst.fill" }
        if value.contains("水") || value.contains("鱼") || value.contains("叉") { return "drop.fill" }
        if value.contains("火") { return "flame.fill" }
        if value.contains("医") || value.contains("针") || value.contains("药") || value.contains("葫芦") { return "cross.case.fill" }
        if value.contains("笔") || value.contains("书") || value.contains("算盘") || value.contains("刻刀") { return "pencil.and.outline" }
        if value.contains("锤") || value.contains("棒") || value.contains("锏") || value.contains("鞭") { return "hammer.fill" }
        if value.contains("符") || value.contains("古剑") { return "sparkles" }
        if value.contains("拳") || value.contains("铁头") { return "figure.martial.arts" }
        if value.contains("索") || value.contains("钩") { return "link" }
        return "shield.lefthalf.filled"
    }
}

private struct ShuihuLockedCard: View {
    let card: ShuihuCardDefinition

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.22, green: 0.21, blue: 0.18))
            HalftoneDots(color: Color.white.opacity(0.10))
            VStack(spacing: 8) {
                Text(String(format: "%03d", card.rank))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                Image(systemName: "questionmark")
                    .font(.system(size: 31, weight: .black))
                Text(card.isHeavenlySpirit ? "天罡待聚" : "地煞待聚")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color(red: 0.82, green: 0.76, blue: 0.61))
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.72), lineWidth: 2))
        .aspectRatio(0.70, contentMode: .fit)
        .accessibilityLabel("第\(card.rank)张，尚未获得")
    }
}

private struct ShuihuCardBack: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(red: 0.70, green: 0.07, blue: 0.06))
            RetroSunburst(
                primary: Color(red: 0.92, green: 0.67, blue: 0.10),
                secondary: Color(red: 0.09, green: 0.30, blue: 0.27)
            )
            VStack(spacing: 14) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 66, weight: .black))
                Text("聚 义")
                    .font(.system(size: 35, weight: .black, design: .rounded))
                Text("水浒一百单八将")
                    .font(.system(size: 15, weight: .bold))
                Text("HERO MUSTER · 108")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundStyle(Color(red: 0.98, green: 0.89, blue: 0.60))
            .shadow(color: .black.opacity(0.34), radius: 0, x: 2, y: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.82), lineWidth: 3))
        .aspectRatio(0.70, contentMode: .fit)
    }
}

private struct RetroHeroPortrait: View {
    let card: ShuihuCardDefinition
    let palette: ShuihuCardPalette

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Capsule()
                    .fill(palette.primary)
                    .frame(width: width * 0.62, height: height * 0.58)
                    .offset(y: height * 0.32)
                    .overlay(
                        Capsule()
                            .stroke(palette.ink, lineWidth: 3)
                            .frame(width: width * 0.62, height: height * 0.58)
                            .offset(y: height * 0.32)
                    )

                Circle()
                    .fill(Color(red: 0.93, green: 0.69, blue: 0.47))
                    .frame(width: width * 0.34)
                    .overlay(Circle().stroke(palette.ink, lineWidth: 3))
                    .offset(y: -height * 0.07)

                headwear(width: width, height: height)
                face(width: width, height: height)
                beard(width: width, height: height)

                Text(card.nickname.prefix(1))
                    .font(.system(size: max(11, width * 0.09), weight: .black, design: .rounded))
                    .foregroundStyle(palette.paper)
                    .padding(5)
                    .background(palette.ink, in: Circle())
                    .offset(x: width * 0.25, y: -height * 0.26)
            }
        }
    }

    @ViewBuilder
    private func headwear(width: CGFloat, height: CGFloat) -> some View {
        switch card.rank % 6 {
        case 0:
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.ink)
                .frame(width: width * 0.31, height: height * 0.10)
                .offset(y: -height * 0.22)
        case 1:
            Image(systemName: "crown.fill")
                .font(.system(size: width * 0.20, weight: .black))
                .foregroundStyle(palette.accent)
                .overlay(Image(systemName: "crown").font(.system(size: width * 0.20, weight: .black)).foregroundStyle(palette.ink))
                .offset(y: -height * 0.24)
        case 2:
            Capsule()
                .fill(palette.accent)
                .frame(width: width * 0.37, height: height * 0.09)
                .overlay(Capsule().stroke(palette.ink, lineWidth: 3))
                .offset(y: -height * 0.21)
        case 3:
            Image(systemName: "mountain.2.fill")
                .font(.system(size: width * 0.23, weight: .black))
                .foregroundStyle(palette.ink)
                .offset(y: -height * 0.23)
        case 4:
            RoundedRectangle(cornerRadius: 5)
                .fill(palette.secondary)
                .frame(width: width * 0.25, height: height * 0.16)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.ink, lineWidth: 3))
                .offset(y: -height * 0.23)
        default:
            Image(systemName: "flame.fill")
                .font(.system(size: width * 0.20, weight: .black))
                .foregroundStyle(palette.accent)
                .overlay(Image(systemName: "flame").font(.system(size: width * 0.20, weight: .black)).foregroundStyle(palette.ink))
                .offset(y: -height * 0.25)
        }
    }

    private func face(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.08) {
            Capsule().fill(palette.ink).frame(width: width * 0.055, height: 4)
            Capsule().fill(palette.ink).frame(width: width * 0.055, height: 4)
        }
        .rotationEffect(.degrees(card.rank.isMultiple(of: 3) ? -5 : 5))
        .offset(y: -height * 0.08)
    }

    @ViewBuilder
    private func beard(width: CGFloat, height: CGFloat) -> some View {
        if card.rank % 4 != 0 {
            Capsule()
                .fill(palette.ink)
                .frame(width: width * (card.rank % 4 == 1 ? 0.20 : 0.13), height: height * 0.14)
                .offset(y: height * 0.09)
        } else {
            Capsule()
                .stroke(palette.ink, lineWidth: 3)
                .frame(width: width * 0.12, height: height * 0.055)
                .offset(y: height * 0.035)
        }
    }
}

private struct RetroSunburst: View {
    let primary: Color
    let secondary: Color

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(primary.opacity(0.10)))
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.36)
            let radius = max(size.width, size.height) * 1.25
            for index in 0..<20 where index.isMultiple(of: 2) {
                let start = Double(index) * .pi / 10
                let end = Double(index + 1) * .pi / 10
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + cos(start) * radius, y: center.y + sin(start) * radius))
                path.addLine(to: CGPoint(x: center.x + cos(end) * radius, y: center.y + sin(end) * radius))
                path.closeSubpath()
                context.fill(path, with: .color(secondary.opacity(0.22)))
            }
        }
    }
}

private struct HalftoneDots: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 11
            var y: CGFloat = 5
            while y < size.height {
                var x: CGFloat = 5 + (Int(y / spacing).isMultiple(of: 2) ? 0 : spacing / 2)
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2.4, height: 2.4)),
                        with: .color(color)
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RetroScanline: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.84))
            .shadow(color: Color(red: 0.93, green: 0.58, blue: 0.08), radius: 8)
            .offset(y: offset)
            .onAppear {
                offset = 0
                withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                    offset = 320
                }
            }
    }
}

private struct ShuihuCardPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let paper: Color
    let ink: Color

    init(index: Int) {
        let palettes: [(Color, Color, Color)] = [
            (Color(red: 0.72, green: 0.07, blue: 0.06), Color(red: 0.94, green: 0.62, blue: 0.08), Color(red: 0.08, green: 0.34, blue: 0.30)),
            (Color(red: 0.05, green: 0.35, blue: 0.33), Color(red: 0.90, green: 0.42, blue: 0.07), Color(red: 0.74, green: 0.08, blue: 0.15)),
            (Color(red: 0.10, green: 0.28, blue: 0.58), Color(red: 0.86, green: 0.68, blue: 0.12), Color(red: 0.74, green: 0.12, blue: 0.08)),
            (Color(red: 0.48, green: 0.16, blue: 0.42), Color(red: 0.10, green: 0.48, blue: 0.46), Color(red: 0.94, green: 0.54, blue: 0.07)),
            (Color(red: 0.16, green: 0.38, blue: 0.18), Color(red: 0.74, green: 0.14, blue: 0.08), Color(red: 0.90, green: 0.68, blue: 0.10)),
            (Color(red: 0.09, green: 0.40, blue: 0.55), Color(red: 0.78, green: 0.20, blue: 0.10), Color(red: 0.96, green: 0.68, blue: 0.08)),
        ]
        let selected = palettes[(index - 1) % palettes.count]
        primary = selected.0
        secondary = selected.1
        accent = selected.2
        paper = Color(red: 0.96, green: 0.88, blue: 0.68)
        ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    }
}
