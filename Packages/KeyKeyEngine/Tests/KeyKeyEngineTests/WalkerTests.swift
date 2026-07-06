import XCTest
@testable import KeyKeyEngine

final class WalkerTests: XCTestCase {
    // Fixture LM: single chars for ㄋㄧ, ㄏㄠ, plus the phrase ㄋㄧ-ㄏㄠ (higher combined pref).
    private func index() -> TonelessLanguageModelIndex {
        TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄋㄧ 泥 -6.0
        ㄏㄠ 好 -3.0
        ㄏㄠ 號 -4.0
        ㄋㄧ-ㄏㄠ 你好 -5.0
        """)
    }

    func testPrefersPhraseOverTwoSingles() {
        // Two singles cost -3.0 + -3.0 = -6.0; the phrase costs -5.0 (better).
        let walker = Walker(index: index())
        let nodes = walker.walk(readings: ["ㄋㄧ", "ㄏㄠ"], rawSyllables: ["ni", "hao"],
                                userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].chosenText, "你好")
        XCTAssertEqual(nodes[0].readingRange, 0..<2)
    }

    func testSingleReadingHasCandidatesSortedByScore() {
        let walker = Walker(index: index())
        let nodes = walker.walk(readings: ["ㄋㄧ"], rawSyllables: ["ni"], userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].candidates, ["你", "泥"])
        XCTAssertEqual(nodes[0].chosenText, "你")
    }

    func testUserBonusReordersCandidatesButNotSegmentation() {
        let walker = Walker(index: index())
        // Big bonus for 泥 lifts it above 你 within the node.
        let nodes = walker.walk(readings: ["ㄋㄧ"], rawSyllables: ["ni"],
                                userBonus: { $0 == "泥" ? 100 : 0 })
        XCTAssertEqual(nodes[0].candidates.first, "泥")
    }

    func testUnmappedReadingFallsBackToRawText() {
        let walker = Walker(index: index())
        // ㄗㄗ has no LM entry -> raw-text node keeps the pinyin visible; path still complete.
        let nodes = walker.walk(readings: ["ㄗㄗ"], rawSyllables: ["zz"], userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].chosenText, "zz")
    }

    func testPrefersSinglesWhenPhraseScoresWorse() {
        // Phrase ㄋㄧ-ㄏㄠ at -50 is far worse than 你(-3) + 好(-3) = -6, so singles win.
        let idx = TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄏㄠ 好 -3.0
        ㄋㄧ-ㄏㄠ 你好 -50.0
        """)
        let nodes = Walker(index: idx).walk(readings: ["ㄋㄧ", "ㄏㄠ"], rawSyllables: ["ni", "hao"], userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.map(\.chosenText), ["你", "好"])
    }

    func testEmptyReadings() {
        let walker = Walker(index: index())
        XCTAssertTrue(walker.walk(readings: [], rawSyllables: [], userBonus: { _ in 0 }).isEmpty)
    }
}

extension WalkerTests {
    func testLongInputCompletesQuickly() {
        let walker = Walker(index: index())
        let readings = Array(repeating: "ㄋㄧ", count: 24)
        let raws = Array(repeating: "ni", count: 24)
        let start = Date()
        let nodes = walker.walk(readings: readings, rawSyllables: raws, userBonus: { _ in 0 })
        XCTAssertFalse(nodes.isEmpty)
        // Reconstructed reading coverage must be complete.
        XCTAssertEqual(nodes.reduce(0) { $0 + $1.readingRange.count }, 24)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.1)
    }
}
