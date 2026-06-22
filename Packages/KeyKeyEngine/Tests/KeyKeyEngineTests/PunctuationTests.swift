import XCTest
@testable import KeyKeyEngine

final class PunctuationTests: XCTestCase {
    func testComma() {
        XCTAssertEqual(Punctuation.fullWidth(for: ","), "，")
    }

    func testPeriod() {
        XCTAssertEqual(Punctuation.fullWidth(for: "."), "。")
    }

    func testOpenCornerBracket() {
        XCTAssertEqual(Punctuation.fullWidth(for: "["), "「")
    }

    func testCloseCornerBracket() {
        XCTAssertEqual(Punctuation.fullWidth(for: "]"), "」")
    }

    func testQuestionMark() {
        XCTAssertEqual(Punctuation.fullWidth(for: "?"), "？")
    }

    func testOpenParen() {
        XCTAssertEqual(Punctuation.fullWidth(for: "("), "（")
    }

    func testCloseParen() {
        XCTAssertEqual(Punctuation.fullWidth(for: ")"), "）")
    }

    func testIdeographicComma() {
        XCTAssertEqual(Punctuation.fullWidth(for: "\\"), "、")
    }

    func testBacktickIdeographicComma() {
        XCTAssertEqual(Punctuation.fullWidth(for: "`"), "、")
    }

    func testDoubleAngleBrackets() {
        XCTAssertEqual(Punctuation.fullWidth(for: "<"), "《")
        XCTAssertEqual(Punctuation.fullWidth(for: ">"), "》")
    }

    func testNonPunctuationLetterReturnsNil() {
        XCTAssertNil(Punctuation.fullWidth(for: "a"))
    }

    func testNonPunctuationDigitReturnsNil() {
        XCTAssertNil(Punctuation.fullWidth(for: "1"))
    }
}
