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

    // MARK: spaceConfirmsStroke (issue #61)

    func testFirstSpaceConfirmsAnAutoCompletedCodeWhenEnabled() {
        // 速成 / 倉頡-with-`*`, option on, not yet confirmed: Space is the stroke confirmation.
        XCTAssertTrue(KeyEventPolicy.spaceConfirmsStroke(enabled: true, autoCompletedCode: true,
                                                        alreadyConfirmed: false))
    }

    func testSecondSpaceDoesNotConfirmAgain() {
        // Once confirmed, Space goes back to paging / committing for the rest of the composition.
        XCTAssertFalse(KeyEventPolicy.spaceConfirmsStroke(enabled: true, autoCompletedCode: true,
                                                         alreadyConfirmed: true))
    }

    func testPlainCangjieNeverNeedsConfirmation() {
        // A determinate 倉頡 code already treats Space as "confirm + commit"; nothing to change.
        XCTAssertFalse(KeyEventPolicy.spaceConfirmsStroke(enabled: true, autoCompletedCode: false,
                                                         alreadyConfirmed: false))
    }

    func testDisabledOptionLeavesSpaceUntouched() {
        // Default (off): existing users keep today's paging behaviour in every case.
        XCTAssertFalse(KeyEventPolicy.spaceConfirmsStroke(enabled: false, autoCompletedCode: true,
                                                         alreadyConfirmed: false))
        XCTAssertFalse(KeyEventPolicy.spaceConfirmsStroke(enabled: false, autoCompletedCode: false,
                                                         alreadyConfirmed: false))
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
