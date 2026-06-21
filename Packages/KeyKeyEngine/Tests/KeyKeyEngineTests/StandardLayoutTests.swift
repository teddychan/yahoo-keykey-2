import XCTest
@testable import KeyKeyEngine

final class StandardLayoutTests: XCTestCase {
    func testConsonantKeys() {
        XCTAssertEqual(StandardLayout.component(for: "1"), .consonant("ㄅ"))
        XCTAssertEqual(StandardLayout.component(for: "z"), .consonant("ㄈ"))
    }
    func testMedialAndVowel() {
        XCTAssertEqual(StandardLayout.component(for: "u"), .medial("ㄧ"))
        XCTAssertEqual(StandardLayout.component(for: "8"), .vowel("ㄚ"))
    }
    func testToneKeys() {
        XCTAssertEqual(StandardLayout.component(for: " "), .tone(nil))   // space = tone 1
        XCTAssertEqual(StandardLayout.component(for: "6"), .tone("ˊ"))
        XCTAssertEqual(StandardLayout.component(for: "3"), .tone("ˇ"))
        XCTAssertEqual(StandardLayout.component(for: "4"), .tone("ˋ"))
        XCTAssertEqual(StandardLayout.component(for: "7"), .tone("˙"))
    }
    func testUnmappedKey() {
        XCTAssertNil(StandardLayout.component(for: "`"))
    }
}
