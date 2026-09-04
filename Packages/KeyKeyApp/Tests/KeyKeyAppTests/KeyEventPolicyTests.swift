import XCTest
import AppKit
import KeyKeyEngine
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

    // MARK: - AdaptiveCandidateOrder (issues #85, #130)

    private static let cangjieA = CandidateListKey.cangjie(tableVersion: "5", code: "a")

    func testCountIsTheStoredCountWhenEnabled() {
        XCTAssertEqual(AdaptiveCandidateOrder.count(of: "漏", in: Self.cangjieA, enabled: true,
                                                    stored: { c, _ in c == "漏" ? 7 : 0 }), 7)
    }

    func testCountIsAskedForTheGivenCandidateAndList() {
        // The gate must pass BOTH through untouched, or a count could be read from the wrong list.
        var seen: (String, CandidateListKey)?
        _ = AdaptiveCandidateOrder.count(of: "漏", in: Self.cangjieA, enabled: true,
                                         stored: { c, l in seen = (c, l); return 0 })
        XCTAssertEqual(seen?.0, "漏")
        XCTAssertEqual(seen?.1, Self.cangjieA)
    }

    func testCountIsZeroWhenDisabled() {
        // Zero is the whole mechanism: every consumer sorts on this count first and falls back to
        // the built-in order, so zero leaves the 倉頡/速成 sorts, the 拼音 walker's node
        // candidates and the 聯想 sort with exactly the order they had before any learning.
        XCTAssertEqual(AdaptiveCandidateOrder.count(of: "漏", in: Self.cangjieA, enabled: false,
                                                    stored: { _, _ in 999 }), 0)
    }

    func testStoredCountsAreNotEvenConsultedWhenDisabled() {
        // "Ignore existing usage counts" — the store is not read at all, so a user who turned the
        // setting off cannot see a list reordered by counts already on disk.
        var consulted = false
        _ = AdaptiveCandidateOrder.count(of: "漏", in: Self.cangjieA, enabled: false,
                                         stored: { _, _ in consulted = true; return 5 })
        XCTAssertFalse(consulted)
    }

    // MARK: usage recorded by a composition commit

    func testCommitUsageIsRecordedWhenEnabled() {
        let pending = [CandidateUsage(list: Self.cangjieA, candidate: "漏")]
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(pending, enabled: true), pending)
    }

    func testNothingIsRecordedFromACommitWhenDisabled() {
        // The setting pauses counting as well as ignoring counts — a user who turned it off is
        // not still being counted in the background.
        let pending = [CandidateUsage(list: Self.cangjieA, candidate: "漏")]
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(pending, enabled: false), [])
    }

    func testAnEmptyPendingUsageRecordsNothing() {
        // What an engine reports for a list with nothing to reorder, and for a commit made after
        // the engine has already reset.
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord([], enabled: true), [])
    }

    func testEveryPendingRecordIsKept() {
        // The gate passes the engine's whole report through, whatever it contains.
        let pending = [
            CandidateUsage(list: .simplex(tableVersion: "5", code: "a"), candidate: "曰"),
            CandidateUsage(list: .cangjieWildcard(tableVersion: "5", pattern: "h*i"), candidate: "龍"),
        ]
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(pending, enabled: true), pending)
    }

    // MARK: usage recorded by a 聯想 pick

    func testAssociationPickRecordsTheWholePhrase() {
        // 關係 inserts only the suffix 係, and a continuation-only display shows only 係 — but the
        // candidate the user picked is the phrase, so the phrase is what is counted.
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "關係", enabled: true),
                       [CandidateUsage(list: .association(trigger: "關"), candidate: "關係")])
    }

    func testAssociationKeyIsTheTriggerAloneSoModesShareOneList() {
        // 倉頡 and 速成 show the same list after the same character, so the record must be keyed
        // by the trigger and nothing else. The function takes ONLY the phrase — there is no mode
        // or code argument it could fold in — and the trigger it derives is the phrase's first
        // character, exactly how AssociatedPhrases buckets its lists. So a pick made after
        // entering 關 through either mode produces this one same record.
        let recorded = AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "關係", enabled: true)
        XCTAssertEqual(recorded.first?.list, .association(trigger: "關"))
        XCTAssertNotEqual(recorded.first?.list, .cangjie(tableVersion: "5", code: "a"))
        XCTAssertNotEqual(recorded.first?.list, .simplex(tableVersion: "5", code: "a"))
    }

    func testALongerAssociationPhraseIsCountedWhole() {
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "關係人", enabled: true),
                       [CandidateUsage(list: .association(trigger: "關"), candidate: "關係人")])
    }

    func testNothingIsRecordedFromAnAssociationWhenDisabled() {
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "關係", enabled: false), [])
    }

    func testAnEmptyOrSingleCharacterAssociationRecordsNothing() {
        // A one-character "phrase" inserts nothing and is not an association candidate.
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "", enabled: true), [])
        XCTAssertEqual(AdaptiveCandidateOrder.usageToRecord(forAssociationPhrase: "關", enabled: true), [])
    }

    // MARK: 拼音 — the per-character mechanism, out of scope for the per-list change

    func testBonusIsTheLearnedValueWhenEnabled() {
        XCTAssertEqual(AdaptiveCandidateOrder.bonus(for: "漏", enabled: true,
                                                    learned: { $0 == "漏" ? 7 : 0 }), 7)
    }

    func testBonusIsZeroWhenDisabled() {
        // The same setting gates both mechanisms, so 拼音 is paused by the toggle too.
        XCTAssertEqual(AdaptiveCandidateOrder.bonus(for: "漏", enabled: false,
                                                    learned: { _ in 999 }), 0)
    }

    func testSingleCharacterCommitIsStillLearnedPerCharacter() {
        // 拼音 ranks by this, and on the previous release every mode's single-character commits
        // fed it. That is kept, so 拼音's learning neither resets nor stops.
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "漏", enabled: true), "漏")
    }

    func testNothingIsLearnedPerCharacterWhenDisabled() {
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "漏", enabled: false))
    }

    func testMultiCharacterCommitIsNotLearnedPerCharacter() {
        // UserFrequency counts characters, so a multi-character 拼音 commit has no single
        // character to attribute. Unchanged.
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "今天", enabled: true))
    }

    func testEmptyCommitIsNotLearnedPerCharacter() {
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromCommitted: "", enabled: true))
    }

    func testAssociationPickStillLearnsTheContinuationPerCharacter() {
        // No longer what orders the 聯想 list — the phrase count does — but still what feeds 拼音.
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係",
                                                               enabled: true), "係")
        XCTAssertEqual(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係人",
                                                               enabled: true), "係")
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "係",
                                                             enabled: false))
        XCTAssertNil(AdaptiveCandidateOrder.characterToLearn(fromAssociationSuffix: "", enabled: true))
    }

    // Merely showing or dismissing a 聯想 list must count nothing. Reading counts to ORDER a list
    // goes through `count(of:in:enabled:stored:)`, which takes a read-only `stored` closure and
    // therefore cannot record: showing a list is a pure read. Recording needs
    // `usageToRecord(forAssociationPhrase:enabled:)`, and the only place InputController calls it
    // is the digit-selection branch that commits a suggestion — `clearAssociations()`, Esc and
    // the any-other-key dismissal have nothing to call.
    func testOrderingAListIsAPureReadThatCannotRecord() {
        var reads = 0
        let count = AdaptiveCandidateOrder.count(of: "關係", in: .association(trigger: "關"),
                                                 enabled: true,
                                                 stored: { _, _ in reads += 1; return 3 })
        XCTAssertEqual(count, 3)
        XCTAssertEqual(reads, 1, "displaying a list reads its counts once and writes nothing")
    }
}
