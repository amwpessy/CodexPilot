import SwiftUI

struct PokerGameView: View {
    @ObservedObject private var account = CommunityAccountStore.shared
    @StateObject private var game = PokerGame()
    @State private var settlingHandID: String?

    let onOpenCommunity: () -> Void

    private let dailyLimitFallback = 7_500
    private let tableHeight: CGFloat = 386
    private let playAreaHeight: CGFloat = 464

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.065, blue: 0.075),
                    Color(red: 0.018, green: 0.022, blue: 0.026),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                scoreRail
                Divider().overlay(Color.white.opacity(0.09))

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 8) {
                        PokerTableView(game: game)
                            .frame(height: tableHeight)
                        PokerActionBar(game: game, canDeal: canDeal, onDeal: startHand)
                            .frame(height: 70)
                    }
                    .frame(maxWidth: .infinity, minHeight: playAreaHeight, maxHeight: playAreaHeight)

                    PokerSidePanel(game: game)
                        .frame(width: 248, height: playAreaHeight)
                }
                .frame(height: playAreaHeight)
                .padding(12)

                Text("林猫驾驶舱积分 · 仅供娱乐 · 不可兑换现金 / Lynncat Pilot points are for entertainment only and have no cash value")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .padding(.bottom, 10)
            }

            if let result = game.lastResult {
                PokerResultOverlay(
                    result: result,
                    settlement: game.pendingSettlement,
                    receiptMessage: game.settlementMessage,
                    errorMessage: game.settlementError,
                    canContinue: canDeal,
                    canRetry: game.pendingSettlement != nil && settlingHandID == nil,
                    onNext: startHand,
                    onRetry: settlePendingHand
                )
            } else if game.pendingSettlement != nil, account.isAuthenticated {
                pendingSettlementOverlay
            } else if blocker != nil {
                accessOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(height: 600)
        .task(id: account.account?.id) {
            guard account.isAuthenticated else {
                game.syncBankroll(0)
                return
            }
            await account.refreshPokerStatus()
            guard let accountID = account.account?.id else { return }
            game.restorePendingSettlement(for: accountID)
            game.syncBankroll(account.account?.pointsBalance ?? 0)
            if game.pendingSettlement != nil {
                settlePendingHand()
            }
        }
        .onChange(of: account.account?.pointsBalance) { balance in
            game.syncBankroll(balance ?? 0)
        }
        .onChange(of: game.pendingSettlement) { settlement in
            if settlement != nil {
                settlePendingHand()
            }
        }
        .background(PokerKeyboardShortcuts(game: game, canDeal: canDeal, onDeal: startHand))
    }

    private var scoreRail: some View {
        HStack(spacing: 0) {
            PokerScoreMetric(
                icon: "person.crop.circle.fill",
                title: "账户积分 / Points",
                value: format(account.account?.pointsBalance ?? 0),
                tint: .white
            )
            railDivider
            PokerScoreMetric(
                icon: "chart.line.uptrend.xyaxis",
                title: "今日赢得 / Won Today",
                value: "\(format(account.pokerStatus?.dailyWon ?? 0)) / \(format(dailyLimit))",
                tint: .green
            )
            railDivider
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("每日额度 / Daily Limit", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Text("\(Int(dailyProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(3, proxy.size.width * dailyProgress))
                    }
                }
                .frame(height: 7)
                Text("剩余 \(format(dailyRemaining)) 分 / \(format(dailyRemaining)) remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 66)

            railDivider
            PokerScoreMetric(
                icon: "rectangle.stack.fill",
                title: "牌局 / Hand",
                value: game.handNo == 0 ? "READY" : "#\(game.handNo)",
                tint: .orange
            )

            Button {
                game.toggleSound()
            } label: {
                Image(systemName: game.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(game.soundOn ? Color.pokerGold : Color.white.opacity(0.45))
            .help(game.soundOn ? "关闭音效 / Mute sound" : "开启音效 / Enable sound")

            Button {
                Task {
                    await account.refreshPokerStatus()
                    game.syncBankroll(account.account?.pointsBalance ?? 0)
                }
            } label: {
                Image(systemName: account.isPokerSyncing ? "hourglass" : "arrow.clockwise")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.8))
            .disabled(!account.isAuthenticated || account.isPokerSyncing || !game.finished)
            .help("同步积分 / Refresh points")
            .padding(.trailing, 12)
        }
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.24))
    }

    private var railDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 42)
    }

    private var accessOverlay: some View {
        ZStack {
            Color.black.opacity(0.62)
            VStack(spacing: 14) {
                Image(systemName: blocker?.icon ?? "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(blocker?.tint ?? Color.orange)
                Text(blocker?.title ?? "")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(blocker?.detail ?? "")
                    .font(.callout)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                if !account.isAuthenticated {
                    Button(action: onOpenCommunity) {
                        Label("前往登录 / Go to Sign In", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
            .background(Color(red: 0.08, green: 0.095, blue: 0.11), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        }
    }

    private var pendingSettlementOverlay: some View {
        ZStack {
            Color.black.opacity(0.62)
            VStack(spacing: 14) {
                Image(systemName: game.settlementError == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(game.settlementError == nil ? Color.cyan : Color.orange)
                Text("正在恢复牌局结算 / Restoring Settlement")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(
                    game.settlementError
                        ?? "上次牌局尚未完成服务器结算，完成前不能开始新牌局。/ The previous hand must settle before another can begin."
                )
                    .font(.callout)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                if game.settlementError != nil {
                    Button(action: settlePendingHand) {
                        Label("重试结算 / Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(settlingHandID != nil)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(28)
            .background(Color(red: 0.08, green: 0.095, blue: 0.11), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        }
    }

    private var blocker: (title: String, detail: String, icon: String, tint: Color)? {
        if account.isRestoring || (account.isAuthenticated && account.pokerStatus == nil) {
            return (
                "正在同步积分 / Syncing Points",
                "正在读取账户余额与今日赢分记录。",
                "arrow.triangle.2.circlepath",
                .cyan
            )
        }
        if !account.isAuthenticated {
            return (
                "登录后进入积分牌桌 / Sign In to Play",
                "牌桌直接使用林猫驾驶舱账户积分，输完后不能继续游戏。",
                "person.crop.circle.badge.exclamationmark",
                .orange
            )
        }
        if (account.account?.pointsBalance ?? 0) <= 0 {
            return (
                "积分已用完 / No Points Left",
                "保持林猫驾驶舱运行可继续获得积分，余额大于 0 后即可再次发牌。",
                "gauge.with.dots.needle.0percent",
                .red
            )
        }
        if dailyRemaining <= 0 {
            return (
                "今日赢分已达 7,500 / Daily Limit Reached",
                "为保持公平，今天不能再开始新牌局；额度将在中国时区次日 00:00 重置。",
                "checkmark.seal.fill",
                .green
            )
        }
        return nil
    }

    private var canDeal: Bool {
        account.isAuthenticated
            && account.pokerStatus != nil
            && (account.account?.pointsBalance ?? 0) > 0
            && dailyRemaining > 0
            && game.finished
            && !game.locked
            && game.pendingSettlement == nil
    }

    private var dailyLimit: Int {
        account.pokerStatus?.dailyLimit ?? dailyLimitFallback
    }

    private var dailyRemaining: Int {
        account.pokerStatus?.dailyRemaining ?? 0
    }

    private var dailyProgress: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(max(Double(account.pokerStatus?.dailyWon ?? 0) / Double(dailyLimit), 0), 1)
    }

    private func startHand() {
        guard canDeal, let accountID = account.account?.id else { return }
        game.startHand(bankroll: account.account?.pointsBalance ?? 0, accountID: accountID)
    }

    private func settlePendingHand() {
        guard let pending = game.pendingSettlement, settlingHandID == nil else { return }
        settlingHandID = pending.id
        Task {
            do {
                let receipt = try await account.settlePokerHand(
                    handId: pending.id,
                    delta: pending.requestedDelta
                )
                game.completeSettlement(receipt)
            } catch let error as CommunityServiceError {
                game.failSettlement(settlementErrorMessage(error))
            } catch {
                game.failSettlement("网络连接失败，请重试 / Network error. Please retry.")
            }
            settlingHandID = nil
        }
    }

    private func settlementErrorMessage(_ error: CommunityServiceError) -> String {
        switch error {
        case let .server(_, code) where code == "login_required":
            return "登录已失效，请重新登录 / Session expired. Please sign in again."
        case let .server(_, code) where code == "invalid_hand_delta":
            return "牌局数据未通过校验 / Hand result was rejected."
        default:
            return "结算暂时失败，请重试 / Settlement failed. Please retry."
        }
    }

    private func format(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

private struct PokerScoreMetric: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
    }
}

private struct PokerTableView: View {
    @ObservedObject var game: PokerGame

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                tableSurface(width: width, height: height)

                VStack(spacing: 10) {
                    Text("底池 / POT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.52))
                    Text("\(game.points(game.pot)) PTS")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pokerGold)
                    HStack(spacing: 7) {
                        ForEach(0..<5, id: \.self) { index in
                            PokerCardView(
                                card: index < game.community.count ? game.community[index] : nil,
                                highlighted: index < game.community.count
                                    && (game.lastResult?.winningCardIds.contains(game.community[index].id) ?? false)
                            )
                        }
                    }
                    Text(game.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 390)
                }
                .position(x: width / 2, y: height * 0.48)

                if game.players.count == 4 {
                    seat(game.players[1]).position(x: width * 0.15, y: height * 0.22)
                    seat(game.players[2]).position(x: width * 0.5, y: height * 0.12)
                    seat(game.players[3]).position(x: width * 0.85, y: height * 0.22)
                    seat(game.players[0], reveal: true, compact: false)
                        .position(x: width * 0.5, y: height * 0.84)
                }
            }
        }
    }

    private func seat(_ player: PokerPlayer, reveal: Bool = false, compact: Bool = true) -> some View {
        PokerPlayerSeat(
            player: player,
            isDealer: player.id == game.dealer,
            isTurn: player.id == game.actor,
            revealCards: (reveal || (game.lastResult?.winningPlayerIds.contains(player.id) ?? false)) && !player.folded,
            actionText: game.seatActions[player.id],
            compact: compact,
            isWinner: game.lastResult?.winningPlayerIds.contains(player.id) ?? false,
            winningCardIDs: game.lastResult?.winningCardIds ?? []
        )
    }

    private func tableSurface(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.pokerRailLight, .pokerRailDark], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [.pokerFeltLight, .pokerFeltDark],
                        center: .center,
                        startRadius: 12,
                        endRadius: max(width, height) * 0.68
                    )
                )
                .padding(12)
            Capsule()
                .stroke(Color.pokerGold.opacity(0.48), lineWidth: 1.5)
                .padding(19)
        }
        .padding(2)
    }
}

private struct PokerCardView: View {
    let card: PokerCard?
    var faceDown = false
    var size = CGSize(width: 58, height: 82)
    var highlighted = false

    var body: some View {
        ZStack {
            if let card, !faceDown {
                face(card)
            } else if faceDown {
                back
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(highlighted ? 1.05 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: highlighted)
    }

    private func face(_ card: PokerCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
                .fill(Color(white: 0.98))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
                .stroke(highlighted ? Color.pokerGold : Color.black.opacity(0.12), lineWidth: highlighted ? 2.5 : 1)
            VStack {
                HStack {
                    corner(card)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    corner(card).rotationEffect(.degrees(180))
                }
            }
            .padding(size.width * 0.09)
            Text(card.suit.rawValue)
                .font(.system(size: size.width * 0.42))
                .foregroundStyle(card.suit.color)
        }
    }

    private func corner(_ card: PokerCard) -> some View {
        VStack(spacing: -2) {
            Text(card.rank).font(.system(size: size.width * 0.25, weight: .bold, design: .rounded))
            Text(card.suit.rawValue).font(.system(size: size.width * 0.18))
        }
        .foregroundStyle(card.suit.color)
    }

    private var back: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.22, blue: 0.38), Color(red: 0.035, green: 0.08, blue: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                .padding(4)
            Image(systemName: "command")
                .font(.system(size: size.width * 0.28, weight: .bold))
                .foregroundStyle(Color.pokerGold.opacity(0.72))
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
            .fill(Color.white.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: min(8, size.width * 0.12))
                    .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
    }
}

private struct PokerPlayerSeat: View {
    let player: PokerPlayer
    let isDealer: Bool
    let isTurn: Bool
    let revealCards: Bool
    let actionText: String?
    let compact: Bool
    let isWinner: Bool
    let winningCardIDs: Set<PokerCard.ID>

    private var cardSize: CGSize {
        compact ? CGSize(width: 36, height: 51) : CGSize(width: 54, height: 76)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                if player.cards.isEmpty {
                    PokerCardView(card: nil, size: cardSize)
                    PokerCardView(card: nil, size: cardSize)
                } else {
                    ForEach(player.cards) { card in
                        PokerCardView(
                            card: card,
                            faceDown: !revealCards,
                            size: cardSize,
                            highlighted: winningCardIDs.contains(card.id)
                        )
                    }
                }
            }
            HStack(spacing: 6) {
                if isDealer {
                    badge("D")
                }
                if isWinner {
                    badge("★")
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isWinner ? Color.pokerGold : .white)
                    Text("\(player.chips.formatted()) PTS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pokerGold)
                    if player.bet > 0, !player.folded {
                        Text("本轮 \(player.bet.formatted()) / Bet")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.pokerGold.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.5), in: Capsule())
            .overlay(
                Capsule().stroke(
                    isWinner || isTurn ? Color.pokerGold : Color.white.opacity(0.14),
                    lineWidth: isWinner ? 2.5 : (isTurn ? 2 : 1)
                )
            )
        }
        .opacity(player.folded ? 0.38 : 1)
        .scaleEffect(isWinner ? 1.06 : (isTurn ? 1.03 : 1))
        .shadow(color: isWinner || isTurn ? Color.pokerGold.opacity(0.48) : .clear, radius: 13)
        .animation(.easeInOut(duration: 0.22), value: isTurn)
        .animation(.easeInOut(duration: 0.22), value: isWinner)
        .overlay(alignment: .top) {
            if let actionText {
                Text(actionText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.08, green: 0.42, blue: 0.31), in: Capsule())
                    .offset(y: -24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 17, height: 17)
            .background(Color.pokerGold, in: Circle())
    }
}

private struct PokerActionBar: View {
    @ObservedObject var game: PokerGame
    let canDeal: Bool
    let onDeal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("当前牌力 / Hand")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.48))
                Text(game.handStrengthLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(game.outsLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.52))
            }
            .frame(width: 175, alignment: .leading)

            if game.canRaise {
                VStack(alignment: .leading, spacing: 4) {
                    Text("加注至 \(Int(raiseValue).formatted()) / Raise")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pokerGold)
                    Slider(value: raiseBinding, in: raiseRange)
                        .tint(.green)
                        .frame(minWidth: 120, maxWidth: 200)
                }
            } else {
                Spacer(minLength: 8)
            }

            actionButton("弃牌 / Fold", icon: "xmark", tint: .red, enabled: game.canAct) {
                game.playerAction(.fold)
            }
            actionButton(game.callTitle, icon: "checkmark", tint: .blue, enabled: game.canAct) {
                game.playerAction(.call)
            }
            actionButton("加注 / Raise", icon: "arrow.up", tint: .green, enabled: game.canRaise) {
                game.playerAction(.raise)
            }
            actionButton(game.dealTitle, icon: "rectangle.stack.fill", tint: .orange, enabled: canDeal) {
                onDeal()
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.28))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
    }

    private var raiseRange: ClosedRange<Double> {
        let lower = Double(game.minRaise)
        let upper = max(lower, Double((game.maxRaise / PokerGame.bigBlind) * PokerGame.bigBlind))
        return lower...upper
    }

    private var raiseValue: Double {
        min(max(game.raiseAmount, raiseRange.lowerBound), raiseRange.upperBound)
    }

    private var raiseBinding: Binding<Double> {
        Binding(
            get: { raiseValue },
            set: {
                let snapped = round($0 / Double(PokerGame.bigBlind)) * Double(PokerGame.bigBlind)
                game.raiseAmount = min(max(snapped, raiseRange.lowerBound), raiseRange.upperBound)
            }
        )
    }

    private func actionButton(
        _ title: String,
        icon: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 46)
            .background(enabled ? tint.opacity(0.78) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(enabled ? 0.18 : 0.06)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
    }
}

