import XCTest
@testable import KeyKeyEngine

final class PhoneticLayoutTests: XCTestCase {
    // A trivial custom layout: only key "a" maps, to consonant "ㄅ".
    struct StubLayout: PhoneticLayout {
        func component(for key: Character) -> Component? {
            key == "a" ? .consonant("ㄅ") : nil
        }
    }

    func testReadingBufferUsesInjectedLayout() {
        var b = ReadingBuffer(layout: StubLayout())
        // "a" maps in the stub, "l" does not.
        XCTAssertEqual(b.receive("a"), .updated("ㄅ"))
        XCTAssertEqual(b.receive("l"), .unhandled)
    }

    func testStandardLayoutConformsToProtocol() {
        let layout: PhoneticLayout = StandardLayout()
        XCTAssertEqual(layout.component(for: "1"), .consonant("ㄅ"))
    }

    // The new state-aware `resolve` must not change Standard/ETen behaviour: its
    // default impl applies the stateless component to the given syllable.
    func testResolveDefaultUnaffectsDirectLayouts() {
        // Standard: "a" -> ㄇ merged onto an existing vowel ㄠ (a phoneme update).
        var prior = Syllable(); prior.vowel = "ㄠ"
        XCTAssertEqual(StandardLayout().resolve(key: "a", given: prior),
                       .phoneme({ var s = prior; s.consonant = "ㄇ"; return s }()))
        // ETen: "b" -> ㄅ on empty syllable.
        XCTAssertEqual(EtenLayout().resolve(key: "b", given: Syllable()),
                       .phoneme({ var s = Syllable(); s.consonant = "ㄅ"; return s }()))
        // Standard tone key (space == tone 1, no mark) -> .tone(nil).
        XCTAssertEqual(StandardLayout().resolve(key: " ", given: prior), .tone(nil))
        // Standard tone 2 key "6" -> .tone("ˊ").
        XCTAssertEqual(StandardLayout().resolve(key: "6", given: prior), .tone("ˊ"))
        // Unmapped key still returns nil through resolve.
        XCTAssertNil(StandardLayout().resolve(key: "`", given: Syllable()))
        // StubLayout (no resolve override) keeps working via the default.
        XCTAssertEqual(StubLayout().resolve(key: "a", given: Syllable()),
                       .phoneme({ var s = Syllable(); s.consonant = "ㄅ"; return s }()))
    }
}
