import XCTest
@testable import KeyKeyEngine

// 注音 (ㄅ半) typing, end to end through the engine: keys in, one character out.
final class ZhuyinEngineTests: XCTestCase {
    // ㄕˋ is 是/事/世, ㄋㄧˇ is 你/妳, ㄕ is 詩 — enough for tones, selection and paging.
    private let tableText = """
    ㄕˋ\t是
    ㄕˋ\t事
    ㄕˋ\t世
    ㄕ\t詩
    ㄋㄧˇ\t你
    ㄋㄧˇ\t妳
    ㄏㄠˇ\t好
    """

    private func engine(layout: ZhuyinKeyboardLayout = .dachen,
                        usageCount: @escaping (CandidateListKey, String) -> Int = { _, _ in 0 })
    -> ZhuyinEngine {
        ZhuyinEngine(table: ZhuyinTable(text: tableText), layout: layout, usageCount: usageCount)
    }

    private func type(_ keys: String, into engine: ZhuyinEngine) {
        for key in keys { _ = engine.handleKey(key) }
    }

    // MARK: Composing

    func testTypingASyllableShowsItAsZhuyin() {
        let e = engine()
        type("su", into: e)                     // ㄋ + ㄧ on 大千
        XCTAssertEqual(e.composingText, "ㄋㄧ")
    }

    func testCandidatesAppearOnlyOnceAToneFinishesTheSyllable() {
        let e = engine()
        type("su", into: e)
        XCTAssertEqual(e.candidates, [], "ㄋㄧ is unfinished: no tone, no candidate list")
        XCTAssertNil(e.candidateListKey)
        type("3", into: e)                      // ˇ
        XCTAssertEqual(e.composingText, "ㄋㄧˇ")
        XCTAssertEqual(e.candidates, ["你", "妳"])
        XCTAssertEqual(e.candidateListKey, .zhuyin(reading: "ㄋㄧˇ"))
    }

    func testSpaceAppliesTheFirstTone() {
        let e = engine()
        type("g", into: e)                      // ㄕ
        XCTAssertEqual(e.candidates, [])
        XCTAssertTrue(e.applyFirstTone())
        XCTAssertEqual(e.composingText, "ㄕ", "the first tone is unmarked")
        XCTAssertEqual(e.candidates, ["詩"])
    }

    func testFirstToneIsRefusedWhenThereIsNothingToToneOrItIsAlreadyDone() {
        let e = engine()
        XCTAssertFalse(e.applyFirstTone(), "nothing composing: Space stays a literal space")
        type("g4", into: e)                     // ㄕˋ
        XCTAssertFalse(e.applyFirstTone(), "already finished: Space pages or commits instead")
        XCTAssertEqual(e.composingText, "ㄕˋ")
    }

    func testAKeyThisLayoutDoesNotTypeIsNotConsumed() {
        let e = engine()
        XCTAssertFalse(e.handleKey("["), "punctuation must fall through to the app")
        XCTAssertFalse(e.handleKey("A"))
        XCTAssertTrue(e.composingText.isEmpty)
    }

    func testAStrayToneKeyIsNotConsumed() {
        // With nothing composing, `3` on 大千 must reach the app as a digit.
        let e = engine()
        XCTAssertFalse(e.handleKey("3"))
    }

    func testBackspaceRemovesOnePartAtATime() {
        let e = engine()
        type("su3", into: e)
        e.backspace()
        XCTAssertEqual(e.composingText, "ㄋㄧ")
        XCTAssertEqual(e.candidates, [], "the tone is gone, so the candidate list is too")
        e.backspace()
        XCTAssertEqual(e.composingText, "ㄋ")
    }

    func testMapsKeyReportsWhatTheLayoutClaims() {
        let e = engine()
        XCTAssertTrue(e.mapsKey(","), "ㄝ on 大千 — the controller must not make it ，")
        XCTAssertTrue(e.mapsKey("3"))
        XCTAssertFalse(e.mapsKey("["))
        XCTAssertFalse(e.mapsKey("<"))
    }

    // MARK: Committing

