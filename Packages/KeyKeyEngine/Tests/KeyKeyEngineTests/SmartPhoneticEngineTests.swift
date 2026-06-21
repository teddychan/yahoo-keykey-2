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
}
