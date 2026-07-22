# Associated-Phrase Selection Key Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user setting that chooses whether a plain number key or Shift+number selects an associated phrase (聯想), so digits can be typed smoothly after a Chinese character (issue #52).

**Architecture:** A new string-backed `AssociationTrigger` enum + `Preferences` accessor (mirroring the existing `CangjieVersion` pattern), surfaced as a two-option `Picker` in the General settings pane via a stored `SettingsModel` property, and read live by `InputController` in the association-mode digit branch.

**Tech Stack:** Swift, SwiftUI (DragonKit settings), IMKit, XCTest. App built headlessly with `tools/build-app.sh`; package tests via `swift test`.

## Global Constraints

- Default MUST be `.number` (plain 1–9 picks) — existing users see no behavior change.
- Do NOT introduce a new UserDefaults suite; use the same `UserDefaults.standard` domain the other `Preferences` keys use.
- Only two trigger options: Number and Shift+Number. No Control/Option.
- Change is confined to association mode; regular Cangjie/Simplex/Pinyin candidate selection is untouched.
- User-facing strings must be added to BOTH `App/en.lproj` and `App/zh-Hant.lproj` `Localizable.strings`.

---

### Task 1: `AssociationTrigger` preference (enum, default, accessor) + tests

**Files:**
- Modify: `App/Preferences.swift`
- Test: `Packages/KeyKeyApp/Tests/KeyKeyAppTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum AssociationTrigger: String { case number = "number"; case shift = "shift" }`
  - `static var Preferences.associationSelectionTrigger: AssociationTrigger { get set }`
  - Registered default `associationSelectionTrigger` = `"number"`.

- [ ] **Step 1: Write the failing tests**

Add the new key to the `tearDown` reset list in `Packages/KeyKeyApp/Tests/KeyKeyAppTests/PreferencesTests.swift` (both occurrences — `tearDown` at the top and the reset loop inside `testRegisterDefaultsSuppliesSensibleFirstLaunchValues`). Change each list from:

```swift
        for key in ["candidateFontSize", "associatedPhrasesEnabled", "fullWidthPunctuationEnabled",
                    "outputSimplifiedEnabled", "cangjieVersion", "associationContinuationOnly",
                    "codeHintEnabled"] {
```

to:

```swift
        for key in ["candidateFontSize", "associatedPhrasesEnabled", "fullWidthPunctuationEnabled",
                    "outputSimplifiedEnabled", "cangjieVersion", "associationContinuationOnly",
                    "codeHintEnabled", "associationSelectionTrigger"] {
```

Add this assertion inside `testRegisterDefaultsSuppliesSensibleFirstLaunchValues`, right after the `cangjieVersion` assertion:

```swift
        XCTAssertEqual(Preferences.associationSelectionTrigger, .number)
```

