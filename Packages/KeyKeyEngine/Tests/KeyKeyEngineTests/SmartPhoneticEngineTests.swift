import XCTest
@testable import KeyKeyEngine

final class SmartPhoneticEngineTests: XCTestCase {
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄇㄠ 貓 -4.0
    ㄇㄠ 毛 -4.2
    """)

    private func make() -> SmartPhoneticEngine { SmartPhoneticEngine(languageModel: Self.lm) }

    func testTypeOneSyllableShowsComposingAndCandidates() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // ㄇ
        XCTAssertTrue(e.handleKey("l"))   // ㄇㄠ
        XCTAssertTrue(e.handleKey(" "))   // tone 1 completes reading ㄇㄠ
        XCTAssertEqual(e.composingText, "貓")
        XCTAssertEqual(e.candidates, ["貓", "毛"])
    }

    func testSelectCandidateOverrides() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "毛")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        XCTAssertEqual(e.commit(), "貓")
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testBackspaceRemovesReading() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")  // one reading
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testUnmappedKeyNotConsumed() {
        let e = make()
        XCTAssertFalse(e.handleKey("`"))
    }

    func testIsComposingSyllableTrueWithPhonemesFalseAfterTone() {
        let e = SmartPhoneticEngine(languageModel: Self.phraseLM)
        XCTAssertFalse(e.isComposingSyllable)              // nothing typed yet
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p")  // ㄐㄧㄣ phonemes
        XCTAssertTrue(e.isComposingSyllable)               // mid-syllable, no tone
        _ = e.handleKey(" ")                               // tone 1 finalizes
        XCTAssertFalse(e.isComposingSyllable)
    }

    static let phraseLM = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -4.0
    ㄐㄧㄣ 斤 -4.5
    ㄊㄧㄢ 天 -4.0
    ㄊㄧㄢ 田 -4.6
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.2
    """)

    func testSelectionWorksWhenPhraseWinsWalk() {
        let e = SmartPhoneticEngine(languageModel: Self.phraseLM)
        // type ㄐㄧㄣ (r,u,p, space) then ㄊㄧㄢ (w,u,0, space)
        for k in ["r","u","p"," ","w","u","0"," "] { _ = e.handleKey(Character(k)) }
        XCTAssertEqual(e.composingText, "今天")            // phrase wins by default
        // candidates at the last position include 天/田 (and the phrase); pick 田
        let i = e.candidates.firstIndex(of: "田")
        XCTAssertNotNil(i)
        e.selectCandidate(i!)
        XCTAssertEqual(e.composingText, "今田")            // selection applied despite phrase walk
    }

    private func makeTwoSyllable() -> SmartPhoneticEngine {
        let e = SmartPhoneticEngine(languageModel: Self.phraseLM)
        // type ㄐㄧㄣ then ㄊㄧㄢ -> two readings
        for k in ["r","u","p"," ","w","u","0"," "] { _ = e.handleKey(Character(k)) }
        return e
    }

    func testCursorDefaultsToLastPosition() {
        let e = makeTwoSyllable()
        XCTAssertEqual(e.cursorPosition, 1)
    }

    func testMoveCursorLeftThenSelectOverridesNonFinalSyllable() {
        let e = makeTwoSyllable()
        e.moveCursorLeft()                       // cursor now at position 0 (今)
        XCTAssertEqual(e.cursorPosition, 0)
        // candidates at position 0 include 今天 (phrase), 今, 斤; pick 斤
        let i = e.candidates.firstIndex(of: "斤")
        XCTAssertNotNil(i)
        e.selectCandidate(i!)
        XCTAssertEqual(e.composingText, "斤天")   // non-final syllable overridden
    }

    func testCandidatesAtPositionDelegatesToGrid() {
        let e = makeTwoSyllable()
        XCTAssertEqual(e.candidates(at: 0), ["今天", "今", "斤"])
    }

    func testCursorClampsAtBounds() {
        let e = makeTwoSyllable()
        e.moveCursorLeft(); e.moveCursorLeft(); e.moveCursorLeft()
        XCTAssertEqual(e.cursorPosition, 0)      // clamped at low bound
        e.moveCursorRight(); e.moveCursorRight(); e.moveCursorRight()
        XCTAssertEqual(e.cursorPosition, 1)      // clamped at high bound
    }

    func testLastPositionSelectionStillWorksAfterMovingBack() {
        let e = makeTwoSyllable()
        e.moveCursorLeft()                       // position 0
        e.moveCursorRight()                      // back to position 1
        let i = e.candidates.firstIndex(of: "田")
        XCTAssertNotNil(i)
        e.selectCandidate(i!)
        XCTAssertEqual(e.composingText, "今田")
    }

    func testSelectCandidateAtExplicitPosition() {
        let e = makeTwoSyllable()
        let i = e.candidates(at: 0).firstIndex(of: "斤")
        XCTAssertNotNil(i)
        e.selectCandidate(at: 0, index: i!)
        XCTAssertEqual(e.composingText, "斤天")
    }

    func testTypingNewReadingResetsMovedCursorToLastPosition() {
        let e = makeTwoSyllable()           // two readings, cursor tracks last
        e.moveCursorLeft()                  // cursor moved to position 0
        XCTAssertEqual(e.cursorPosition, 0)
        // type a 3rd reading ㄊㄧㄢ (w,u,0, space)
        for k in ["w","u","0"," "] { _ = e.handleKey(Character(k)) }
        XCTAssertEqual(e.cursorPosition, 2) // cursor tracks the new last reading
        XCTAssertEqual(e.candidates, ["天", "田"])
    }
}
