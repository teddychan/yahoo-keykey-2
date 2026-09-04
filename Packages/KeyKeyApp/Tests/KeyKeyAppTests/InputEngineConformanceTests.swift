import XCTest
import KeyKeyEngine
@testable import KeyKeyApp

// Locks the App-internal InputEngine / PhraseComposingEngine contract that InputController's
// handle() relies on: which concrete engines conform, and that driving them purely through the
// protocol surface (handleKey → candidates → selectCandidate → commit, plus cursor movement)
// behaves as the controller expects.
final class InputEngineConformanceTests: XCTestCase {
    // a=日, ab=明 — enough to exercise multi-key accumulation and candidate selection.
    private func makeCangjie() -> CangjieEngine {
        CangjieEngine(table: CangjieTable(text: """
        a\t日
        a\t曰
        ab\t明
        """), tableVersion: "5")
    }

    private func makePinyin() -> PinyinEngine {
        let table = PinyinSyllableTable(text: """
        ni\tㄋㄧ
        hao\tㄏㄠ
        wo\tㄨㄛ
        """)
        let index = TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄏㄠ 好 -3.0
        ㄋㄧ-ㄏㄠ 你好 -5.0
        ㄨㄛ 我 -3.0
        """)
        return PinyinEngine(syllableTable: table, index: index)
    }

    func testConcreteEnginesConformToInputEngine() {
        XCTAssertTrue((makeCangjie() as Any) is InputEngine)
        XCTAssertTrue((SimplexEngine(table: SimplexTable(text: "a\t日\n"), tableVersion: "5") as Any) is InputEngine)
        XCTAssertTrue((makePinyin() as Any) is InputEngine)
    }

    func testOnlyPinyinIsPhraseComposing() {
        XCTAssertTrue((makePinyin() as Any) is PhraseComposingEngine)
        XCTAssertFalse((makeCangjie() as Any) is PhraseComposingEngine)
        XCTAssertFalse((SimplexEngine(table: SimplexTable(text: "a\t日\n"), tableVersion: "5") as Any) is PhraseComposingEngine)
    }

    func testDrivingCangjieThroughProtocol() {
        let engine: InputEngine = makeCangjie()
        XCTAssertTrue(engine.handleKey("a"))
        XCTAssertTrue(engine.handleKey("b"))
        XCTAssertEqual(engine.composingText, "日月")
        XCTAssertEqual(engine.candidates, ["明"])
        engine.selectCandidate(0)
        XCTAssertEqual(engine.commit(), "明")
        // commit() resets composition
        XCTAssertEqual(engine.composingText, "")
    }

    func testProtocolBackspaceAndOutOfRangeSelectAreSafe() {
        let engine: InputEngine = makeCangjie()
        _ = engine.handleKey("a")
        _ = engine.handleKey("b")
        engine.selectCandidate(999)          // out of range: no-op, no crash
        engine.backspace()                   // deletes within composition
        XCTAssertEqual(engine.composingText, "日")
    }

    // The adaptive-ordering contract InputController.commitCurrent depends on: the usage to
    // credit is readable THROUGH the protocol, and only before commit() — which is why the
    // controller reads it as its first step rather than after inserting the text (issue #130).
    func testPendingUsageIsReadableThroughTheProtocolAndOnlyBeforeCommit() {
        let engine: InputEngine = makeCangjie()
        XCTAssertTrue(engine.handleKey("a"))
        XCTAssertEqual(engine.candidates, ["日", "曰"])
        engine.selectCandidate(1)
        XCTAssertEqual(engine.pendingUsage,
                       [CandidateUsage(list: .cangjie(tableVersion: "5", code: "a"), candidate: "曰")])
        XCTAssertEqual(engine.commit(), "曰")
        XCTAssertEqual(engine.pendingUsage, [], "the list identity is gone once commit() resets")
    }

    func testEveryConcreteEngineAnswersPendingUsageThroughTheProtocol() {
        // Whichever engine handle() is driving, the one commit call site can ask.
        let engines: [InputEngine] = [
            makeCangjie(),
            SimplexEngine(table: SimplexTable(text: "a\t日\na\t曰\n"), tableVersion: "5"),
            makePinyin(),
        ]
        for engine in engines {
            _ = engine.handleKey("a")
            _ = engine.pendingUsage   // must not trap for any engine, composing or not
            _ = engine.commit()
            XCTAssertEqual(engine.pendingUsage, [])
        }
    }

    func testPinyinCreditsNothingToThePerListStore() {
        // 拼音 candidate ranking is out of scope for the per-list change: it keeps ranking off
        // the per-character store, so it must report no per-list usage at any point — before a
        // commit, mid-composition, or after. Anything else would start counting it silently.
        let engine: InputEngine = makePinyin()
        XCTAssertEqual(engine.pendingUsage, [])
        for c in "nihao" { _ = engine.handleKey(c) }
        XCTAssertEqual(engine.composingText, "你好")
        XCTAssertFalse(engine.candidates.isEmpty)
        XCTAssertEqual(engine.pendingUsage, [], "拼音 must not report per-list usage")
        _ = engine.commit()
        XCTAssertEqual(engine.pendingUsage, [])
    }

    func testDrivingPinyinThroughPhraseComposingProtocol() {
        let engine: PhraseComposingEngine = makePinyin()
        // "woni" segments into two single-char nodes (我 你); there is no 我你 phrase to merge them.
        for c in "woni" { _ = engine.handleKey(c) }
        XCTAssertEqual(engine.composingText, "我你")
        // Cursor starts on the first node; left is a no-op, right advances to the second node.
        XCTAssertEqual(engine.cursorReading, "wo")
        XCTAssertFalse(engine.moveCursorLeft())      // already at first node
        XCTAssertTrue(engine.moveCursorRight())
        XCTAssertEqual(engine.cursorReading, "ni")
        XCTAssertFalse(engine.moveCursorRight())     // already at last node
        XCTAssertEqual(engine.commit(), "我你")
    }
}
