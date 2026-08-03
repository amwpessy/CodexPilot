import Combine
import Foundation

@MainActor
final class PokerGame: ObservableObject {
    enum ActionType {
        case fold
        case call
        case raise
    }

    static let smallBlind = 25
    static let bigBlind = 50
    static let botBuyIn = 2_500
    static let maximumLogEntries = 120
    static let names = ["Codex 用户 / Codex User", "Lin", "Taka", "Jo"]
    static let tips = [
        "位置越靠后，掌握的信息越多 / Later position reveals more information.",
        "听牌时比较跟注成本与底池大小 / Compare draw odds with the price of a call.",
        "小对子未中三条时不必执着 / Small pairs are easy to release when they miss.",
        "同花听牌通常有 9 张提升牌 / A flush draw usually has nine outs.",
        "强牌也可以过牌，让对手继续投入 / Checking a strong hand can keep opponents involved.",
    ]

    @Published private(set) var players = PokerGame.names.enumerated().map {
        PokerPlayer(id: $0.offset, name: $0.element, chips: $0.offset == 0 ? 0 : PokerGame.botBuyIn)
    }
    @Published private(set) var community: [PokerCard] = []
    @Published private(set) var pot = 0
    @Published private(set) var currentBet = 0
    @Published private(set) var street = PokerStreet.idle
    @Published private(set) var dealer = 3
    @Published private(set) var handNo = 0
    @Published private(set) var locked = false
    @Published private(set) var finished = true
    @Published private(set) var logs: [PokerLogEntry] = []
    @Published private(set) var statusText = "登录后发牌 / Sign in to deal"
    @Published private(set) var tipText = ""
    @Published private(set) var lastResult: PokerHandResult?
    @Published private(set) var seatActions: [Int: String] = [:]
    @Published private(set) var actor = -1
    @Published private(set) var pendingSettlement: PendingPokerSettlement?
    @Published private(set) var settlementMessage: String?
    @Published private(set) var settlementError: String?
    @Published private(set) var soundOn: Bool
    @Published var raiseAmount: Double = 100

    private var deck: [PokerCard] = []
    private var totalContributions = Array(repeating: 0, count: 4)
    private var hasActed: Set<Int> = []
    private var safetyCounter = 0
    private var handStartingBalance = 0
    private var currentHandID = ""
    private var currentAccountID = ""
    private let settlementJournal: PokerSettlementJournal
    private static let soundDefaultsKey = "codexpilotPokerSoundEnabled"

    init(settlementJournal: PokerSettlementJournal = PokerSettlementJournal()) {
        self.settlementJournal = settlementJournal
        soundOn = UserDefaults.standard.object(forKey: Self.soundDefaultsKey) as? Bool ?? true
    }

    var you: PokerPlayer { players[0] }
    var owed: Int { max(0, currentBet - players[0].bet) }
    var canAct: Bool { !finished && !locked && !players[0].folded && players[0].chips > 0 }
    var callTitle: String {
        owed > 0 ? "跟注 \(points(min(owed, players[0].chips))) / Call" : "过牌 / Check"
    }
    var dealTitle: String { handNo > 0 ? "下一手 / Next" : "发牌 / Deal" }
    var minRaise: Int { max(PokerGame.bigBlind, currentBet + PokerGame.bigBlind) }
    var raiseCap: Int { min(1_000, players[0].chips + players[0].bet) }
    var maxRaise: Int { max(minRaise, raiseCap) }
    var canRaise: Bool { canAct && raiseCap >= minRaise }
    var isAwaitingSettlement: Bool { pendingSettlement != nil }

