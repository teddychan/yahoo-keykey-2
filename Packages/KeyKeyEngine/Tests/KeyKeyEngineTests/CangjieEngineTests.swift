import XCTest
@testable import KeyKeyEngine

final class CangjieEngineTests: XCTestCase {
    // a=日, b=月, c=金, ... ; codes -> chars from the real Cangjie scheme.
    static let table = CangjieTable(text: """
    a\t日
    a\t曰
    ab\t明
    abc\t冒
    abcde\t韻
    abcdef\t漏
    """)

    private func make() -> CangjieEngine { CangjieEngine(table: Self.table) }

    func testAccumulatesRadicalGlyphs() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // 日
        XCTAssertTrue(e.handleKey("b"))   // 月
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCandidatesForCurrentCode() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertEqual(e.candidates, ["日", "曰"])
        _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])
    }

    func testNoCandidatesWhenEmpty() {
        XCTAssertEqual(make().candidates, [])
    }

    func testSelectCandidateShowsItAsComposing() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "曰")
    }

    func testSelectOutOfRangeIgnored() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(5)
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(0)
        XCTAssertEqual(e.commit(), "明")
        XCTAssertEqual(e.composingText, "")
        XCTAssertEqual(e.candidates, [])
    }

    func testCommitWithoutSelectionUsesFirstCandidate() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.commit(), "明")   // first candidate for "ab", not the radicals
        XCTAssertEqual(e.composingText, "")
    }

    func testCommitWithNoMatchEmitsNothing() {
        let e = make()
        _ = e.handleKey("c")   // no code "c" in the fixture
        XCTAssertEqual(e.commit(), "")
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceRemovesLastRadical() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.backspace()
        XCTAssertEqual(e.composingText, "日")
        XCTAssertEqual(e.candidates, ["日", "曰"])
    }

    func testBackspaceClearsSelection() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceOnEmptyIsSafe() {
        let e = make()
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testMaxFiveRadicalsCap() {
        let e = make()
        for k in "abcdef" { XCTAssertTrue(e.handleKey(k)) } // 6th still consumed, not stored
        XCTAssertEqual(e.composingText, "日月金木水")        // only 5 glyphs
        XCTAssertEqual(e.candidates, ["韻"])                 // code is "abcde"
    }

    func testNonLetterIgnored() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertFalse(e.handleKey("1"))
        XCTAssertFalse(e.handleKey(" "))
        XCTAssertFalse(e.handleKey("A"))   // uppercase is not a radical key
        XCTAssertEqual(e.composingText, "日")
    }

    func testWildcardIsConsumedAndShownLiterally() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertTrue(e.handleKey("*"))
        XCTAssertEqual(e.composingText, "日*")   // * rendered literally
    }

    func testWildcardCandidatesMatchPattern() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("*")
        // "a*" matches "ab","abc","abcde","abcdef" (≥1 letter after a)
        XCTAssertEqual(e.candidates, ["明", "冒", "韻", "漏"])
    }

    func testWildcardBetweenLiterals() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("*"); _ = e.handleKey("b")
        // "a*b" matches codes starting a, ending b, ≥1 between: "ab" is too short? ab=a,b no middle
        XCTAssertEqual(e.candidates, [])
    }

    func testWildcardCountsTowardMaxLength() {
        let e = make()
        for _ in 0..<6 { _ = e.handleKey("*") }
        XCTAssertEqual(e.composingText, "*****")   // capped at 5
    }

    func testWildcardCandidatesRerankedByCharacterRank() {
        // Rank a normally-late char (漏) highest so it leads the "a*" list.
        let rank: [Character: Double] = ["漏": 0.0, "韻": -1.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank)
        _ = e.handleKey("a"); _ = e.handleKey("*")
        // Default table order is ["明","冒","韻","漏"]; ranked chars move ahead
        // (漏 > 韻), unranked ("明","冒") keep their relative order after.
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testEmptyRankLeavesOrderUnchanged() {
        let e = CangjieEngine(table: Self.table, characterRank: [:])
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["明", "冒", "韻", "漏"])
    }

    func testUserRankPromotesLearnedChar() {
        // No dict rank; a userRank closure boosts an otherwise-last char (漏) to the top.
        let e = CangjieEngine(table: Self.table, userRank: { $0 == "漏" ? 100 : 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "明", "冒", "韻"])
    }

    func testZeroUserRankLeavesOrderUnchanged() {
        // Default (zero) userRank must not perturb dict-only ordering: existing behaviour.
        let rank: [Character: Double] = ["漏": 0.0, "韻": -1.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank, userRank: { _ in 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testUserRankAddsToCharacterRank() {
        // userRank is added on top of the dict rank, lifting a learned char above a
        // higher-dict-ranked one.
        let rank: [Character: Double] = ["韻": 1.0, "漏": 0.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank, userRank: { $0 == "漏" ? 5 : 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        // 漏: 0+5=5 leads; 韻: 1+0=1; then unranked 明,冒 keep order.
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testRadicalMapCoversFullAlphabet() {
        for k in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertNotNil(CangjieEngine.radicals[k], "missing radical for \(k)")
        }
        XCTAssertEqual(CangjieEngine.radicals.count, 26)
    }
}
