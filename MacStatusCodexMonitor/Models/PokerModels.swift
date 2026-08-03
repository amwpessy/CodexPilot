import Foundation
import SwiftUI

enum PokerSuit: String, CaseIterable {
    case spade = "♠"
    case heart = "♥"
    case diamond = "♦"
    case club = "♣"

    var color: Color {
        switch self {
        case .heart, .diamond:
            return Color(red: 0.82, green: 0.12, blue: 0.18)
        case .spade, .club:
            return Color(red: 0.08, green: 0.09, blue: 0.11)
        }
    }
}

struct PokerCard: Identifiable, Equatable, Hashable {
    let suit: PokerSuit
    let rank: String
    let value: Int

    var id: String { rank + suit.rawValue }

    static func fullDeck() -> [PokerCard] {
        let ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
        return PokerSuit.allCases.flatMap { suit in
            ranks.enumerated().map { index, rank in
                PokerCard(suit: suit, rank: rank, value: index + 2)
            }
        }
    }
}

struct PokerPlayer: Identifiable {
    let id: Int
    let name: String
    var chips: Int
    var cards: [PokerCard] = []
    var folded = false
    var bet = 0

    var isHuman: Bool { id == 0 }
    var displayName: String { isHuman ? "你 / You" : name }
}

enum PokerStreet {
    case idle
    case preflop
    case flop
    case turn
    case river

    var label: String {
        switch self {
        case .idle: return "等待 / Ready"
        case .preflop: return "翻牌前 / Pre-flop"
        case .flop: return "翻牌 / Flop"
        case .turn: return "转牌 / Turn"
        case .river: return "河牌 / River"
        }
    }
}

struct PokerLogEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct PokerHandResult: Equatable {
    let winnerName: String
    let isYou: Bool
    let handType: String
    let potAmount: Int
    let reason: String
    let winningCardIds: Set<PokerCard.ID>
    let winningPlayerIds: Set<Int>
}

struct PendingPokerSettlement: Identifiable, Equatable, Codable {
    let id: String
    let requestedDelta: Int
    let tableBalance: Int
}

struct PokerSettlementJournal {
    private static let storageKey = "codexpilotPokerPendingSettlementsV1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pending(for accountID: String) -> PendingPokerSettlement? {
        settlements()[accountID]
    }

    func save(_ settlement: PendingPokerSettlement, for accountID: String) {
        guard !accountID.isEmpty else { return }
        var values = settlements()
        values[accountID] = settlement
        persist(values)
    }

    func clear(accountID: String, handID: String) {
        var values = settlements()
        guard values[accountID]?.id == handID else { return }
        values[accountID] = nil
        persist(values)
    }

    private func settlements() -> [String: PendingPokerSettlement] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: PendingPokerSettlement].self, from: data)) ?? [:]
    }

    private func persist(_ values: [String: PendingPokerSettlement]) {
        if values.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

enum PokerHandEvaluator {
    static let categories = [
        "高牌 / High Card",
        "一对 / Pair",
        "两对 / Two Pair",
        "三条 / Three of a Kind",
        "顺子 / Straight",
        "同花 / Flush",
        "葫芦 / Full House",
        "四条 / Four of a Kind",
        "同花顺 / Straight Flush",
    ]

    static func scoreFive(_ cards: [PokerCard]) -> [Int] {
        guard cards.count == 5 else { return [0] }
        let values = cards.map(\.value).sorted(by: >)
        var counts: [Int: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }
        let groups = counts.map { (value: $0.key, count: $0.value) }
            .sorted { left, right in
                left.count != right.count ? left.count > right.count : left.value > right.value
            }
        let flush = cards.allSatisfy { $0.suit == cards[0].suit }
        var unique = Array(Set(values)).sorted(by: >)
        if unique.first == 14 {
            unique.append(1)
        }
        var straightHigh = 0
        if unique.count >= 5 {
            for index in 0...(unique.count - 5) where unique[index] - unique[index + 4] == 4 {
                straightHigh = unique[index]
                break
            }
        }

        if flush && straightHigh > 0 { return [8, straightHigh] }
        if groups[0].count == 4 { return [7, groups[0].value, groups[1].value] }
        if groups[0].count == 3, groups.count > 1, groups[1].count == 2 {
            return [6, groups[0].value, groups[1].value]
        }
        if flush { return [5] + values }
        if straightHigh > 0 { return [4, straightHigh] }
        if groups[0].count == 3 {
            return [3, groups[0].value] + groups.dropFirst().map(\.value).sorted(by: >)
        }
        if groups[0].count == 2, groups.count > 1, groups[1].count == 2 {
            return [2, max(groups[0].value, groups[1].value), min(groups[0].value, groups[1].value), groups[2].value]
        }
        if groups[0].count == 2 {
            return [1, groups[0].value] + groups.dropFirst().map(\.value).sorted(by: >)
        }
        return [0] + values
    }

    static func bestScore(_ cards: [PokerCard]) -> [Int] {
        combinations(of: cards)
            .map(scoreFive)
            .max { compare($0, $1) < 0 } ?? [0]
    }

    static func bestHand(_ cards: [PokerCard]) -> [PokerCard] {
        combinations(of: cards)
            .max { compare(scoreFive($0), scoreFive($1)) < 0 } ?? Array(cards.prefix(5))
    }

    static func compare(_ left: [Int], _ right: [Int]) -> Int {
        for index in 0..<max(left.count, right.count) {
            let lhs = index < left.count ? left[index] : 0
            let rhs = index < right.count ? right[index] : 0
            if lhs != rhs {
                return lhs - rhs
            }
        }
        return 0
    }

    private static func combinations(of cards: [PokerCard]) -> [[PokerCard]] {
        guard cards.count >= 5 else { return [] }
        var result: [[PokerCard]] = []
        for first in 0..<(cards.count - 4) {
            for second in (first + 1)..<(cards.count - 3) {
                for third in (second + 1)..<(cards.count - 2) {
                    for fourth in (third + 1)..<(cards.count - 1) {
                        for fifth in (fourth + 1)..<cards.count {
                            result.append([
                                cards[first], cards[second], cards[third], cards[fourth], cards[fifth],
                            ])
                        }
                    }
                }
            }
        }
        return result
    }
}
