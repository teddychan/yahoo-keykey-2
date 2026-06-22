import XCTest
@testable import KeyKeyEngine

final class PlainPhoneticEngineTests: XCTestCase {
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -4.5
    ㄐㄧㄣ 斤 -4.0
    ㄇㄠ 貓 -4.0
    ㄇㄠ 毛 -4.2
    """)

    private func make() -> PlainPhoneticEngine { PlainPhoneticEngine(languageModel: Self.lm) }

    func testMidSyllableShowsComposingNoCandidates() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // ㄇ
        XCTAssertTrue(e.handleKey("l"))   // ㄇㄠ
        XCTAssertEqual(e.composingText, "ㄇㄠ")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testCompletedReadingShowsCandidatesSortedBestFirst() {
        let e = make()
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p")  // ㄐㄧㄣ
        XCTAssertTrue(e.handleKey(" "))   // tone 1 completes ㄐㄧㄣ
        XCTAssertEqual(e.composingText, "ㄐㄧㄣ")
        XCTAssertEqual(e.candidates, ["斤", "今"])   // -4.0 best, then -4.5
    }

    func testSelectCandidateCommitsThatCharAndResets() {
        let e = make()
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p"); _ = e.handleKey(" ")
        XCTAssertEqual(e.selectCandidate(1), "今")   // not the best
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testSelectCandidateOutOfRangeIsNoOp() {
        let e = make()
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p"); _ = e.handleKey(" ")
        XCTAssertEqual(e.selectCandidate(99), "")        // out of range: no commit
        XCTAssertEqual(e.composingText, "ㄐㄧㄣ")          // state unchanged
        XCTAssertEqual(e.candidates, ["斤", "今"])
    }

    func testCommitPicksBestCandidate() {
        let e = make()
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p"); _ = e.handleKey(" ")
        XCTAssertEqual(e.commit(), "斤")            // best candidate
        XCTAssertEqual(e.composingText, "")
    }

    func testCommitWithNoCandidatesReturnsRawReading() {
        let e = make()
        // ㄋㄩ : key 's' -> ㄋ, 'm' -> ㄩ ; this reading has no LM entry
        _ = e.handleKey("s"); _ = e.handleKey("m"); _ = e.handleKey(" ")
        XCTAssertEqual(e.composingText, "ㄋㄩ")
        XCTAssertTrue(e.candidates.isEmpty)
        XCTAssertEqual(e.commit(), "ㄋㄩ")        // no candidate -> raw reading
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceMidSyllableRemovesLastComponent() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l")   // ㄇㄠ
        e.backspace()
        XCTAssertEqual(e.composingText, "ㄇ")
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceClearsCompletedReading() {
        let e = make()
        _ = e.handleKey("r"); _ = e.handleKey("u"); _ = e.handleKey("p"); _ = e.handleKey(" ")
        XCTAssertEqual(e.composingText, "ㄐㄧㄣ")
        e.backspace()
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testUnmappedKeyNotConsumed() {
        let e = make()
        XCTAssertFalse(e.handleKey("`"))
    }
}
