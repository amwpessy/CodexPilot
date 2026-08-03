import XCTest
@testable import MacStatusCodexMonitor

final class PokerModelsTests: XCTestCase {
    func testWheelStraightFlushScoresAceAsLow() {
        let cards = [
            card(.spade, "A", 14),
            card(.spade, "2", 2),
            card(.spade, "3", 3),
            card(.spade, "4", 4),
            card(.spade, "5", 5),
        ]

        XCTAssertEqual(PokerHandEvaluator.scoreFive(cards), [8, 5])
    }

    func testBestOfSevenSelectsFullHouse() {
        let cards = [
            card(.spade, "K", 13),
            card(.heart, "K", 13),
            card(.diamond, "K", 13),
            card(.club, "9", 9),
            card(.spade, "9", 9),
            card(.heart, "2", 2),
            card(.club, "A", 14),
        ]

        XCTAssertEqual(PokerHandEvaluator.bestScore(cards), [6, 13, 9])
        XCTAssertEqual(PokerHandEvaluator.bestHand(cards).count, 5)
    }

    func testFullHouseBeatsFlush() {
        XCTAssertGreaterThan(
            PokerHandEvaluator.compare([6, 10, 4], [5, 14, 11, 8, 6, 2]),
            0
        )
    }

    func testPokerSoundEffectsProduceValidWaveData() {
        for effect in PokerSoundEffect.allCases {
            let data = PokerSoundPlayer.waveData(for: effect)

            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: data.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
            XCTAssertGreaterThan(data.count, 44)
        }
    }

    @MainActor
    func testGameCannotStartWithZeroAccountPoints() async {
        let game = PokerGame()
        game.startHand(bankroll: 0, accountID: "account-zero")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(game.handNo, 0)
        XCTAssertTrue(game.finished)
        XCTAssertEqual(game.you.chips, 0)
    }

    @MainActor
    func testPendingSettlementSurvivesGameRecreation() {
        let suiteName = "PokerSettlementJournalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let journal = PokerSettlementJournal(defaults: defaults)
        let settlement = PendingPokerSettlement(
            id: "hand-pending-123",
            requestedDelta: -240,
            tableBalance: 760
        )

        journal.save(settlement, for: "account-1")
        let restoredGame = PokerGame(settlementJournal: journal)
        restoredGame.restorePendingSettlement(for: "account-1")

        XCTAssertEqual(restoredGame.pendingSettlement, settlement)
        journal.clear(accountID: "account-1", handID: settlement.id)
        XCTAssertNil(journal.pending(for: "account-1"))
    }

    private func card(_ suit: PokerSuit, _ rank: String, _ value: Int) -> PokerCard {
        PokerCard(suit: suit, rank: rank, value: value)
    }
}
