import XCTest
@testable import KeyKeyEngine

final class PinyinEngineTests: XCTestCase {
    private func makeEngine(usageCount: @escaping (String, String) -> Int = { _, _ in 0 }) -> PinyinEngine {
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
        return PinyinEngine(syllableTable: table, index: index, usageCount: usageCount)
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

    func testRawLengthCappedOnInvalidInput() {
        // 'x' never extends a syllable, so pre-fix this would grow `raw` (and the
        // per-keystroke re-segment) unbounded; the guard should cap it.
        let e = makeEngine()
        for _ in 0..<500 { _ = e.handleKey("x") }
        XCTAssertLessThanOrEqual(e.rawLengthForTesting, PinyinEngine.maxRawLength)
    }

    // MARK: adaptive ordering (issue #130)

    func testOneCommitLeadsTheHigherScoringCandidateInThatNode() {
        // No committed usage leaves 你 (-3.0) ahead of 泥 (-6.0, see testCandidatesAtCursor);
        // one commit of 泥 in this node's own list flips the order.
        let e = makeEngine(usageCount: { _, c in c == "泥" ? 1 : 0 })
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.candidates, ["泥", "你"])
    }

    func testZeroCountsLeaveTheBuiltInOrderUnchanged() {
        let e = makeEngine(usageCount: { _, _ in 0 })
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.candidates, ["你", "泥"])
    }

    func testEqualCountsKeepTheBuiltInOrder() {
        let e = makeEngine(usageCount: { _, _ in 4 })
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.candidates, ["你", "泥"])
    }

    func testCountsAreScopedToTheNodesOwnReadingKey() {
        // The single-syllable ㄋㄧ node and the two-syllable ㄋㄧ-ㄏㄠ node are different lists.
        var asked: Set<String> = []
        let e = makeEngine(usageCount: { key, _ in asked.insert(key); return 0 })
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(asked, ["ㄋㄧ"])
        // A count filed under the phrase node cannot reorder the single-syllable node.
        let other = makeEngine(usageCount: { key, c in key == "ㄋㄧ-ㄏㄠ" && c == "泥" ? 9 : 0 })
        _ = other.handleKey("n"); _ = other.handleKey("i")
        XCTAssertEqual(other.candidates, ["你", "泥"])
    }

    func testCountsDoNotChangeWhichSpansTheWalkerChooses() {
        // Path selection stays a pure language-model decision: nihao still composes as the
        // ㄋㄧ-ㄏㄠ phrase node even when a single-syllable candidate has been committed often.
        let e = makeEngine(usageCount: { _, c in c == "泥" ? 500 : 0 })
        for c in "nihao" { _ = e.handleKey(c) }
        XCTAssertEqual(e.composingText, "你好")
    }

    func testPendingUsageNamesEveryNodesChosenCandidate() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.pendingUsage,
                       [CandidateUsage(list: .pinyin(readingKey: "ㄋㄧ"), candidate: "你")])
        e.selectCandidate(1)   // 泥
        XCTAssertEqual(e.pendingUsage,
                       [CandidateUsage(list: .pinyin(readingKey: "ㄋㄧ"), candidate: "泥")])
    }

    func testPendingUsageCoversEveryNodeOfAMultiNodeComposition() {
        // "wo" + "ni" walks to two single-syllable nodes; committing the buffer accepts both,
        // so both are credited — each in its own node's list.
        let e = makeEngine()
        for c in "woni" { _ = e.handleKey(c) }
        let pending = e.pendingUsage
        XCTAssertEqual(pending.count, 1, "only ㄋㄧ has more than one candidate to reorder")
        XCTAssertEqual(pending, [CandidateUsage(list: .pinyin(readingKey: "ㄋㄧ"), candidate: "你")])
    }

    func testPendingUsageSkipsSingleCandidateNodes() {
        // ㄨㄛ has one candidate (我) and ㄏㄠ one (好): nothing to reorder, nothing to count.
        let e = makeEngine()
        _ = e.handleKey("w"); _ = e.handleKey("o")
        XCTAssertEqual(e.candidates, ["我"])
        XCTAssertEqual(e.pendingUsage, [])
    }

    func testPendingUsageIsGoneAfterCommit() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertFalse(e.pendingUsage.isEmpty)
        XCTAssertEqual(e.commit(), "你")
        // The nodes are cleared by commit, so it MUST be read first.
        XCTAssertEqual(e.pendingUsage, [])
    }

    func testNonLetterIgnored() {
        let e = makeEngine()
        XCTAssertFalse(e.handleKey("1"))
        XCTAssertFalse(e.handleKey(" "))
        // Audit note: unlike CangjieEngine/SimplexEngine (whose radical maps are
        // lowercase-only), PinyinEngine's guard is `key.isLetter && key.isASCII`, which
        // does not check case, so uppercase "A" IS accepted (returns true) -- it just
        // never matches a syllable and surfaces in the tail.
        XCTAssertTrue(e.handleKey("A"))
        XCTAssertEqual(e.composingText, "A")
    }

    func testApostropheKeyAccepted() {
        XCTAssertTrue(makeEngine().handleKey("'"))
    }

    func testSelectOutOfRangeIgnored() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        e.selectCandidate(9)
        XCTAssertEqual(e.composingText, "你")
    }

    func testSelectWithNoNodeIsSafe() {
        let e = makeEngine()
        e.selectCandidate(0)                 // no composing nodes yet -- guarded no-op
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceOnEmptyIsSafe() {
        let e = makeEngine()
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testCommitEmptyReturnsEmpty() {
        let e = makeEngine()
        XCTAssertEqual(e.commit(), "")
        XCTAssertEqual(e.composingText, "")
    }
}