Add these new test methods (place them after `testCangjieVersionAbsentFallsBackToV5`):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/KeyKeyApp --filter PreferencesTests`
Expected: FAIL to compile with errors like "cannot find 'AssociationTrigger' in scope" / "value of type 'Preferences' has no member 'associationSelectionTrigger'".

- [ ] **Step 3: Add the enum**

In `App/Preferences.swift`, add this enum immediately after the `CangjieVersion` enum (before `enum Preferences {`):

```swift
// Which key selects an associated phrase (聯想) in the numbered candidate window.
// `.number` keeps the classic direct 1–9 pick; `.shift` requires Shift+1–9 so a bare
// 1–9 types the digit instead — smoother when mixing numbers with Chinese (issue #52).
enum AssociationTrigger: String {
    case number = "number"   // default — plain 1–9 picks
    case shift  = "shift"    // Shift+1–9 picks; plain 1–9 types the digit
}
```

- [ ] **Step 4: Add the key, default, and accessor**

In `App/Preferences.swift`, add the key constant to the `private enum Key` block, after `codeHintEnabled`:

```swift
        static let associationSelectionTrigger = "associationSelectionTrigger"
```

Add the registered default inside `registerDefaults()`'s dictionary, after the `codeHintEnabled` entry:

```swift
            Key.associationSelectionTrigger: AssociationTrigger.number.rawValue,
```

Add the typed accessor after the `codeHintEnabled` computed property (end of the `Preferences` enum):

```swift
    // Which key selects an associated phrase; unknown/absent falls back to plain number keys.
    static var associationSelectionTrigger: AssociationTrigger {
        get { AssociationTrigger(rawValue: UserDefaults.standard.string(forKey: Key.associationSelectionTrigger) ?? "") ?? .number }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.associationSelectionTrigger) }
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path Packages/KeyKeyApp --filter PreferencesTests`
Expected: PASS (all PreferencesTests green, including the 5 new tests and the updated registerDefaults test).

- [ ] **Step 6: Commit**

```bash
git add App/Preferences.swift Packages/KeyKeyApp/Tests/KeyKeyAppTests/PreferencesTests.swift
git commit -m "feat: add AssociationTrigger preference (#52)"
```

---

### Task 2: Settings UI — SettingsModel property, Picker, localized strings

**Files:**
- Modify: `App/SettingsModel.swift`
- Modify: `App/GeneralPane.swift`
- Modify: `App/en.lproj/Localizable.strings`
- Modify: `App/zh-Hant.lproj/Localizable.strings`

**Interfaces:**
- Consumes: `AssociationTrigger`, `Preferences.associationSelectionTrigger` (Task 1).
- Produces: `SettingsModel.associationTrigger: AssociationTrigger` (stored, writes through to `Preferences`); a `Picker` bound to it in the General pane.

- [ ] **Step 1: Add the stored property to SettingsModel**

In `App/SettingsModel.swift`, add this property immediately after the `cangjieVersion` stored property (after its closing `}` around line 75):

```swift
    // 聯想選字鍵 (issue #52). Stored + observation-tracked like `cangjieVersion` above so the
    // menu-style Picker selection sticks (a computed forwarder would silently revert). `didSet`
    // writes through to Preferences, which InputController reads live on the next composition.
    var associationTrigger: AssociationTrigger = Preferences.associationSelectionTrigger {
        didSet {
            guard associationTrigger != oldValue else { return }
            Preferences.associationSelectionTrigger = associationTrigger
        }
    }
```

- [ ] **Step 2: Add the Picker to the General pane**

In `App/GeneralPane.swift`, inside the first `DragonSection` (`keykey.general.input`), insert the Picker between the `associationContinuationOnly` Toggle (with its `.dragonAnnotation`) and the `codeHint` Toggle:

```swift
                Toggle(L("keykey.general.associationContinuationOnly"), isOn: $model.associationContinuationOnly)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.associationContinuationOnlyHint")))
                Picker(L("keykey.general.associationTrigger"), selection: $model.associationTrigger) {
                    Text(L("keykey.general.associationTriggerNumber")).tag(AssociationTrigger.number)
                    Text(L("keykey.general.associationTriggerShift")).tag(AssociationTrigger.shift)
                }
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.associationTriggerHint")))
                Toggle(L("keykey.general.codeHint"), isOn: $model.codeHint)
```

- [ ] **Step 3: Add English strings**

In `App/en.lproj/Localizable.strings`, add these lines after the `keykey.general.associationContinuationOnlyHint` line:

```
"keykey.general.associationTrigger" = "Associated-phrase selection key";
"keykey.general.associationTriggerNumber" = "Number key";
"keykey.general.associationTriggerShift" = "Shift + Number";
"keykey.general.associationTriggerHint" = "With “Shift + Number”, a plain number key types the digit instead of picking an associated phrase — handy for typing numbers right after a character (e.g. 這周有7天).";
```

- [ ] **Step 4: Add Traditional Chinese strings**

In `App/zh-Hant.lproj/Localizable.strings`, add these lines after the `keykey.general.associationContinuationOnlyHint` line:

```
"keykey.general.associationTrigger" = "聯想選字鍵";
"keykey.general.associationTriggerNumber" = "數字鍵";
"keykey.general.associationTriggerShift" = "Shift + 數字";
"keykey.general.associationTriggerHint" = "選「Shift + 數字」時，直接按數字鍵會輸入該數字，而不會選取聯想詞，方便在字後接著打數字（例如「這周有7天」）。";
```

- [ ] **Step 5: Build the app to verify it compiles**

Run: `tools/build-app.sh`
Expected: builds successfully, ending with the produced `./build/YahooKeyKey2.app` (no swiftc errors). This is the only compile check for `SettingsModel.swift` / `GeneralPane.swift`, which are not part of the Swift package.

- [ ] **Step 6: Commit**

```bash
git add App/SettingsModel.swift App/GeneralPane.swift App/en.lproj/Localizable.strings App/zh-Hant.lproj/Localizable.strings
git commit -m "feat: add associated-phrase selection-key picker to settings (#52)"
```

---

### Task 3: Trigger-aware selection in InputController

**Files:**
- Modify: `App/InputController.swift` (association-mode digit branch, ~lines 280–297)

**Interfaces:**
- Consumes: `Preferences.associationSelectionTrigger`, `AssociationTrigger` (Task 1).
- Produces: no new symbols; changes runtime behavior of the association digit branch.

- [ ] **Step 1: Replace the digit-selection block**

In `App/InputController.swift`, inside `if !associations.isEmpty { … }`, replace this existing block:

```swift
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
                let index = candidatePage * InputController.pageSize + (d - 1)
                if index < count {
                    // Associations are full phrases that START with the just-committed
                    // character (already in the document), so insert only the remainder
                    // after it (好 + association "好像" -> insert "像", giving 好像).
                    let suffix = String(associations[index].dropFirst())
                    clearAssociations()
                    if !suffix.isEmpty {
                        client.insertText(applyHanConvert(suffix), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                    }
                    return true
                }
                return true // digit beyond this page: swallow, no insert
            }
            // Any other key: dismiss suggestions, then fall through to process the key normally.
            clearAssociations()
