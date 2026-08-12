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

    // MARK: - AdaptiveCandidateOrder (issue #85)

    func testBonusIsTheLearnedValueWhenEnabled() {
        XCTAssertEqual(AdaptiveCandidateOrder.bonus(for: "漏", enabled: true,
                                                    learned: { $0 == "漏" ? 7 : 0 }), 7)
    }

    func testBonusIsZeroWhenDisabled() {
        // Zero is the whole mechanism: every consumer adds this to a static score, so zero leaves
        // the Cangjie/Simplex sorts, the Pinyin walker and the 聯想 sort on that score alone.
        XCTAssertEqual(AdaptiveCandidateOrder.bonus(for: "漏", enabled: false,
                                                    learned: { _ in 999 }), 0)
    }

    func testSingleCharacterCommitIsLearnedWhenEnabled() {
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "漏", enabled: true), "漏")
    }

    func testNothingIsLearnedFromACommitWhenDisabled() {
        // The setting pauses learning as well as ignoring it — a user who turned it off is not
        // still being counted in the background.
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "漏", enabled: false))
    }

    func testMultiCharacterCommitIsNotLearned() {
        // UserFrequency counts characters, so a multi-character 拼音 commit has no single
        // character to attribute. Unchanged from the pre-toggle behaviour.
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "今天", enabled: true))
    }

    func testEmptyCommitIsNotLearned() {
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "", enabled: true))
    }

    func testAssociationPickLearnsTheContinuation() {
        // 關係 inserts the suffix 係, and 係 is what the user chose — the same character
        // AssociatedPhrases ranks the phrase by.
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係",
                                                               enabled: true), "係")
    }

    func testLongerAssociationLearnsOnlyTheFirstContinuation() {
        // No length condition here, unlike a composition commit: a three-character phrase still
        // turns on the one continuation character it adds first.
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係人",
                                                               enabled: true), "係")
    }

    func testNothingIsLearnedFromAnAssociationWhenDisabled() {
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係",
                                                             enabled: false))
    }

    func testEmptyAssociationSuffixLearnsNothing() {
        // A one-character "phrase" inserts nothing, so there is nothing to attribute.
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "", enabled: true))
    }
}
