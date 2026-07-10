import XCTest
@testable import KeyKeyEngine

final class PinyinSegmenterTests: XCTestCase {
    // Minimal syllable set covering the cases under test.
    private let table = PinyinSyllableTable(text: """
    ni\tㄋㄧ
    hao\tㄏㄠ
    wo\tㄨㄛ
    men\tㄇㄣ
    qu\tㄑㄩ
    xi\tㄒㄧ
    xian\tㄒㄧㄢ
    an\tㄢ
    fan\tㄈㄢ
    gan\tㄍㄢ
    fang\tㄈㄤ
    lv\tㄌㄩ
    nve\tㄋㄩㄝ
    guan\tㄍㄨㄢ
    gu\tㄍㄨ
    pan\tㄆㄢ
    pang\tㄆㄤ
    chan\tㄔㄢ
    chang\tㄔㄤ
    """)

    private func seg(_ s: String) -> (syllables: [String], tail: String) {
        PinyinSegmenter(table: table).segment(s)
    }

    func testSimplePhrases() {
        XCTAssertEqual(seg("nihao").syllables, ["ni", "hao"])
        XCTAssertEqual(seg("womenqu").syllables, ["wo", "men", "qu"])
    }

    func testGreedyLongestMatch() {
        XCTAssertEqual(seg("xian").syllables, ["xian"])       // one syllable, not xi+an
        XCTAssertEqual(seg("fangan").syllables, ["fang", "an"]) // greedy: fang+an
    }

    func testApostropheForcesBoundary() {
        XCTAssertEqual(seg("xi'an").syllables, ["xi", "an"])
    }

    func testUpsilonViaV() {
        XCTAssertEqual(seg("lv").syllables, ["lv"])
        XCTAssertEqual(seg("nve").syllables, ["nve"])
    }

    func testTrailingUnparsableTail() {
        let r = seg("nihaoxq")
        XCTAssertEqual(r.syllables, ["ni", "hao"])
        XCTAssertEqual(r.tail, "xq")
    }

    func testEmpty() {
        let r = seg("")
        XCTAssertTrue(r.syllables.isEmpty)
        XCTAssertEqual(r.tail, "")
    }

    func testBacktracksWhenGreedyWouldStrand() {
        // fang+[uan] dead-ends; must backtrack to fan+guan (飯館).
        XCTAssertEqual(seg("fanguan").syllables, ["fan", "guan"])
        XCTAssertEqual(seg("fanguan").tail, "")
        // pang+[u] would strand; pan+gu is the full parse (盤古).
        XCTAssertEqual(seg("pangu").syllables, ["pan", "gu"])
        // chang+[uan] dead-ends; chan+guan.
        XCTAssertEqual(seg("changuan").syllables, ["chan", "guan"])
    }

    func testAmbiguousStillPrefersLongestFirstWhenBothFullyParse() {
        // Both fang+an and fan+gan fully parse; longest-first from the left keeps fang+an.
        XCTAssertEqual(seg("fangan").syllables, ["fang", "an"])
    }

    func testLeadingApostrophe() {
        let r = seg("'nihao")
        XCTAssertEqual(r.syllables, ["ni", "hao"])
        XCTAssertEqual(r.tail, "")
    }

    func testTrailingApostrophe() {
        let r = seg("nihao'")
        XCTAssertEqual(r.syllables, ["ni", "hao"])
        XCTAssertEqual(r.tail, "")
    }

    func testDoubledApostrophe() {
        // Consecutive apostrophes behave like a single boundary (skipApostrophes
        // advances past all of them), so "xi''an" segments exactly like "xi'an".
        let r = seg("xi''an")
        XCTAssertEqual(r.syllables, ["xi", "an"])
        XCTAssertEqual(r.tail, "")
    }

    func testOnlyApostrophes() {
        let r = seg("'''")
        XCTAssertEqual(r.syllables, [])
        XCTAssertEqual(r.tail, "")
    }

    func testApostropheOverridesGreedy() {
        // Contrast with testAmbiguousStillPrefersLongestFirstWhenBothFullyParse: an
        // explicit apostrophe forces the fan|gan boundary, blocking the "fang" reading
        // that greedy left-to-right matching would otherwise pick for "fangan".
        XCTAssertEqual(seg("fan'gan").syllables, ["fan", "gan"])
    }

    func testFullyInvalidInput() {
        let r = seg("xyz")
        XCTAssertEqual(r.syllables, [])
        XCTAssertEqual(r.tail, "xyz")
    }

    func testVeryLongValidInputNoCrash() {
        let long = String(repeating: "nihao", count: 16)   // 32 syllables
        let r = seg(long)
        XCTAssertEqual(r.syllables.count, 32)
        XCTAssertEqual(r.tail, "")
    }
}