```

with:

```swift
            // Which digit (if any) selects an associated phrase depends on the configured
            // trigger (issue #52). In .number mode a plain 1–9 picks (Shift+digit yields a
            // symbol that Int() rejects, so it falls through and dismisses, as before). In
            // .shift mode only Shift+1–9 with no ⌃⌥⌘ picks — read from the base key, since
            // Shift+digit's `characters` is a symbol — and a bare digit is NOT a pick, so it
            // falls through, dismisses, and the idle engine lets the app type the number.
            let selectionDigit: Int? = {
                switch Preferences.associationSelectionTrigger {
                case .number:
                    if let chars = event.characters, let d = Int(chars), (1...9).contains(d) { return d }
                case .shift:
                    if event.modifierFlags.contains(.shift),
                       event.modifierFlags.intersection([.control, .option, .command]).isEmpty,
                       let base = event.charactersIgnoringModifiers, let d = Int(base), (1...9).contains(d) { return d }
                }
                return nil
            }()
            if let d = selectionDigit {
                let index = candidatePage * InputController.pageSize + (d - 1)
                if index < count {
                    // Associations are full phrases that START with the just-committed
                    // character (already in the document), so insert only the remainder
                    // after it (好 + association "好像" -> insert "像", giving 好像).
                    let suffix = String(associations[index].dropFirst())
                    clearAssociations()
                    if !suffix.isEmpty {
                        client.insertText(applyHanConvert(suffix), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                    }
                    return true
                }
                return true // digit beyond this page: swallow, no insert
            }
            // Any other key: dismiss suggestions, then fall through to process the key normally.
            clearAssociations()
```

- [ ] **Step 2: Build the app to verify it compiles**

Run: `tools/build-app.sh`
Expected: builds successfully, produces `./build/YahooKeyKey2.app` with no swiftc errors.

- [ ] **Step 3: Run the package test suites (regression guard)**

Run: `swift test --package-path Packages/KeyKeyApp && swift test --package-path Packages/KeyKeyEngine`
Expected: PASS (nothing regressed; Preferences tests still green).

- [ ] **Step 4: Manual verification (debug build)**

Run: `tools/run-debug.sh` then, in the input menu / General settings of "Yahoo KeyKey 2 Debug", verify:
- Default ("Number key"): type a character, then `1` → picks the 1st associated phrase (unchanged behavior). Shift+`1` → dismisses and inserts full-width symbol, as before.
- Switch to "Shift + Number": type a character, then `7` → the suggestions dismiss and `7` is typed literally. Shift+`2` → picks the 2nd associated phrase.
- Type `這周有7天。` end-to-end in "Shift + Number" mode → the `7` appears as a digit, not a phrase pick.
- Regular Cangjie/Simplex composition: plain `1`–`9` still selects candidates normally in both modes.

Expected: all four checks pass.

- [ ] **Step 5: Commit**

```bash
git add App/InputController.swift
git commit -m "feat: honor associated-phrase selection-key setting in InputController (#52)"
```

---

## Notes

- The 臨時英數 block at the top of `handle()` (`App/InputController.swift:241`) intercepts only Shift+**letter** (`raw.isLetter`), so Shift+digit reaches the association branch untouched — no conflict.
- No table reload is needed on change; `InputController` reads `Preferences.associationSelectionTrigger` live each keystroke.
- `CHANGELOG.md` / version bump are release-time concerns handled separately, per the repo's release flow — not part of this feature plan.
