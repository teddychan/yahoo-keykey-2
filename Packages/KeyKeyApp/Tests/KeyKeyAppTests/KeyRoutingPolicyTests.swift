import XCTest
import AppKit
@testable import KeyKeyApp

// Characterization tests for the candidate/聯想 key-routing decisions InputController.handle()
// consults — the numbered-window half of KeyEventPolicy. (KeyEventPolicyTests covers the two
// older decisions, isSystemShortcut/spaceConfirmsStroke, i.e. issues #56 and #61.)
//
// Every expectation here was derived from the routing code as it stood BEFORE the extraction,
// so a change in any of these values is a change in what the IME does on a keystroke — never a
// test to "fix". The window is 9 rows (InputController.pageSize), so the tests pass pageSize: 9.
final class KeyRoutingPolicyTests: XCTestCase {

    // MARK: selectionDigit — the 1–9 pick read from `characters`

    func testDigitCharactersSelect() {
        for digit in 1...9 {
            XCTAssertEqual(KeyEventPolicy.selectionDigit(characters: String(digit)), digit)
        }
    }

    func testZeroIsNotASelection() {
        // The window numbers rows 1–9, so 0 picks nothing and falls through to be typed.
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: "0"))
    }

    func testNonDigitsAreNotSelections() {
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: nil))
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: ""))
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: "a"))
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: " "))
        // Shift+1 reports its symbol, not the digit — this is exactly why a shifted number key
        // is not a pick in the default (.number) 聯想 mode.
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: "!"))
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: "&"))
        // Int() would parse "10", but it is outside the 1–9 the window offers.
        XCTAssertNil(KeyEventPolicy.selectionDigit(characters: "10"))
    }

    // MARK: associationSelectionDigit — .number trigger (default, issue #52)

    func testNumberTriggerPicksOnPlainDigit() {
        XCTAssertEqual(KeyEventPolicy.associationSelectionDigit(trigger: .number, characters: "3",
                                                                modifierFlags: [], keyCode: 20), 3)
    }

    func testNumberTriggerIgnoresTheKeyCode() {
        // .number reads `characters` only, so any key that types a digit picks, and a key code
        // from the number row does NOT pick by itself.
        XCTAssertEqual(KeyEventPolicy.associationSelectionDigit(trigger: .number, characters: "7",
                                                                modifierFlags: [], keyCode: 0), 7)
        XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .number, characters: "a",
                                                              modifierFlags: [], keyCode: 18))
    }

    func testNumberTriggerFallsThroughOnShiftedDigit() {
        // Shift+7 arrives as "&", which Int() rejects: no pick, so the caller dismisses the
        // suggestions and processes the key normally. Documented as "as before" in the routing.
        XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .number, characters: "&",
                                                              modifierFlags: [.shift], keyCode: 26))
    }

    // MARK: associationSelectionDigit — .shift trigger (issue #52)

    func testShiftTriggerPicksByPhysicalNumberRowKeyCode() {
        // The number row, left to right. Note 23/22 (5/6) and 26/28/25 (7/8/9) are not in
        // ascending key-code order — that is the real US keyboard layout, not a typo.
        let numberRow: [(UInt16, Int)] = [(18, 1), (19, 2), (20, 3), (21, 4), (23, 5),
                                          (22, 6), (26, 7), (28, 8), (25, 9)]
        for (keyCode, digit) in numberRow {
            // `characters` is the shifted symbol here (7 → &) and is deliberately not consulted.
            XCTAssertEqual(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: "&",
                                                                    modifierFlags: [.shift],
                                                                    keyCode: keyCode),
                           digit, "key code \(keyCode) must pick \(digit)")
        }
    }

    func testShiftTriggerRejectsABareDigit() {
        // The whole point of #52: with .shift selected, a plain 1–9 types the number instead of
        // picking a phrase.
        XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: "1",
                                                              modifierFlags: [], keyCode: 18))
    }

    func testShiftTriggerRejectsOtherModifiers() {
        for extra in [NSEvent.ModifierFlags.control, .option, .command] {
            XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: "!",
                                                                  modifierFlags: [.shift, extra],
                                                                  keyCode: 18))
        }
    }

    func testShiftTriggerToleratesCapsLock() {
        // Caps Lock is not one of ⌃⌥⌘, so Shift+1 still picks with Caps on.
        XCTAssertEqual(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: "!",
                                                                modifierFlags: [.shift, .capsLock],
                                                                keyCode: 18), 1)
    }

    func testShiftTriggerRejectsKeysOffTheNumberRow() {
        // 29 is the `0` key; 12 is `q`. Neither is in the 1–9 map.
        XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: ")",
                                                              modifierFlags: [.shift], keyCode: 29))
        XCTAssertNil(KeyEventPolicy.associationSelectionDigit(trigger: .shift, characters: "Q",
                                                              modifierFlags: [.shift], keyCode: 12))
    }

    // MARK: candidateIndex — page arithmetic, shared by candidates and 聯想

    func testFirstPageMapsDigitsToTheFirstNineRows() {
        for digit in 1...9 {
            XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: digit, page: 0, pageSize: 9, count: 30),
                           digit - 1)
        }
    }

    func testLaterPagesOffsetByWholePages() {
        XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: 1, page: 1, pageSize: 9, count: 30), 9)
        XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: 9, page: 1, pageSize: 9, count: 30), 17)
        XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: 1, page: 2, pageSize: 9, count: 30), 18)
    }

    func testDigitPastTheEndOfTheListSelectsNothing() {
        // A short last page: 20 candidates means page 2 shows only rows 1–2 (indices 18, 19).
        XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: 2, page: 2, pageSize: 9, count: 20), 19)
        XCTAssertNil(KeyEventPolicy.candidateIndex(digit: 3, page: 2, pageSize: 9, count: 20))
        XCTAssertNil(KeyEventPolicy.candidateIndex(digit: 9, page: 2, pageSize: 9, count: 20))
        // Callers SWALLOW that nil rather than passing the key on, so no stray digit is typed.
    }

    func testShortSingleListPage() {
        XCTAssertEqual(KeyEventPolicy.candidateIndex(digit: 3, page: 0, pageSize: 9, count: 3), 2)
        XCTAssertNil(KeyEventPolicy.candidateIndex(digit: 4, page: 0, pageSize: 9, count: 3))
    }

    // MARK: pageStep — arrows and Page Up / Page Down

    func testNextPageKeys() {
        for keyCode: UInt16 in [125, 124, 121] { // Down / Right arrow / Page Down
            XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: keyCode, page: 0, lastPage: 2),
                           .move(to: 1), "key code \(keyCode)")
        }
    }

    func testPreviousPageKeys() {
        for keyCode: UInt16 in [126, 123, 116] { // Up / Left arrow / Page Up
            XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: keyCode, page: 2, lastPage: 2),
                           .move(to: 1), "key code \(keyCode)")
        }
    }

    func testPagingKeysAtTheEdgesDoNotWrapButAreStillConsumed() {
        // Arrows clamp — unlike Space, which wraps. Both ends still swallow the key so the arrow
        // never reaches the app while the window is up.
        XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: 125, page: 2, lastPage: 2), .atEdge)
        XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: 126, page: 0, lastPage: 2), .atEdge)
        // A single page has nowhere to go in either direction.
        XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: 125, page: 0, lastPage: 0), .atEdge)
        XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: 126, page: 0, lastPage: 0), .atEdge)
    }

    func testNonPagingKeysFallThrough() {
        // Space (49), Return (36), Escape (53), Backspace (51) and ordinary keys (18 = "1") all
        // have their own meanings further down handle(), so paging must not claim them.
        for keyCode: UInt16 in [49, 36, 53, 51, 18, 0] {
            XCTAssertEqual(KeyEventPolicy.pageStep(keyCode: keyCode, page: 0, lastPage: 2),
                           .notPaging, "key code \(keyCode)")
        }
    }

    // MARK: spacePage — Space wraps last → first

    func testSpaceAdvancesAPage() {
        XCTAssertEqual(KeyEventPolicy.spacePage(page: 0, lastPage: 2), 1)
        XCTAssertEqual(KeyEventPolicy.spacePage(page: 1, lastPage: 2), 2)
    }

    func testSpaceWrapsFromTheLastPageBackToTheFirst() {
        XCTAssertEqual(KeyEventPolicy.spacePage(page: 2, lastPage: 2), 0)
        XCTAssertEqual(KeyEventPolicy.spacePage(page: 1, lastPage: 1), 0)
    }

    func testSpaceOnASinglePageIsNotPaging() {
        // nil means "fall through": in 聯想 that dismisses the suggestions and types a literal
        // space; with candidates up it commits the first candidate.
        XCTAssertNil(KeyEventPolicy.spacePage(page: 0, lastPage: 0))
    }

    // MARK: associationSuffix — insert only the continuation

    func testSuffixDropsTheAlreadyCommittedFirstCharacter() {
        // 好 is already in the document; picking "好像" must insert only "像".
        XCTAssertEqual(KeyEventPolicy.associationSuffix("好像"), "像")
        XCTAssertEqual(KeyEventPolicy.associationSuffix("關係"), "係")
        XCTAssertEqual(KeyEventPolicy.associationSuffix("中華民國"), "華民國")
    }

    func testSingleCharacterAssociationHasNothingToInsert() {
        // The caller checks for empty and inserts nothing rather than an empty string.
        XCTAssertEqual(KeyEventPolicy.associationSuffix("好"), "")
        XCTAssertEqual(KeyEventPolicy.associationSuffix(""), "")
    }
}
