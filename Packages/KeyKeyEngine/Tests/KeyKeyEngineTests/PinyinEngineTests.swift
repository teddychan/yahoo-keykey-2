import XCTest
@testable import KeyKeyEngine

final class PinyinEngineTests: XCTestCase {
    private func makeEngine() -> PinyinEngine {
        let table = PinyinSyllableTable(text: """
        ni\tㄋㄧ
        hao\tㄏㄠ
        wo\tㄨㄛ
        """)
        let index = TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄋㄧ 泥 -6.0
        ㄏㄠ 好 -3.0
        ㄋㄧ-ㄏㄠ 你好 -5.0
        ㄨㄛ 我 -3.0
        """)
        return PinyinEngine(syllableTable: table, index: index, userRank: { _ in 0 })
    }

    func testTypingComposesBestPath() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        XCTAssertEqual(e.composingText, "你好")
    }

    func testCandidatesAtCursor() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.candidates, ["你", "泥"]) // cursor on the only node
    }

    func testSelectCandidateOverridesNode() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        e.selectCandidate(1)                 // pick 泥
        XCTAssertEqual(e.composingText, "泥")
    }

    func testCursorMovementAcrossNodes() {
        let e = makeEngine()
        for c in "wo" { _ = e.handleKey(c) }
        for c in "ni" { _ = e.handleKey(c) } // two nodes: 我 | 你
        XCTAssertEqual(e.composingText, "我你")
        XCTAssertEqual(e.candidates.first, "我")   // cursor starts on first node
        XCTAssertTrue(e.moveCursorRight())
        XCTAssertEqual(e.candidates, ["你", "泥"])  // cursor now on second node
        XCTAssertFalse(e.moveCursorRight())         // already at last node
        XCTAssertTrue(e.moveCursorLeft())
        XCTAssertEqual(e.candidates.first, "我")
    }

    func testBackspaceRemovesLastLetterAndRewalks() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        e.backspace()                        // drop 'o'
        XCTAssertTrue(e.composingText.hasPrefix("你"))
    }

    func testCommitReturnsFullTextAndResets() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        XCTAssertEqual(e.commit(), "你好")
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testTailKeptVisible() {
        let e = makeEngine()
        for c in "nix" { _ = e.handleKey(c) } // 'x' can't extend/segment -> tail
        XCTAssertEqual(e.composingText, "你x")
    }

    func testCursorReadingFollowsCursorAndSpansPhrase() {
        let e = makeEngine()
        XCTAssertNil(e.cursorReading)                       // nothing composing
        for c in "wo" { _ = e.handleKey(c) }
        for c in "ni" { _ = e.handleKey(c) }                // two nodes: 我 | 你
        XCTAssertEqual(e.cursorReading, "wo")               // cursor on first node
        XCTAssertTrue(e.moveCursorRight())
        XCTAssertEqual(e.cursorReading, "ni")               // cursor on second node
        _ = e.commit()
        XCTAssertNil(e.cursorReading)                       // reset after commit
    }

    func testCursorReadingJoinsMultiSyllablePhraseNode() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }             // one node 你好 spanning ㄋㄧ-ㄏㄠ
        XCTAssertEqual(e.composingText, "你好")
        XCTAssertEqual(e.cursorReading, "ni hao")
    }

    func testMaxComposingSyllablesCap() {
        let e = makeEngine()
        for _ in 0..<50 { _ = e.handleKey("n"); _ = e.handleKey("i") }
        XCTAssertLessThanOrEqual(e.syllableCountForTesting, PinyinEngine.maxComposingSyllables)
    }
}
