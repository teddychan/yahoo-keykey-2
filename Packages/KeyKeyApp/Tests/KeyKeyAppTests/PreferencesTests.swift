import XCTest
@testable import KeyKeyApp

// Covers Preferences (typed UserDefaults accessors + clamping) and the CangjieVersion enum.
// Each test writes explicit values into UserDefaults.standard (the domain Preferences reads),
// so ordering between tests does not matter.
final class PreferencesTests: XCTestCase {
    private let defaults = UserDefaults.standard

    override func tearDown() {
        for key in ["candidateFontSize", "associatedPhrasesEnabled", "fullWidthPunctuationEnabled",
                    "outputSimplifiedEnabled", "cangjieVersion", "associationContinuationOnly",
                    "codeHintEnabled", "associationSelectionTrigger", "strokeConfirmationEnabled"] {
            defaults.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: candidateFontSize clamping

    func testFontSizeGetterClampsBelowMin() {
        defaults.set(5.0, forKey: "candidateFontSize")       // raw, below min
        XCTAssertEqual(Preferences.candidateFontSize, 14)    // clamped up to minFontSize
    }

    func testFontSizeGetterClampsAboveMax() {
        defaults.set(40.0, forKey: "candidateFontSize")      // raw, above max
        XCTAssertEqual(Preferences.candidateFontSize, 28)    // clamped down to maxFontSize
    }

    func testFontSizeGetterPreservesInRange() {
        defaults.set(20.0, forKey: "candidateFontSize")
        XCTAssertEqual(Preferences.candidateFontSize, 20)
    }

    func testFontSizeSetterClampsBothEnds() {
        Preferences.candidateFontSize = 100                  // setter clamps before storing
        XCTAssertEqual(defaults.double(forKey: "candidateFontSize"), 28)
        Preferences.candidateFontSize = 1
        XCTAssertEqual(defaults.double(forKey: "candidateFontSize"), 14)
    }

    func testFontSizeConstants() {
        XCTAssertEqual(Preferences.minFontSize, 14)
        XCTAssertEqual(Preferences.maxFontSize, 28)
        XCTAssertEqual(Preferences.defaultFontSize, 18)
    }

    // MARK: bool accessors round-trip

    func testBoolAccessorsRoundTrip() {
        Preferences.associatedPhrasesEnabled = true
        XCTAssertTrue(Preferences.associatedPhrasesEnabled)
        Preferences.associatedPhrasesEnabled = false
        XCTAssertFalse(Preferences.associatedPhrasesEnabled)

        Preferences.fullWidthPunctuationEnabled = true
        XCTAssertTrue(Preferences.fullWidthPunctuationEnabled)
        Preferences.fullWidthPunctuationEnabled = false
        XCTAssertFalse(Preferences.fullWidthPunctuationEnabled)

        Preferences.outputSimplifiedEnabled = true
        XCTAssertTrue(Preferences.outputSimplifiedEnabled)
        Preferences.outputSimplifiedEnabled = false
        XCTAssertFalse(Preferences.outputSimplifiedEnabled)

        Preferences.associationContinuationOnly = true
        XCTAssertTrue(Preferences.associationContinuationOnly)
        Preferences.associationContinuationOnly = false
        XCTAssertFalse(Preferences.associationContinuationOnly)

        Preferences.codeHintEnabled = true
        XCTAssertTrue(Preferences.codeHintEnabled)
        Preferences.codeHintEnabled = false
        XCTAssertFalse(Preferences.codeHintEnabled)

        Preferences.strokeConfirmationEnabled = true
        XCTAssertTrue(Preferences.strokeConfirmationEnabled)
        Preferences.strokeConfirmationEnabled = false
        XCTAssertFalse(Preferences.strokeConfirmationEnabled)
    }

    // Issue #61: absent (never set) must read false, so an existing install keeps today's
    // Space behaviour until the user opts in.
    func testStrokeConfirmationDefaultsOffWhenAbsent() {
        defaults.removeObject(forKey: "strokeConfirmationEnabled")
        XCTAssertFalse(Preferences.strokeConfirmationEnabled)
    }

    // MARK: cangjieVersion

    func testCangjieVersionRoundTrip() {
        Preferences.cangjieVersion = .v3
        XCTAssertEqual(Preferences.cangjieVersion, .v3)
        Preferences.cangjieVersion = .v5
        XCTAssertEqual(Preferences.cangjieVersion, .v5)
    }

    func testCangjieVersionUnknownRawFallsBackToV5() {
        defaults.set("99", forKey: "cangjieVersion")         // not a valid case
        XCTAssertEqual(Preferences.cangjieVersion, .v5)
    }

    func testCangjieVersionAbsentFallsBackToV5() {
        defaults.removeObject(forKey: "cangjieVersion")
        XCTAssertEqual(Preferences.cangjieVersion, .v5)
    }

    // MARK: associationSelectionTrigger

    func testAssociationTriggerRoundTrip() {
        Preferences.associationSelectionTrigger = .shift
        XCTAssertEqual(Preferences.associationSelectionTrigger, .shift)
        Preferences.associationSelectionTrigger = .number
        XCTAssertEqual(Preferences.associationSelectionTrigger, .number)
    }

    func testAssociationTriggerUnknownRawFallsBackToNumber() {
        defaults.set("zzz", forKey: "associationSelectionTrigger")   // not a valid case
        XCTAssertEqual(Preferences.associationSelectionTrigger, .number)
    }

    func testAssociationTriggerAbsentFallsBackToNumber() {
        defaults.removeObject(forKey: "associationSelectionTrigger")
        XCTAssertEqual(Preferences.associationSelectionTrigger, .number)
    }

    func testAssociationTriggerRawValues() {
        XCTAssertEqual(AssociationTrigger.number.rawValue, "number")
        XCTAssertEqual(AssociationTrigger.shift.rawValue, "shift")
    }

    func testAssociationTriggerInitFromRawValue() {
        XCTAssertEqual(AssociationTrigger(rawValue: "number"), .number)
        XCTAssertEqual(AssociationTrigger(rawValue: "shift"), .shift)
        XCTAssertNil(AssociationTrigger(rawValue: "x"))
    }

    // MARK: registerDefaults

    func testRegisterDefaultsSuppliesSensibleFirstLaunchValues() {
        for key in ["candidateFontSize", "associatedPhrasesEnabled", "fullWidthPunctuationEnabled",
                    "outputSimplifiedEnabled", "cangjieVersion", "associationContinuationOnly",
                    "codeHintEnabled", "associationSelectionTrigger", "strokeConfirmationEnabled"] {
            defaults.removeObject(forKey: key)
        }
        Preferences.registerDefaults()
        XCTAssertTrue(Preferences.associatedPhrasesEnabled)
        XCTAssertTrue(Preferences.fullWidthPunctuationEnabled)
        XCTAssertFalse(Preferences.outputSimplifiedEnabled)
        XCTAssertFalse(Preferences.associationContinuationOnly)
        XCTAssertFalse(Preferences.codeHintEnabled)
        XCTAssertFalse(Preferences.strokeConfirmationEnabled)
        XCTAssertEqual(Preferences.cangjieVersion, .v5)
        XCTAssertEqual(Preferences.associationSelectionTrigger, .number)
        XCTAssertEqual(Preferences.candidateFontSize, 18)    // defaultFontSize
    }

    // MARK: CangjieVersion enum

    func testCangjieVersionRawValues() {
        XCTAssertEqual(CangjieVersion.v5.rawValue, "5")
        XCTAssertEqual(CangjieVersion.v3.rawValue, "3")
    }

    func testCangjieVersionInitFromRawValue() {
        XCTAssertEqual(CangjieVersion(rawValue: "5"), .v5)
        XCTAssertEqual(CangjieVersion(rawValue: "3"), .v3)
        XCTAssertNil(CangjieVersion(rawValue: "x"))
    }
}
