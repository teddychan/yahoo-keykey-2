import XCTest
import AppKit
@testable import KeyKeyApp

// Locks issue #56: ⌘/⌃ combinations (⌘C copy, ⌘X cut, ⌘V paste, ⌃A …) are app/system
// shortcuts, never IME input. InputController.handle() must let the app process them instead
// of feeding the base letter to the engine (which would turn ⌘C into the radical "c" / 金 and
// swallow the copy). KeyEventPolicy is the pure decision it consults.
final class KeyEventPolicyTests: XCTestCase {
    func testCommandCombinationsAreSystemShortcuts() {
        XCTAssertTrue(KeyEventPolicy.isSystemShortcut([.command]))                 // ⌘C / ⌘X / ⌘V
        XCTAssertTrue(KeyEventPolicy.isSystemShortcut([.command, .shift]))         // ⌘⇧S
        XCTAssertTrue(KeyEventPolicy.isSystemShortcut([.command, .option]))        // ⌘⌥…
    }

    func testControlCombinationsAreSystemShortcuts() {
        XCTAssertTrue(KeyEventPolicy.isSystemShortcut([.control]))                 // ⌃A / ⌃E …
        XCTAssertTrue(KeyEventPolicy.isSystemShortcut([.control, .command]))
    }

    func testImeRelevantModifiersAreNotSystemShortcuts() {
        // ⇧+letter (臨時英數) and plain/⌥ typing stay with the IME.
        XCTAssertFalse(KeyEventPolicy.isSystemShortcut([]))
        XCTAssertFalse(KeyEventPolicy.isSystemShortcut([.shift]))
        XCTAssertFalse(KeyEventPolicy.isSystemShortcut([.capsLock]))
        XCTAssertFalse(KeyEventPolicy.isSystemShortcut([.option]))
        XCTAssertFalse(KeyEventPolicy.isSystemShortcut([.shift, .capsLock]))
    }
}
