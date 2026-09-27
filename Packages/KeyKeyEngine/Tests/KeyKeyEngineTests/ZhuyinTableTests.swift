import XCTest
@testable import KeyKeyEngine

// Parsing the bundled ㄅ半 table: the order it keeps, and the rows it drops.
final class ZhuyinTableTests: XCTestCase {
    private let sample = """
    # a comment line, and a blank one follow

    ㄕˋ\t是
    ㄕˋ\t事
    ㄕˋ\t世
    ㄋㄧˇ\t你
    ㄋㄧˇ\t妳
    """

    func testCharactersKeepTheTablesOwnOrder() {
        let table = ZhuyinTable(text: sample)
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), ["是", "事", "世"])
        XCTAssertEqual(table.characters(forReading: "ㄋㄧˇ"), ["你", "妳"])
    }

    func testCommentsAndBlankLinesAreSkipped() {
        XCTAssertEqual(ZhuyinTable(text: sample).readingCount, 2)
    }

    func testUnknownReadingIsEmptyNotACrash() {
        let table = ZhuyinTable(text: sample)
        XCTAssertEqual(table.characters(forReading: "ㄅㄨㄥˇ"), [])
        XCTAssertFalse(table.hasReading("ㄅㄨㄥˇ"))
        XCTAssertTrue(table.hasReading("ㄕˋ"))
    }

    func testToneIsPartOfTheReading() {
        // Different tones are different lists — 是 is not a candidate for ㄕ.
        let table = ZhuyinTable(text: "ㄕ\t詩\nㄕˋ\t是\n")
        XCTAssertEqual(table.characters(forReading: "ㄕ"), ["詩"])
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), ["是"])
    }

    func testARepeatedRowIsNotOfferedTwice() {
        // The same character twice under one reading would be two identical rows in the candidate
        // window, one of which can never be what the user wanted.
        let table = ZhuyinTable(text: "ㄕˋ\t是\nㄕˋ\t事\nㄕˋ\t是\n")
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), ["是", "事"])
    }

    func testRowsThatWouldRenderAsTofuAreDropped() {
        // The source is a CNS 11643 "large character set" table: about two rows in three name a
        // supplementary-plane or private-use character, which shows as a box in the candidate
        // window and pastes as one. Same policy as the 倉頡 tables.
        let table = ZhuyinTable(text: "ㄕˋ\t是\nㄕˋ\t\u{2A6B2}\nㄕˋ\t\u{F0000}\nㄕˋ\t事\n")
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), ["是", "事"])
    }

    func testMalformedRowsAreIgnoredRatherThanLoaded() {
        let table = ZhuyinTable(text: "ㄕˋ\t是\nno-tab-here\n\t沒有讀音\nㄕˋ\t兩個字x\n")
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), ["是"])
        XCTAssertEqual(table.readingCount, 1)
    }

    func testEmptyTextLoadsAnEmptyTable() {
        let table = ZhuyinTable(text: "")
        XCTAssertEqual(table.readingCount, 0)
        XCTAssertEqual(table.characters(forReading: "ㄕˋ"), [])
    }
}