private struct PokerSidePanel: View {
    @ObservedObject var game: PokerGame
    @State private var showRanks = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("牌局记录 / Hand Log", systemImage: "list.bullet.rectangle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if game.logs.isEmpty {
                            VStack(spacing: 7) {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 24))
                                Text("等待发牌 / Ready")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Color.white.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 42)
                        }
                        ForEach(game.logs) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.pokerGold)
                                if !entry.detail.isEmpty {
                                    Text(entry.detail)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.68))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                            .id(entry.id)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .onChange(of: game.logs.count) { _ in
                    if let id = game.logs.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.1))
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showRanks.toggle()
                }
            } label: {
                HStack {
                    Label("牌型 / Hand Ranks", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showRanks ? 90 : 0))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if showRanks {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(PokerHandEvaluator.categories.enumerated().reversed()), id: \.offset) { index, name in
                        HStack(spacing: 7) {
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 15, height: 15)
                                .background(Color.pokerGold, in: Circle())
                            Text(name)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }
                }
            }

            if !game.tipText.isEmpty {
                Divider().overlay(Color.white.opacity(0.1))
                Label(game.tipText, systemImage: "lightbulb.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.24))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
        }
    }
}

private struct PokerResultOverlay: View {
    let result: PokerHandResult
    let settlement: PendingPokerSettlement?
    let receiptMessage: String?
    let errorMessage: String?
    let canContinue: Bool
    let canRetry: Bool
    let onNext: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.66)
            VStack(spacing: 13) {
                Image(systemName: result.isYou ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(result.isYou ? Color.pokerGold : Color.white.opacity(0.82))
                Text(result.isYou ? "你赢了这一手 / You Won" : "\(result.winnerName) 获胜 / Wins")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(result.handType)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.pokerGold, in: Capsule())
                Text("底池 \(result.potAmount.formatted()) PTS · \(result.reason)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button(action: onRetry) {
                        Label("重试结算 / Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRetry)
                } else if settlement != nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(receiptMessage ?? "正在同步积分 / Syncing points")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                } else {
                    Text(receiptMessage ?? "积分已同步 / Points synced")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                    Button(action: onNext) {
                        Label("下一手 / Next Hand", systemImage: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!canContinue)
                }
            }
            .padding(28)
            .frame(width: 430)
            .background(Color(red: 0.07, green: 0.085, blue: 0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pokerGold.opacity(0.42)))
            .shadow(color: .black.opacity(0.55), radius: 28, y: 14)
        }
    }
}

private struct PokerKeyboardShortcuts: View {
    @ObservedObject var game: PokerGame
    let canDeal: Bool
    let onDeal: () -> Void

    var body: some View {
        ZStack {
            Button("") { if game.canAct { game.playerAction(.fold) } }
                .keyboardShortcut("f", modifiers: [])
            Button("") { if game.canAct { game.playerAction(.call) } }
                .keyboardShortcut("c", modifiers: [])
            Button("") { if game.canRaise { game.playerAction(.raise) } }
                .keyboardShortcut("r", modifiers: [])
            Button("") { if canDeal { onDeal() } }
                .keyboardShortcut(.defaultAction)
        }
        .opacity(0)
    }
}

private extension Color {
    static let pokerGold = Color(red: 0.97, green: 0.76, blue: 0.22)
    static let pokerRailLight = Color(red: 0.34, green: 0.22, blue: 0.12)
    static let pokerRailDark = Color(red: 0.12, green: 0.075, blue: 0.04)
    static let pokerFeltLight = Color(red: 0.055, green: 0.43, blue: 0.29)
    static let pokerFeltDark = Color(red: 0.018, green: 0.14, blue: 0.095)
}
