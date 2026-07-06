import XCTest
@testable import KeyKeyEngine

final class CangjieCodeIndexTests: XCTestCase {
    // 面 = 一田卜中 (mwyl); 日 has two codes of different length; 倉 = 人口竹口 (orhr).
    static let table = CangjieTable(text: """
    # inline fixture
    a\t日
    aa\t日
    mwyl\t面
    or\t你
    orhr\t倉
    """)
    static let index = CangjieCodeIndex(table: CangjieCodeIndexTests.table)

    func testCodeGlyphsMapsLettersToRadicalGlyphs() {
        // m→一 w→田 y→卜 l→中
        XCTAssertEqual(Self.index.codeGlyphs(for: "面"), "一田卜中")
    }

    func testPrefersShortestCodeWhenMultiple() {
        // 日 has "a" and "aa"; the single-letter code wins → a→日 radical
        XCTAssertEqual(Self.index.codeGlyphs(for: "日"), "日")
    }

    func testAbsentCharacterReturnsNil() {
        XCTAssertNil(Self.index.codeGlyphs(for: "X"))
        XCTAssertNil(Self.index.codeGlyphs(for: "水"))
    }

    func testMultiLetterCode() {
        // o→人 r→口 h→竹 r→口
        XCTAssertEqual(Self.index.codeGlyphs(for: "倉"), "人口竹口")
    }

    func testTieBreakIsLexicographicForEqualLength() {
        // Two equal-length codes for the same char: the lexicographically smaller wins.
        let t = CangjieTable(text: """
        zb\t甲
        za\t甲
        """)
        let idx = CangjieCodeIndex(table: t)
        // za < zb → z→重 a→日
        XCTAssertEqual(idx.codeGlyphs(for: "甲"), "重日")
    }
}
