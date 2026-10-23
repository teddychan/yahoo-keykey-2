import XCTest
@testable import KeyKeyEngine

// 智慧注音: whole sentences of 注音, walked by the language model.
final class SmartZhuyinEngineTests: XCTestCase {
    // 你好 is a phrase of its own; 是 and 事 share ㄕˋ so a tone-aware walk has a real choice.
    private let lm = """
    ㄋㄧˇ 你 -3.0
    ㄋㄧˇ 妳 -5.0
    ㄏㄠˇ 好 -3.0
    ㄋㄧˇ-ㄏㄠˇ 你好 -2.0
    ㄕˋ 是 -2.5
    ㄕˋ 事 -3.5
    ㄨㄛˇ 我 -2.0
    ㄨㄛˇ-ㄕˋ 我是 -2.0
    """

    private func engine(layout: ZhuyinKeyboardLayout = .hsu) -> SmartZhuyinEngine {
        SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: layout)
    }

    private func type(_ keys: String, into e: SmartZhuyinEngine) {
        for key in keys { _ = e.handleKey(key) }
    }

    func testASentenceIsChosenWithoutPickingAnyCharacter() {
        let e = engine()
        type("nefhwf", into: e)                    // ㄋㄧˇ ㄏㄠˇ on 許氏
        XCTAssertEqual(e.composingText, "你好")
    }

    func testAToneEndsEachSyllableSoTheSentenceGrows() {
        let e = engine()
        type("nef", into: e)
        XCTAssertEqual(e.composingText, "你")
        type("hw", into: e)                        // ㄏㄠ still unfinished: shown as 注音
        XCTAssertEqual(e.composingText, "你ㄏㄠ")
        type("f", into: e)
        XCTAssertEqual(e.composingText, "你好")
    }

    func testSpaceIsTheFirstToneAndFinishesASyllable() {
        let lm = "ㄇ 媽 -3.0\nㄇㄚ 媽 -3.0"
        let e = SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: .hsu)
        type("mm", into: e)                        // ㄇ then… a lone second m is ㄢ: ㄇㄢ
        XCTAssertTrue(e.applyFirstTone())
        XCTAssertFalse(e.applyFirstTone(), "nothing left to finish")
    }

    func testTonesDecideBetweenReadings() {
        let e = engine()
        type("cj", into: e)                        // ㄕˋ
        XCTAssertEqual(e.candidates, ["是", "事"])
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "事")
    }

    func testPhraseBeatsItsCharacters() {
        let e = engine()
        type("xhfcj", into: e)                     // ㄨㄛˇ ㄕˋ
        XCTAssertEqual(e.composingText, "我是")
        XCTAssertEqual(e.cursorReading, "ㄕˋ", "the cursor is on a syllable, not a word")
        XCTAssertTrue(e.candidates.contains("我是"), "the word is still on offer from either syllable")
    }

    func testBackspaceReopensTheLastToneThenTheSyllable() {
        let e = engine()
        type("nefhwf", into: e)
        e.backspace()                              // takes the tone back off ㄏㄠˇ
        XCTAssertEqual(e.composingText, "你ㄏㄠ")
        e.backspace()                              // ㄏㄠ → the key `h` alone, which 許氏 reads as ㄛ
        XCTAssertEqual(e.composingText, "你ㄛ")
        e.backspace()
        XCTAssertEqual(e.composingText, "你")
    }

    func testCommitReturnsTheSentenceAndClears() {
        let e = engine()
        type("nefhwf", into: e)
        XCTAssertEqual(e.commit(), "你好")
        XCTAssertEqual(e.composingText, "")
    }

    func testAKeyOutsideTheLayoutIsNotConsumed() {
        let e = engine()
        XCTAssertFalse(e.handleKey("q"))
        XCTAssertFalse(e.handleKey("1"))
    }

    func testAnUnknownReadingStaysVisibleAsZhuyin() {
        let e = engine()
        type("bj", into: e)                        // ㄅˋ — not in this model
        XCTAssertEqual(e.composingText, "ㄅˋ")
    }

    func testDachenWorksToo() {
        let e = engine(layout: .dachen)
        type("su3cl3", into: e)                    // ㄋㄧˇ ㄏㄠˇ → s u 3 / c l 3
        XCTAssertEqual(e.composingText, "你好")
    }

    func testTheCursorCharacterIsMarkedOnlyOnceTheUserMovesBackOntoIt() {
        let e = engine()
        type("xhfcj", into: e)                     // 我是 — one two-syllable word
        XCTAssertEqual(e.segments, [ComposingSegment(text: "我是", isCursor: false)],
                       "typing at the end marks nothing")
        XCTAssertTrue(e.moveCursorLeft())
        XCTAssertEqual(e.segments, [ComposingSegment(text: "我", isCursor: true),
                                    ComposingSegment(text: "是", isCursor: false)],
                       "inside a word, only the character under the cursor is marked")
        type("cj", into: e)                        // typing goes on at the end again
        XCTAssertTrue(e.segments.allSatisfy { !$0.isCursor })
    }

    // The reported case: the model joins 太長 into one word, but 長 must still be correctable to 常.
    func testACharacterInsideAWordCanBeChangedOnItsOwn() {
        let lm = """
        ㄊㄞˋ 太 -2.0
        ㄔㄤˊ 長 -2.8
        ㄔㄤˊ 常 -3.0
        ㄊㄞˋ-ㄔㄤˊ 太長 -3.5
        """
        let e = SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: .hsu)
        // ㄊㄞˋ ㄔㄤˊ on 許氏: t i j / v k d
        type("tij", into: e); type("vkd", into: e)
        XCTAssertEqual(e.composingText, "太長")
        XCTAssertTrue(e.moveCursorLeft())
        XCTAssertTrue(e.moveCursorRight())         // back onto 長
        XCTAssertEqual(e.segments.first(where: \.isCursor)?.text, "長")
        let choices = e.candidates
        let index = try! XCTUnwrap(choices.firstIndex(of: "常"))
        e.selectCandidate(index)
        XCTAssertEqual(e.composingText, "太常")
    }

    func testAPinnedCharacterIsRememberedAndLeadsNextTime() {
        var counts: [String: Int] = [:]
        let lm = "ㄕˋ 是 -2.0\nㄕˋ 氏 -4.0"
        func make() -> SmartZhuyinEngine {
            SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: .hsu,
                              usageCount: { _, candidate in counts[candidate, default: 0] })
        }
        let first = make()
        type("cj", into: first)
        XCTAssertEqual(first.composingText, "是")
        first.selectCandidate(first.candidates.firstIndex(of: "氏")!)
        for usage in first.pendingUsage { counts[usage.candidate, default: 0] += 1 }
        XCTAssertEqual(first.pendingUsage.map(\.candidate), ["氏"])
        let second = make()
        type("cj", into: second)
        XCTAssertEqual(second.composingText, "氏", "what the user picked now leads")
    }

    func testAcceptingTheDefaultCountsAsMuchAsPickingIt() {
        var counts: [String: Int] = [:]
        let lm = "ㄕˋ 是 -2.0\nㄕˋ 氏 -4.0"
        func make() -> SmartZhuyinEngine {
            SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: .hsu,
                              usageCount: { _, candidate in counts[candidate, default: 0] })
        }
        func commitCrediting(_ e: SmartZhuyinEngine) {
            for usage in e.pendingUsage { counts[usage.candidate, default: 0] += 1 }
            e.commit()
        }
        for _ in 0..<3 {                                                   // 是, accepted as the default
            let e = make()
            type("cj", into: e)
            commitCrediting(e)
        }
        let picked = make()
        type("cj", into: picked)
        picked.selectCandidate(picked.candidates.firstIndex(of: "氏")!)   // 氏, once, by hand
        commitCrediting(picked)
        XCTAssertEqual(counts["是"], 3)
        XCTAssertEqual(counts["氏"], 1)
        let next = make()
        type("cj", into: next)
        XCTAssertEqual(next.composingText, "是", "three accepted 是 outweigh one picked 氏")
    }

    func testAReadingWithOneChoiceCreditsNothing() {
        let e = engine()
        type("nefhwf", into: e)                    // 你好: a single word, nothing to reorder
        XCTAssertTrue(e.pendingUsage.isEmpty)
    }

    func testOnlyTheCharacterJustFinishedGoesBackIntoZhuyin() {
        let e = engine()
        type("nefhwf", into: e)                    // 你好
        e.backspace()                              // 好 back to its 注音, tone off
        XCTAssertEqual(e.composingText, "你ㄏㄠ")
        e.backspace()                              // peel its symbols (許氏 reads a lone `h` as ㄛ)
        e.backspace()
        XCTAssertEqual(e.composingText, "你")
        e.backspace()                              // 你 is deleted whole, not reopened as ㄋㄧ
        XCTAssertEqual(e.composingText, "")
    }

    func testEarlierCharactersAreDeletedOneKeyEach() {
        let lm = "ㄋㄧˇ 你 -3.0\nㄏㄠˇ 好 -3.0\nㄨㄛˇ 我 -2.0"
        let e = SmartZhuyinEngine(index: TonelessLanguageModelIndex(text: lm, keepTones: true), layout: .hsu)
        type("xhfnefhwf", into: e)                 // 我你好
        XCTAssertEqual(e.composingText, "我你好")
        type("n", into: e)                         // start another syllable, so 好 is no longer fresh
        e.backspace()
        XCTAssertEqual(e.composingText, "我你好", "only the unfinished syllable went")
        e.backspace()
        XCTAssertEqual(e.composingText, "我你", "好 is deleted whole")
        e.backspace()
        XCTAssertEqual(e.composingText, "我")
    }
}
