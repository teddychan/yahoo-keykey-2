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

    // MARK: adaptive ordering (issues #85, #130)

    func testZeroCountsPreserveTheStaticOrder() {
        // The off path — and the fresh-store path: zero everywhere must mean exactly what the LM
        // scores said. Same expectation as testAssociationsBestFirst, asserted here as a contract.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", usageCount: { _ in 0 }), ["今天", "今日", "今晚"])
    }

    func testACommittedPhraseLeadsTheList() {
        // 今晚 is last on LM score (-5.0 against -3.2). One commit of it leads the list, because
        // the count decides before the score is consulted at all.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", usageCount: { $0 == "今晚" ? 1 : 0 }),
                       ["今晚", "今天", "今日"])
    }

    func testCountsAreReadForTheWholePhraseNotTheContinuation() {
        // The list offers whole phrases, so the count is asked for 今晚 — not for the
        // continuation 晚 that a 聯想只顯示接續字 display would show, and not for the bucket key 今.
        let ap = AssociatedPhrases(text: Self.fixture)
        var asked: Set<String> = []
        _ = ap.associations(for: "今") { asked.insert($0); return 0 }
        XCTAssertEqual(asked, ["今天", "今日", "今晚"])
        // A count filed under the continuation alone therefore moves nothing.
        XCTAssertEqual(ap.associations(for: "今", usageCount: { $0 == "晚" ? 5 : 0 }),
                       ["今天", "今日", "今晚"])
    }

    func testEqualCountsChangeNothing() {
        // Every phrase committed the same number of times: the LM order stands.
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今", usageCount: { _ in 1 }),
                       ["今天", "今日", "今晚"])
    }

    func testHigherCountLeadsLowerCount() {
        // The issue's own example, with the trigger's list as the unit: 關係 8, 關心 3.
        let text = """
        ㄍㄨㄢ-ㄒㄧˋ 關係 -3.00000000
        ㄍㄨㄢ-ㄒㄧㄣ 關心 -2.00000000
        """
        let ap = AssociatedPhrases(text: text)
        XCTAssertEqual(ap.associations(for: "關"), ["關心", "關係"])   // LM baseline
        let counts = ["關係": 8, "關心": 3]
        XCTAssertEqual(ap.associations(for: "關", usageCount: { counts[$0] ?? 0 }),
                       ["關係", "關心"])
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
        // And a count still breaks that tie the other way, rather than the order being frozen.
        XCTAssertEqual(ap.associations(for: "甲", usageCount: { $0 == "甲丙" ? 1 : 0 }),
                       ["甲丙", "甲乙"])
    }
}
