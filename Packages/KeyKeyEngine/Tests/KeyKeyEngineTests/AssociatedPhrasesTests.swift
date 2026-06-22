import XCTest
@testable import KeyKeyEngine

final class AssociatedPhrasesTests: XCTestCase {
    static let fixture = """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -3.00000000
    ㄐㄧㄣ-ㄖˋ 今日 -4.00000000
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.20000000
    ㄐㄧㄣ-ㄨㄢˇ 今晚 -5.00000000
    ㄇㄠ 貓 -4.10000000

    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.20000000
    """

    func testAssociationsBestFirst() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今"), ["今天", "今日", "今晚"])
    }

    func testSingleCharEntriesExcluded() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertFalse(ap.associations(for: "今").contains("今"))
    }

    func testUnknownCharReturnsEmpty() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "貓"), [])
    }

    func testDeDup() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "今").filter { $0 == "今天" }.count, 1)
    }

    func testCommentAndBlankLinesIgnored() {
        let ap = AssociatedPhrases(text: Self.fixture)
        XCTAssertEqual(ap.associations(for: "#"), [])
    }
}
