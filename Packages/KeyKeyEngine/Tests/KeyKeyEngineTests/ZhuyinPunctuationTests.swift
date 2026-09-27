import XCTest
@testable import KeyKeyEngine

// The marks 注音 moves, and — just as important — the ones it leaves alone.
final class ZhuyinPunctuationTests: XCTestCase {
    func testDachenMovesTheMarksWhoseKeysType注音() {
        // `,` `.` `;` type ㄝ ㄡ ㄤ on 大千, so these four marks live on the shifted keys — the
        // arrangement the original Yahoo! KeyKey's own bpmf-punctuations.cin has.
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: "<", layout: .dachen), "，")
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: ">", layout: .dachen), "。")
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: "'", layout: .dachen), "、")
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: "\"", layout: .dachen), "；")
    }

    func testEtenMovesOnlyTheTwoItHasTo() {
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: "<", layout: .eten), "，")
        XCTAssertEqual(ZhuyinPunctuation.fullWidth(for: ">", layout: .eten), "。")
        // `'` types ㄘ on 倚天, so the engine claims it before punctuation is ever consulted and
        // there is no override to make.
        XCTAssertNil(ZhuyinPunctuation.fullWidth(for: "'", layout: .eten))
        XCTAssertNil(ZhuyinPunctuation.fullWidth(for: "\"", layout: .eten))
    }

    func testEverythingElseFallsBackToTheSharedTable() {
        // Only the differences are listed here; a key both tables agree on must return nil so the
        // one shared table stays the single source for it.
        for key in Array("[]!?~`:+=-_|{}()") {
            XCTAssertNil(ZhuyinPunctuation.fullWidth(for: key, layout: .dachen),
                         "\(key) should be left to the shared Punctuation table")
        }
    }

    // The overrides must not collide with the layout: a key the engine consumes would never reach
    // punctuation, so an entry for one would be dead — and a sign the two disagree about a key.
    func testNoOverrideSitsOnAKeyItsLayoutAlreadyTypes() {
        for id in ZhuyinKeyboardLayout.Identifier.allCases {
            let layout = ZhuyinKeyboardLayout.layout(for: id)
            for code in 33...126 {
                let key = Character(UnicodeScalar(code)!)
                if layout.symbol(for: key) != nil {
                    XCTAssertNil(ZhuyinPunctuation.fullWidth(for: key, layout: id),
                                 "\(id.rawValue) types \(key) as 注音, so an override is unreachable")
                }
            }
        }
    }
}
