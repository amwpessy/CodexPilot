import XCTest
@testable import MacStatusCodexMonitor

final class ShuihuCardsTests: XCTestCase {
    func testCatalogContainsEveryUniqueRankAndHero() {
        let cards = ShuihuCardCatalog.all

        XCTAssertEqual(cards.count, 108)
        XCTAssertEqual(cards.map(\.rank), Array(1...108))
        XCTAssertEqual(Set(cards.map(\.name)).count, 108)
        XCTAssertEqual(cards.filter(\.isHeavenlySpirit).count, 36)
        XCTAssertEqual(cards.filter { !$0.isHeavenlySpirit }.count, 72)
    }

    func testEveryEditorialAttributeStaysInThePublishedScale() {
        for card in ShuihuCardCatalog.all {
            for value in [card.command, card.might, card.wisdom, card.charisma] {
                XCTAssertTrue((1...100).contains(value), "\(card.name) has an invalid rating")
            }
            XCTAssertFalse(card.weapon.isEmpty)
            XCTAssertFalse(card.signature.isEmpty)
            XCTAssertFalse(card.role.isEmpty)
        }
    }

    func testSignatureCharactersReflectTheirNovelStrengths() throws {
        let songJiang = try XCTUnwrap(ShuihuCardCatalog.definition(id: 1))
        let wuYong = try XCTUnwrap(ShuihuCardCatalog.definition(id: 3))
        let wuSong = try XCTUnwrap(ShuihuCardCatalog.definition(id: 14))
        let shiQian = try XCTUnwrap(ShuihuCardCatalog.definition(id: 107))

        XCTAssertGreaterThanOrEqual(songJiang.charisma, 95)
        XCTAssertEqual(wuYong.wisdom, 100)
        XCTAssertEqual(wuSong.might, 100)
        XCTAssertGreaterThanOrEqual(shiQian.wisdom, 90)
    }

    func testDrawReceiptProducesACompleteCollectionStatus() {
        let receipt = ShuihuDrawReceipt(
            cardId: 14,
            isNew: true,
            copies: 1,
            cost: 1_000,
            pointsBalance: 4_000,
            drawsUsed: 2,
            dailyLimit: 10,
            drawsRemaining: 8,
            dayKey: "2026-07-24",
            resetsAt: Date(timeIntervalSince1970: 100),
            uniqueCount: 1,
            totalCopies: 1,
            rewardGranted: false,
            rewardAmount: 0,
            rewardClaimed: false,
            collection: [ShuihuCollectionEntry(cardId: 14, copies: 1)]
        )

        XCTAssertEqual(receipt.status.copies(of: 14), 1)
        XCTAssertEqual(receipt.status.drawsRemaining, 8)
        XCTAssertEqual(receipt.status.pointsBalance, 4_000)
    }
}
