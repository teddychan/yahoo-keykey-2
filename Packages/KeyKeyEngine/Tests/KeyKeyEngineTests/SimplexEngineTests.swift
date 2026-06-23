import XCTest
@testable import KeyKeyEngine

final class SimplexEngineTests: XCTestCase {
    // Same fixture as SimplexTableTests; simplex code = first+last letter.
    //   "ab"   -> "ab"   明
    //   "amb"  -> "ab"   昌
    //   "abc"  -> "ac"   冒
    //   "a"    -> "a"    日
    static let table = SimplexTable(cangjie: CangjieTable(text: """
    a\t日
    ab\t明
    amb\t昌
    abc\t冒
    abcde\t韻
    """))

    private func make() -> SimplexEngine { SimplexEngine(table: Self.table) }

    func testAccumulatesRadicalGlyphs() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // 日
        XCTAssertTrue(e.handleKey("b"))   // 月
        XCTAssertEqual(e.composingText, "日月")
    }

    func testIsComposingSyllableAlwaysFalse() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertFalse(e.isComposingSyllable)
    }

    func testCandidatesFromSimplexCode() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        // simplex "ab" -> 明, 昌 (larger list than full Cangjie)
        XCTAssertEqual(e.candidates, ["明", "昌"])
    }

    func testCandidatesForDifferentCode() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("c")
        XCTAssertEqual(e.candidates, ["冒"])
    }

    func testNoCandidatesWhenEmpty() {
        XCTAssertEqual(make().candidates, [])
    }

    func testSelectCandidateShowsItAsComposing() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "昌")
    }

    func testSelectOutOfRangeIgnored() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(9)
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCommitWithSelectionReturnsItAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(1)
        XCTAssertEqual(e.commit(), "昌")
        XCTAssertEqual(e.composingText, "")
        XCTAssertEqual(e.candidates, [])
    }

    func testCommitWithoutSelectionUsesFirstCandidate() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.commit(), "明")
        XCTAssertEqual(e.composingText, "")
    }

    func testCommitWithNoMatchEmitsNothing() {
        let e = make()
        _ = e.handleKey("z"); _ = e.handleKey("z")
        XCTAssertEqual(e.commit(), "")
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceRemovesLastRadical() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.backspace()
        XCTAssertEqual(e.composingText, "日")
        XCTAssertEqual(e.candidates, ["日"])   // simplex "a" -> 日
    }

    func testBackspaceClearsSelection() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(1)
        e.backspace()
        XCTAssertEqual(e.composingText, "日")
    }

    func testBackspaceOnEmptyIsSafe() {
        let e = make()
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testCandidatesRerankedByCharacterRank() {
        // simplex "ab" -> ["明","昌"]; rank 昌 highest so it leads.
        let rank: [Character: Double] = ["昌": 1.0]
        let e = SimplexEngine(table: Self.table, characterRank: rank)
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["昌", "明"])
    }

    func testEmptyRankLeavesOrderUnchanged() {
        let e = SimplexEngine(table: Self.table, characterRank: [:])
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明", "昌"])
    }

    func testUserRankPromotesLearnedChar() {
        // No dict rank; userRank boosts the second char (昌) so it leads.
        let e = SimplexEngine(table: Self.table, userRank: { $0 == "昌" ? 100 : 0 })
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["昌", "明"])
    }

    func testZeroUserRankLeavesOrderUnchanged() {
        let e = SimplexEngine(table: Self.table, userRank: { _ in 0 })
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明", "昌"])
    }

    func testNonLetterIgnored() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertFalse(e.handleKey("1"))
        XCTAssertFalse(e.handleKey(" "))
        XCTAssertFalse(e.handleKey("A"))
        XCTAssertEqual(e.composingText, "日")
    }
}