    func testSelectingAndCommittingACandidate() {
        let e = engine()
        type("g4", into: e)                      // ㄕˋ
        XCTAssertEqual(e.candidates, ["是", "事", "世"])
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "事", "the picked character replaces the 注音 display")
        XCTAssertEqual(e.commit(), "事")
        XCTAssertEqual(e.composingText, "", "commit resets the syllable")
        XCTAssertEqual(e.candidates, [])
    }

    func testCommitWithoutSelectingTakesTheFirstCandidate() {
        let e = engine()
        type("g4", into: e)
        XCTAssertEqual(e.commit(), "是")
    }

    func testCommittingAnUnknownReadingYieldsNothingRatherThanGarbage() {
        let e = engine()
        type("1j/3", into: e)                    // ㄅㄨㄥˇ — no such character
        XCTAssertEqual(e.candidates, [])
        XCTAssertEqual(e.commit(), "")
        XCTAssertEqual(e.composingText, "")
    }

    func testOutOfRangeSelectionIsANoOp() {
        let e = engine()
        type("g4", into: e)
        e.selectCandidate(99)
        e.selectCandidate(-1)
        XCTAssertEqual(e.commit(), "是")
    }

    // MARK: Running on to the next character

    func testAZhuyinKeyAgainstAFinishedSyllableStartsTheNextCharacter() {
        let e = engine()
        type("g4", into: e)                      // ㄕˋ, finished
        XCTAssertTrue(e.keyStartsNewComposition("s"), "ㄋ belongs to the next character")
        XCTAssertFalse(e.keyStartsNewComposition("["), "not a 注音 key at all")
    }

    func testAToneKeyAgainstAFinishedSyllableCorrectsItInstead() {
        let e = engine()
        type("g4", into: e)                      // ㄕˋ
        XCTAssertFalse(e.keyStartsNewComposition("3"),
                       "a tone key re-tones the syllable rather than starting the next one")
        type("3", into: e)
        XCTAssertEqual(e.composingText, "ㄕˇ")
    }

    func testAnUnfinishedSyllableNeverStartsANewComposition() {
        let e = engine()
        type("g", into: e)                       // ㄕ, no tone yet
        XCTAssertFalse(e.keyStartsNewComposition("s"),
                       "ㄋ here is a correction to the initial, not a new character")
    }

    // MARK: Layouts

    func testTheSameCharacterIsTypableOnEitherKeyboard() {
        let dachen = engine(layout: .dachen)
        type("su3", into: dachen)
        XCTAssertEqual(dachen.commit(), "你")

        let eten = engine(layout: .eten)
        type("ne3", into: eten)                  // ㄋ + ㄧ + ˇ on 倚天
        XCTAssertEqual(eten.composingText, "ㄋㄧˇ")
        XCTAssertEqual(eten.commit(), "你")
    }

    // MARK: Adaptive ordering

    func testACommittedCandidateLeadsItsOwnReadingNextTime() {
        // The count closure is consulted on every sort — the controller's reads the shared store
        // live — so a candidate committed a moment ago leads without rebuilding the engine.
        var counts: [String: Int] = [:]
        let e = engine { list, candidate in
            guard case .zhuyin(let reading) = list else { return 0 }
            return counts["\(reading)|\(candidate)"] ?? 0
        }
        type("g4", into: e)
        XCTAssertEqual(e.candidates, ["是", "事", "世"], "the table's own order, before any learning")
        counts["ㄕˋ|世"] = 1
        e.backspace()                                  // drops the tone, so the next 4 re-sorts
        type("4", into: e)
        XCTAssertEqual(e.candidates, ["世", "是", "事"],
                       "the committed candidate leads; the rest keep the table's order")
    }

    func testLearningIsPerReadingNotPerCharacter() {
        var counts: [String: Int] = ["ㄕˋ|世": 5]
        let e = engine { list, candidate in
            guard case .zhuyin(let reading) = list else { return 0 }
            return counts["\(reading)|\(candidate)"] ?? 0
        }
        type("su3", into: e)                            // ㄋㄧˇ — a different reading
        XCTAssertEqual(e.candidates, ["你", "妳"], "another reading's count must not reach here")
        counts["ㄋㄧˇ|妳"] = 1
        e.backspace()
        type("3", into: e)
        XCTAssertEqual(e.candidates, ["妳", "你"])
    }

    func testPendingUsageNamesTheReadingsListAndIsGoneAfterCommit() {
        let e = engine()
        type("g4", into: e)
        e.selectCandidate(2)
        XCTAssertEqual(e.pendingUsage,
                       [CandidateUsage(list: .zhuyin(reading: "ㄕˋ"), candidate: "世")])
        XCTAssertEqual(e.commit(), "世")
        XCTAssertEqual(e.pendingUsage, [], "the reading that identified the list is gone")
    }

    func testASingleCandidateListRecordsNothing() {
        let e = engine()
        type("g", into: e)
        _ = e.applyFirstTone()                          // ㄕ → 詩 alone
        XCTAssertEqual(e.candidates, ["詩"])
        XCTAssertEqual(e.pendingUsage, [], "nothing to reorder, so nothing to learn")
    }

    func testUnfinishedSyllablesReportNoUsage() {
        let e = engine()
        type("su", into: e)
        XCTAssertEqual(e.pendingUsage, [])
    }
}