    func points(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    func syncBankroll(_ balance: Int) {
        guard finished, pendingSettlement == nil else { return }
        players[0].chips = max(0, balance)
        if balance <= 0 {
            statusText = "积分已用完，暂时不能继续 / No points left to play"
        } else if handNo == 0 {
            statusText = "准备发牌 / Ready to deal"
        }
    }

    func restorePendingSettlement(for accountID: String) {
        guard finished else { return }
        currentAccountID = accountID
        pendingSettlement = settlementJournal.pending(for: accountID)
        if pendingSettlement != nil {
            locked = false
            settlementMessage = "正在恢复上次结算 / Restoring settlement"
            settlementError = nil
            statusText = "发现待结算牌局，正在重试 / Retrying pending hand"
        }
    }

    func startHand(bankroll: Int, accountID: String) {
        guard finished, !locked, pendingSettlement == nil else { return }
        guard bankroll > 0 else {
            syncBankroll(0)
            return
        }
        currentAccountID = accountID
        Task { await runStartHand(bankroll: bankroll) }
    }

    func playerAction(_ type: ActionType) {
        guard canAct else { return }
        Task { await runHumanAction(type) }
    }

    func toggleSound() {
        soundOn.toggle()
        UserDefaults.standard.set(soundOn, forKey: Self.soundDefaultsKey)
        if soundOn {
            playSound(.chip)
        }
    }

    func completeSettlement(_ receipt: PokerSettlementReceipt) {
        guard let pending = pendingSettlement, receipt.handId == pending.id else { return }
        settlementJournal.clear(accountID: currentAccountID, handID: pending.id)
        players[0].chips = receipt.pointsBalance
        pendingSettlement = nil
        locked = false
        settlementError = nil
        let signed = receipt.appliedDelta > 0 ? "+\(points(receipt.appliedDelta))" : points(receipt.appliedDelta)
        settlementMessage = "已结算 \(signed) 分 · 余额 \(points(receipt.pointsBalance)) / Settled"
        if receipt.dailyRemaining == 0 {
            statusText = "今日赢分已达上限 / Daily win limit reached"
        } else if receipt.pointsBalance == 0 {
            statusText = "积分已用完，暂时不能继续 / No points left to play"
        }
    }

    func failSettlement(_ message: String) {
        guard pendingSettlement != nil else { return }
        locked = false
        settlementError = message
        settlementMessage = nil
        statusText = "结算未完成，请重试 / Settlement needs retry"
    }

    var handStrengthLabel: String {
        let cards = players[0].cards + community
        if players[0].cards.isEmpty { return "尚未发牌 / No cards" }
        if players[0].folded { return "已弃牌 / Folded" }
        if cards.count < 5 {
            let first = players[0].cards[0]
            let second = players[0].cards[1]
            if first.value == second.value { return "口袋对子 / Pocket Pair" }
            if first.value >= 12, second.value >= 10 { return "两张大牌 / Broadway" }
            if abs(first.value - second.value) == 1 { return "连张 / Connectors" }
            return "高牌 / High Card"
        }
        return PokerHandEvaluator.categories[PokerHandEvaluator.bestScore(cards)[0]]
    }

    var outsLabel: String {
        let cards = players[0].cards + community
        guard players[0].cards.count == 2 else { return "—" }
        if players[0].folded { return "等待下一手 / Waiting" }
        if cards.count < 5 {
            return players[0].cards.map { $0.rank + $0.suit.rawValue }.joined(separator: " · ")
        }
        if community.count < 5 {
            let score = PokerHandEvaluator.bestScore(cards)
            let known = Set(cards.map(\.id))
            let outs = PokerCard.fullDeck().filter {
                !known.contains($0.id)
                    && PokerHandEvaluator.compare(PokerHandEvaluator.bestScore(cards + [$0]), score) > 0
            }.count
            return outs > 0 ? "约 \(outs) 张提升牌 / \(outs) outs" : "当前已成牌 / Made hand"
        }
        return "最终牌型 / Final hand"
    }

    private func runStartHand(bankroll: Int) async {
        locked = true
        finished = false
        handNo += 1
        lastResult = nil
        settlementMessage = nil
        settlementError = nil
        dealer = (dealer + 1) % players.count
        deck = PokerCard.fullDeck().shuffled()
        community = []
        pot = 0
        currentBet = PokerGame.bigBlind
        street = .preflop
        logs = []
        seatActions = [:]
        totalContributions = Array(repeating: 0, count: players.count)
        handStartingBalance = max(0, bankroll)
        currentHandID = UUID().uuidString.lowercased()

        for index in players.indices {
            if index == 0 {
                players[index].chips = handStartingBalance
            } else if players[index].chips < PokerGame.bigBlind {
                players[index].chips = PokerGame.botBuyIn
            }
            players[index].cards = [deck.removeLast(), deck.removeLast()]
            players[index].folded = false
            players[index].bet = 0
        }

        let smallBlindSeat = (dealer + 1) % players.count
        let bigBlindSeat = (dealer + 2) % players.count
        tipText = PokerGame.tips[(handNo - 1) % PokerGame.tips.count]
        log("第 \(handNo) 手 / Hand \(handNo)", "按钮位 / Button: \(players[dealer].displayName)")
        let smallBlind = contribute(smallBlindSeat, PokerGame.smallBlind)
        log(players[smallBlindSeat].displayName, "小盲 \(points(smallBlind)) / Small blind")
        let bigBlind = contribute(bigBlindSeat, PokerGame.bigBlind)
        log(players[bigBlindSeat].displayName, "大盲 \(points(bigBlind)) / Big blind")
        playSound(.deal)
        resetRaiseSlider()
        await pause(280)
        await beginBetting()
    }

    private func runHumanAction(_ type: ActionType) async {
        locked = true
        switch type {
        case .fold:
            players[0].folded = true
            showAction(0, "弃牌 / Fold")
            log("你 / You", "弃牌 / Fold")
            playSound(.fold)
        case .call:
            let due = toCall(for: 0)
            let paid = contribute(0, due)
            let text = due > 0 ? "跟注 \(points(paid)) / Call" : "过牌 / Check"
            showAction(0, text)
            log("你 / You", text)
            playSound(.chip)
        case .raise:
            let target = min(max(Int(raiseAmount), minRaise), raiseCap)
            _ = contribute(0, max(0, target - players[0].bet))
            currentBet = max(currentBet, players[0].bet)
            let text = "加注至 \(points(players[0].bet)) / Raise"
            showAction(0, text)
            log("你 / You", text)
            playSound(.chip)
        }
        hasActed.insert(0)
        await pause(260)
        actor = nextActive(after: 0) ?? 0
        await actAndAdvance()
    }

    private func beginBetting() async {
        hasActed = []
        safetyCounter = 0
        actor = nextActive(after: dealer) ?? dealer
        await actAndAdvance()
    }

    private func actAndAdvance() async {
        safetyCounter += 1
        if safetyCounter > 4_000 {
            finishByFold(activePlayers().first ?? players[0])
            return
        }
        guard !finished else { return }
        if activePlayers().count == 1 {
            finishByFold(activePlayers()[0])
            return
        }
        if bettingRoundOver() {
            await endBettingRound()
            return
        }

        let currentActor = actor
        if players[currentActor].folded || players[currentActor].chips == 0 {
            hasActed.insert(currentActor)
            actor = nextActive(after: currentActor) ?? currentActor
            await actAndAdvance()
            return
        }
        if currentActor == 0 {
            locked = false
            statusText = owed > 0
                ? "轮到你，需跟 \(points(owed)) 分 / Your turn: call \(points(owed))"
                : "轮到你行动 / Your turn"
            return
        }

        locked = true
        await botAct(currentActor)
        hasActed.insert(currentActor)
        await pause(220)
        actor = nextActive(after: currentActor) ?? currentActor
        await actAndAdvance()
    }

    private func endBettingRound() async {
        if activePlayers().count == 1 {
            finishByFold(activePlayers()[0])
        } else if street == .river {
            showdown()
        } else {
            await nextStreet()
        }
    }

    private func botAct(_ index: Int) async {
        let player = players[index]
        let due = toCall(for: index)
        let stack = player.chips
        let equity = estimateEquity(player)
        let potOdds = due > 0 ? Double(due) / Double(max(1, pot + due)) : 0

        if due == 0 {
            if equity > 0.66 || (Double.random(in: 0..<1) < 0.1 && stack > 0) {
                let target = min(1_000, min(stack + player.bet, max(PokerGame.bigBlind, pot / 2)))
                commitRaise(index, target)
                let text = "下注 \(points(players[index].bet)) / Bet"
                showAction(index, text)
                log(player.displayName, text)
                playSound(.chip)
            } else {
                showAction(index, "过牌 / Check")
                log(player.displayName, "过牌 / Check")
            }
            return
        }

        if equity > potOdds + 0.1 {
            if equity > 0.72, stack > due {
                let target = min(1_000, min(stack + player.bet, currentBet + max(PokerGame.bigBlind, pot / 2)))
                commitRaise(index, target)
                let text = "加注至 \(points(players[index].bet)) / Raise"
                showAction(index, text)
                log(player.displayName, text)
                playSound(.chip)
            } else {
                let paid = contribute(index, due)
                let text = "跟注 \(points(paid)) / Call"
                showAction(index, text)
                log(player.displayName, text)
                playSound(.chip)
            }
        } else if equity > potOdds - 0.03, due <= max(PokerGame.bigBlind, pot / 5), Double.random(in: 0..<1) < 0.5 {
            let paid = contribute(index, due)
            let text = "跟注 \(points(paid)) / Call"
            showAction(index, text)
            log(player.displayName, text)
            playSound(.chip)
        } else {
            players[index].folded = true
            showAction(index, "弃牌 / Fold")
            log(player.displayName, "弃牌 / Fold")
            playSound(.fold)
        }
    }

    private func nextStreet() async {
        for index in players.indices {
            players[index].bet = 0
        }
        currentBet = 0
        switch street {
        case .preflop:
            street = .flop
            community.append(contentsOf: [deck.removeLast(), deck.removeLast(), deck.removeLast()])
        case .flop:
            street = .turn
            community.append(deck.removeLast())
        default:
            street = .river
            community.append(deck.removeLast())
        }
        log(street.label, community.map { $0.rank + $0.suit.rawValue }.joined(separator: " "))
        playSound(.deal)
        resetRaiseSlider()
        statusText = "\(street.label) · 公共牌已发出 / Board updated"
        await pause(360)
        await beginBetting()
    }

    private func showdown() {
        while community.count < 5 {
            community.append(deck.removeLast())
        }
        let originalPot = pot
        let scores = Dictionary(uniqueKeysWithValues: activePlayers().map {
            ($0.id, PokerHandEvaluator.bestScore($0.cards + community))
        })
        var winnerIDs = Set<Int>()
        for layer in sidePotLayers() {
            let eligible = layer.eligible.filter { scores[$0] != nil }
            guard let bestScore = eligible.compactMap({ scores[$0] }).max(by: {
                PokerHandEvaluator.compare($0, $1) < 0
            }) else { continue }
            let winners = eligible.filter { PokerHandEvaluator.compare(scores[$0] ?? [0], bestScore) == 0 }.sorted()
            distribute(layer.amount, among: winners)
            winnerIDs.formUnion(winners)
        }

        let primaryWinner = winnerIDs.sorted().first ?? activePlayers().first?.id ?? 0
        let primaryScore = scores[primaryWinner] ?? [0]
        let names = winnerIDs.sorted().map { players[$0].displayName }.joined(separator: "、")
        var winningCards = Set<PokerCard.ID>()
        for winner in winnerIDs {
            for card in PokerHandEvaluator.bestHand(players[winner].cards + community) {
                winningCards.insert(card.id)
            }
        }
        let handType = PokerHandEvaluator.categories[primaryScore[0]]
        lastResult = PokerHandResult(
            winnerName: names,
            isYou: winnerIDs.contains(0),
            handType: handType,
            potAmount: originalPot,
            reason: "摊牌 / Showdown",
            winningCardIds: winningCards,
            winningPlayerIds: winnerIDs
        )
        log("摊牌 / Showdown", "\(names) · \(handType)")
        statusText = "\(names) 赢得底池 / \(names) wins"
        playSound(.win)
        finishHand()
    }

    private func finishByFold(_ winner: PokerPlayer) {
        let originalPot = pot
        players[winner.id].chips += pot
        lastResult = PokerHandResult(
            winnerName: winner.displayName,
            isYou: winner.isHuman,
            handType: "对手全部弃牌 / Everyone folded",
            potAmount: originalPot,
            reason: "收下底池 / Pot awarded",
            winningCardIds: [],
            winningPlayerIds: [winner.id]
        )
        log("本手结束 / Hand over", "\(winner.displayName) 收下 \(points(originalPot))")
        statusText = "\(winner.displayName) 收下底池 / Pot awarded"
        playSound(.win)
        finishHand()
    }

    private func finishHand() {
        pot = 0
        finished = true
        locked = true
        actor = -1
        let settlement = PendingPokerSettlement(
            id: currentHandID,
            requestedDelta: players[0].chips - handStartingBalance,
            tableBalance: players[0].chips
        )
        pendingSettlement = settlement
        settlementJournal.save(settlement, for: currentAccountID)
        settlementMessage = "正在同步积分 / Syncing points"
        settlementError = nil
    }

    private func sidePotLayers() -> [(amount: Int, eligible: [Int])] {
        let levels = Set(totalContributions.filter { $0 > 0 }).sorted()
        var previous = 0
        return levels.compactMap { level in
            let contributors = players.indices.filter { totalContributions[$0] >= level }
            let amount = (level - previous) * contributors.count
            previous = level
            guard amount > 0 else { return nil }
            return (amount, contributors.filter { !players[$0].folded })
        }
    }

    private func distribute(_ amount: Int, among winners: [Int]) {
        guard !winners.isEmpty else { return }
        let base = amount / winners.count
        var remainder = amount % winners.count
        for winner in winners {
            players[winner].chips += base + (remainder > 0 ? 1 : 0)
            remainder = max(0, remainder - 1)
        }
    }

    private func estimateEquity(_ player: PokerPlayer) -> Double {
        let known = player.cards + community
        guard known.count >= 2 else { return 0.5 }
        let dead = Set(known.map(\.id))
        let opponents = activePlayers().filter { $0.id != player.id }.count
        guard opponents > 0 else { return 1 }
        var wins = 0
        var ties = 0
        let trials = 120
        for _ in 0..<trials {
            var trialDeck = PokerCard.fullDeck().filter { !dead.contains($0.id) }.shuffled()
            var board = community
            for _ in 0..<max(0, 5 - board.count) {
                board.append(trialDeck.removeLast())
            }
            let myScore = PokerHandEvaluator.bestScore(player.cards + board)
            var best = true
            var tied = false
            for _ in 0..<opponents {
                let opponent = [trialDeck.removeLast(), trialDeck.removeLast()]
                let comparison = PokerHandEvaluator.compare(PokerHandEvaluator.bestScore(opponent + board), myScore)
                if comparison > 0 {
                    best = false
                    break
                }
                if comparison == 0 {
                    tied = true
                }
            }
            if best && tied { ties += 1 }
            if best && !tied { wins += 1 }
        }
        return (Double(wins) + Double(ties) * 0.5) / Double(trials)
    }

    private func activePlayers() -> [PokerPlayer] {
        players.filter { !$0.folded }
    }

    private func nextActive(after index: Int) -> Int? {
        for offset in 1...players.count {
            let candidate = (index + offset) % players.count
            if !players[candidate].folded, players[candidate].chips > 0 {
                return candidate
            }
        }
        return nil
    }

    private func bettingRoundOver() -> Bool {
        let contenders = players.indices.filter { !players[$0].folded && players[$0].chips > 0 }
        guard !contenders.isEmpty else { return true }
        return contenders.allSatisfy { hasActed.contains($0) }
            && contenders.allSatisfy { players[$0].bet == currentBet }
    }

    private func toCall(for index: Int) -> Int {
        max(0, currentBet - players[index].bet)
    }

    @discardableResult
    private func contribute(_ index: Int, _ amount: Int) -> Int {
        let paid = min(max(0, amount), players[index].chips)
        players[index].chips -= paid
        players[index].bet += paid
        totalContributions[index] += paid
        pot += paid
        return paid
    }

    private func commitRaise(_ index: Int, _ target: Int) {
        let total = min(target, players[index].chips + players[index].bet)
        _ = contribute(index, max(0, total - players[index].bet))
        currentBet = max(currentBet, players[index].bet)
    }

    private func resetRaiseSlider() {
        let upper = max(minRaise, (maxRaise / PokerGame.bigBlind) * PokerGame.bigBlind)
        if Int(raiseAmount) < minRaise || Int(raiseAmount) > upper {
            raiseAmount = Double(minRaise)
        }
    }

    private func log(_ title: String, _ detail: String = "") {
        logs.append(PokerLogEntry(title: title, detail: detail))
        if logs.count > PokerGame.maximumLogEntries {
            logs.removeFirst(logs.count - PokerGame.maximumLogEntries)
        }
    }

    private func playSound(_ effect: PokerSoundEffect) {
        guard soundOn else { return }
        PokerSoundPlayer.shared.play(effect)
    }

    private func showAction(_ id: Int, _ text: String) {
        seatActions[id] = text
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            if seatActions[id] == text {
                seatActions[id] = nil
            }
        }
    }

    private func pause(_ milliseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}
