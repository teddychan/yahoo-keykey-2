import XCTest
@testable import KeyKeyEngine

final class WalkerTests: XCTestCase {
    // 今天 should beat 今+天 because the 2-syllable unigram scores higher than the sum.
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -4.0
    ㄐㄧㄣ 斤 -4.5
    ㄊㄧㄢ 天 -4.0
    ㄊㄧㄢ 田 -4.6
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.2
    """)

    func testBestPathPrefersPhrase() {
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: Self.lm)
        XCTAssertEqual(grid.walk().joined(), "今天")
    }

    func testCandidatesAtPositionLongestFirst() {
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: Self.lm)
        // position 0 overlaps the 2-syllable node (今天) and the 1-syllable node (今/斤)
        XCTAssertEqual(grid.candidates(at: 0), ["今天", "今", "斤"])
    }

    func testFallbackForUnknownReading() {
        let grid = ReadingGrid(readings: ["ㄓㄜ"], languageModel: Self.lm)  // not in LM
        XCTAssertEqual(grid.walk().joined(), "ㄓㄜ")
    }
}
