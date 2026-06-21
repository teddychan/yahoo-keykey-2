import XCTest
@testable import KeyKeyEngine

final class ReadingBufferTests: XCTestCase {
    func testBuildAndCompleteOnTone() {
        var b = ReadingBuffer()
        // type "ㄇㄠ" then space (tone 1): keys a, l, space
        XCTAssertEqual(b.receive("a"), .updated("ㄇ"))
        XCTAssertEqual(b.receive("l"), .updated("ㄇㄠ"))
        XCTAssertEqual(b.receive(" "), .completed("ㄇㄠ"))
        XCTAssertTrue(b.isEmpty)
    }

    func testToneMarkCompletes() {
        var b = ReadingBuffer()
        _ = b.receive("a")          // ㄇ
        _ = b.receive("l")          // ㄇㄠ
        XCTAssertEqual(b.receive("4"), .completed("ㄇㄠˋ"))
    }

    func testOverwriteSameClass() {
        var b = ReadingBuffer()
        _ = b.receive("1")          // ㄅ
        XCTAssertEqual(b.receive("q"), .updated("ㄆ"))   // consonant replaced
    }

    func testBackspaceRemovesLastComponent() {
        var b = ReadingBuffer()
        _ = b.receive("a")          // ㄇ
        _ = b.receive("l")          // ㄇㄠ
        XCTAssertEqual(b.backspace(), .updated("ㄇ"))
        XCTAssertEqual(b.backspace(), .updated(""))
        XCTAssertEqual(b.backspace(), .empty)
    }

    func testUnmappedKeyIgnored() {
        var b = ReadingBuffer()
        _ = b.receive("a")
        XCTAssertEqual(b.receive("`"), .unhandled)
    }
}
