import XCTest
@testable import KeyKeyEngine

// The key maps themselves. A layout is data, and a wrong entry is indistinguishable from a broken
// keyboard to the person typing, so the everyday keys are pinned by hand and the whole map is
// checked for completeness — every 注音 symbol reachable, exactly once, on both layouts.
final class ZhuyinKeyboardLayoutTests: XCTestCase {
    // Every symbol a 注音 syllable can be built from: 21 initials, 3 medials, 13 finals.
    private var allSymbols: Set<Character> {
        ZhuyinSyllable.initials.union(ZhuyinSyllable.medials).union(ZhuyinSyllable.finals)
    }
    private let toneMarks: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]

    // MARK: 大千

    func testDachenHomeRowAndNumberRow() {
        let l = ZhuyinKeyboardLayout.dachen
        // The four corners of the 大千 layout a Taiwanese keyboard prints.
        XCTAssertEqual(l.symbol(for: "1"), "ㄅ")
        XCTAssertEqual(l.symbol(for: "5"), "ㄓ")
        XCTAssertEqual(l.symbol(for: "u"), "ㄧ")
        XCTAssertEqual(l.symbol(for: "j"), "ㄨ")
        XCTAssertEqual(l.symbol(for: "m"), "ㄩ")
        XCTAssertEqual(l.symbol(for: "a"), "ㄇ")
        XCTAssertEqual(l.symbol(for: "/"), "ㄥ")
        XCTAssertEqual(l.symbol(for: "-"), "ㄦ")
    }

    func testDachenToneKeysAreTheNumberRow() {
        let l = ZhuyinKeyboardLayout.dachen
        XCTAssertEqual(l.symbol(for: "6"), "ˊ")
        XCTAssertEqual(l.symbol(for: "3"), "ˇ")
        XCTAssertEqual(l.symbol(for: "4"), "ˋ")
        XCTAssertEqual(l.symbol(for: "7"), "˙")
    }

    // MARK: 倚天

    func testEtenPutsSymbolsOnTheLettersThatSpellThem() {
        let l = ZhuyinKeyboardLayout.eten
        XCTAssertEqual(l.symbol(for: "b"), "ㄅ")
        XCTAssertEqual(l.symbol(for: "p"), "ㄆ")
        XCTAssertEqual(l.symbol(for: "m"), "ㄇ")
        XCTAssertEqual(l.symbol(for: "f"), "ㄈ")
        XCTAssertEqual(l.symbol(for: "s"), "ㄙ")
        // …and the ones it does not: ㄐ on `g`, ㄑ on `7`, ㄓㄔㄕ on the punctuation cluster.
        XCTAssertEqual(l.symbol(for: "g"), "ㄐ")
        XCTAssertEqual(l.symbol(for: "7"), "ㄑ")
        XCTAssertEqual(l.symbol(for: ","), "ㄓ")
        XCTAssertEqual(l.symbol(for: "."), "ㄔ")
        XCTAssertEqual(l.symbol(for: "/"), "ㄕ")
        XCTAssertEqual(l.symbol(for: "'"), "ㄘ")
    }

    func testEtenToneKeysAreOneToFour() {
        let l = ZhuyinKeyboardLayout.eten
        XCTAssertEqual(l.symbol(for: "1"), "˙")   // 輕聲 leads on 倚天, unlike 大千
        XCTAssertEqual(l.symbol(for: "2"), "ˊ")
        XCTAssertEqual(l.symbol(for: "3"), "ˇ")
        XCTAssertEqual(l.symbol(for: "4"), "ˋ")
    }

    // MARK: Completeness — the property that makes a layout usable at all

    func testEveryLayoutTypesEverySymbolAndEveryToneExactlyOnce() {
        for id in ZhuyinKeyboardLayout.Identifier.allCases {
            let layout = ZhuyinKeyboardLayout.layout(for: id)
            // ASCII printable, minus Space (the first-tone key the controller owns) — the whole
            // set a layout could possibly claim.
            let keys = (33...126).map { Character(UnicodeScalar($0)!) }
            var produced: [Character: [Character]] = [:]
            for key in keys {
                guard let symbol = layout.symbol(for: key) else { continue }
                produced[symbol, default: []].append(key)
            }
            let wanted = allSymbols.union(toneMarks)
            XCTAssertEqual(Set(produced.keys), wanted,
                           "\(id.rawValue) does not type exactly the 注音 symbols and tones")
            for (symbol, keys) in produced {
                XCTAssertEqual(keys.count, 1,
                               "\(id.rawValue) types \(symbol) from more than one key: \(keys)")
            }
        }
    }

    func testAnUnmappedKeyIsNotThisLayouts() {
        // `q` types ㄆ on 大千 but nothing on 倚天's number-row ㄑ arrangement… except it does
        // (ㄟ), so use a key neither layout claims: no layout maps `[`.
        XCTAssertNil(ZhuyinKeyboardLayout.dachen.symbol(for: "["))
        XCTAssertNil(ZhuyinKeyboardLayout.eten.symbol(for: "["))
        // Space is deliberately absent from every map: it is the first-tone key, which only the
        // controller can apply (it also pages and commits).
        XCTAssertNil(ZhuyinKeyboardLayout.dachen.symbol(for: " "))
        XCTAssertNil(ZhuyinKeyboardLayout.eten.symbol(for: " "))
    }

    func testLayoutForIdentifierRoundTrips() {
        for id in ZhuyinKeyboardLayout.Identifier.allCases {
            XCTAssertEqual(ZhuyinKeyboardLayout.layout(for: id).id, id)
        }
        // The raw values are persisted in UserDefaults; changing one silently resets every user's
        // keyboard to the default.
        XCTAssertEqual(ZhuyinKeyboardLayout.Identifier.dachen.rawValue, "dachen")
        XCTAssertEqual(ZhuyinKeyboardLayout.Identifier.eten.rawValue, "eten")
    }

    // The same syllable must be typable on both layouts and spell the same reading — the reason
    // the bundled table is keyed by reading rather than by key sequence.
    func testTheSameSyllableSpellsTheSameReadingOnBothLayouts() {
        var dachen = ZhuyinSyllable()
        for key in "su3" { _ = dachen.insert(ZhuyinKeyboardLayout.dachen.symbol(for: key)!) }
        var eten = ZhuyinSyllable()
        for key in "ne3" { _ = eten.insert(ZhuyinKeyboardLayout.eten.symbol(for: key)!) }
        XCTAssertEqual(dachen.reading, "ㄋㄧˇ")
        XCTAssertEqual(eten.reading, dachen.reading)
    }
}
