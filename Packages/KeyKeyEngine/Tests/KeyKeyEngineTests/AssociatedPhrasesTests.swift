import XCTest
@testable import KeyKeyEngine

final class AssociatedPhrasesTests: XCTestCase {
    static let fixture = """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -3.00000000
    ㄐㄧㄣ-ㄖˋ 今日 -4.00000000
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.20000000
    ㄐㄧㄣ-ㄨㄢˇ 今晚 -5.00000000
    ㄇㄠ 貓 -4.10000000

    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.20000000
    """

    func testAssociationsBestFirst() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今"), ["今天", "今日", "今晚"])
    }

    func testSingleCharEntriesExcluded() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertFalse(ap.associations(for: "今").contains("今"))
    }

    func testUnknownCharReturnsEmpty() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "貓"), [])
    }

    func testDeDup() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今").filter { $0 == "今天" }.count, 1)
    }

    func testCommentAndBlankLinesIgnored() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "#"), [])
    }

    // MARK: user-learning bonus (issue #85)

    func testDefaultZeroBonusPreservesTheStaticOrder() {
        // The off path: no userRank argument must mean exactly what the LM scores said. Same
        // expectation as testAssociationsBestFirst, asserted here as the contract it now is.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", userRank: { _ in 0 }), ["今天", "今日", "今晚"])
    }

    func testBonusOnTheContinuationLiftsThatPhrase() {
        // 晚 is last on LM score (-5.0 against -3.2). A bonus on it — the CONTINUATION character,
        // the one the user picks — carries 今晚 to the front.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", userRank: { $0 == "晚" ? 100 : 0 }),
                       ["今晚", "今天", "今日"])
    }

    func testBonusOnTheIndexCharacterChangesNothing() {
        // 今 is the bucket's key, shared by every phrase in it, so its bonus is a constant that
        // must not reorder anything. This is why the continuation is what the sort reads.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", userRank: { $0 == "今" ? 100 : 0 }),
                       ["今天", "今日", "今晚"])
    }

    func testEqualScoresResolveBySourceOrder() {
        // `sorted(by:)` is not stable, so equal scores need the explicit tie-break to be
        // reproducible — 甲乙 was read first and must stay ahead of 甲丙.
        let text = """
        ㄐㄧㄚˇ-ㄧˇ 甲乙 -4.00000000
        ㄐㄧㄚˇ-ㄅㄧㄥˇ 甲丙 -4.00000000
        """
        let ap = AssociatedPhrases(text: text)
        XCTAssertEqual(ap.associations(for: "甲"), ["甲乙", "甲丙"])
        // And a bonus still breaks that tie the other way, rather than the order being frozen.
        XCTAssertEqual(ap.associations(for: "甲", userRank: { $0 == "丙" ? 1 : 0 }),
                       ["甲丙", "甲乙"])
    }
}
