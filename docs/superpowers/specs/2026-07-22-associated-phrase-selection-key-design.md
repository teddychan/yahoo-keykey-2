# Configurable associated-phrase selection key

**Date:** 2026-07-22
**Issue:** [#52](https://github.com/teddychan/yahoo-keykey-2/issues/52)
**Status:** Approved design

## Problem

After committing a single character, KeyKey offers 聯想 (associated phrases) in
the numbered candidate window. Currently a plain number key `1`–`9` selects an
associated phrase directly. This makes it awkward to type digits immediately
after a Chinese character — e.g. `這周有7天。` — because the `7` is captured by
the association picker instead of being typed. It also diverges from the common
practice of other Chinese IMEs.

## Goal

Let the user choose which key selects an associated phrase:

- **Number key** (default) — plain `1`–`9` picks. Today's behavior, unchanged.
- **Shift + Number** — `Shift`+`1`–`9` picks; a plain `1`–`9` dismisses the
  suggestions and types the literal digit, so numbers flow naturally after a
  character.

The default preserves existing behavior for current users.

## Non-goals

- No change to regular Cangjie / Simplex / Pinyin candidate selection — those
  keep plain-digit selection. This affects **association mode only**.
- No additional trigger options (Control / Option). Only Number and Shift+Number.

## Design

### 1. Setting model — `App/Preferences.swift`

Add a string-backed enum mirroring the existing `CangjieVersion`:

```swift
enum AssociationTrigger: String {
    case number = "number"   // default — plain 1–9 picks
    case shift  = "shift"    // Shift+1–9 picks; plain 1–9 types the digit
}
```

Add:
- A `Key.associationSelectionTrigger` constant (`"associationSelectionTrigger"`).
- A registered default of `AssociationTrigger.number.rawValue`.
- A typed accessor `associationSelectionTrigger` following the `cangjieVersion`
  pattern: unknown/absent value falls back to `.number`.

### 2. Settings UI — `App/SettingsModel.swift`, `App/GeneralPane.swift`, `*/Localizable.strings`

- `SettingsModel`: a **stored**, observation-tracked property
  `associationTrigger`, seeded from `Preferences.associationSelectionTrigger`,
  with a `didSet` that writes through to `Preferences` (same shape as
  `cangjieVersion`, so a menu-style `Picker` selection sticks instead of
  silently reverting). No table reload — `InputController` reads `Preferences`
  live on the next composition.
- `GeneralPane`: a `Picker` placed directly under the associated-phrase toggles,
  with two tags — "Number key" (`.number`) and "Shift + Number" (`.shift`) —
  plus a one-line `.dragonAnnotation` hint.
- Localization: add `keykey.general.associationTrigger`,
  `keykey.general.associationTriggerNumber`,
  `keykey.general.associationTriggerShift`, and
  `keykey.general.associationTriggerHint` to both `App/en.lproj` and
  `App/zh-Hant.lproj` `Localizable.strings`.

### 3. Engine behavior — `App/InputController.swift`

The change is confined to the association-mode digit branch (currently around
line 280, inside `if !associations.isEmpty { … }`).

Replace the single `Int(event.characters)` check with a trigger-aware resolution
of which digit (if any) selects a phrase:

- `.number` mode: **unchanged** — a plain digit read from `event.characters`
  picks; `Shift`+digit yields a symbol (not an `Int`), so it falls through to
  the existing "any other key: dismiss" path exactly as today.
- `.shift` mode: only `Shift`+digit (with no `⌃`/`⌥`/`⌘`), matched by physical
  key code, picks. (`charactersIgnoringModifiers` still applies Shift, so
  `Shift`+`7` reads as `"&"`, not `"7"` — the digit must come from the key code,
  matching the Space/arrow key-code handling already in this block.) A plain
  digit is **not** a pick, so control falls through to `clearAssociations()` and
  then normal handling; the idle engine rejects the digit and `handle()` returns
  `false`, so the app types the literal number.

The phrase-insertion body is unchanged and shared by both modes: index into the
current page, insert only the continuation after the just-committed character
(`dropFirst`), then clear associations.

Notes that make this safe:
- The 臨時英數 block at the top of `handle()` intercepts only `Shift`+**letter**
  (`raw.isLetter`), so `Shift`+digit reaches the association branch untouched.
- Space paging, arrow paging, and Escape (handled before the digit branch) are
  unaffected in both modes.

### 4. Tests — `Packages/KeyKeyApp/Tests/KeyKeyAppTests/PreferencesTests.swift`

Add a round-trip + default test for `associationSelectionTrigger`, matching the
existing `PreferencesTests` style: assert the registered default is `.number`,
and that setting `.shift` persists and reads back. Also:
- Add `"associationSelectionTrigger"` to the per-test key-reset list in `setUp`.
- Add the new key to the assertions in
  `testRegisterDefaultsSuppliesSensibleFirstLaunchValues`.

`InputController` is IMKit-bound and has no unit-test harness today; no
InputController test is added (consistent with the current suite).

## Files touched

- `App/Preferences.swift` — enum + key + default + accessor
- `App/SettingsModel.swift` — stored `associationTrigger` property
- `App/GeneralPane.swift` — `Picker`
- `App/en.lproj/Localizable.strings` — strings
- `App/zh-Hant.lproj/Localizable.strings` — strings
- `App/InputController.swift` — trigger-aware association selection
- `Packages/KeyKeyApp/Tests/KeyKeyAppTests/PreferencesTests.swift` — test

## Verification

- Default install: association picking still uses plain `1`–`9`.
- Switch to "Shift + Number": typing a character, then `7`, types `7` and
  dismisses the suggestions; `Shift`+`2` picks the 2nd suggestion.
- `這周有7天。` types cleanly in Shift+Number mode.
- Regular Cangjie/Simplex/Pinyin candidate selection with plain digits is
  unchanged in both modes.
- `PreferencesTests` pass.
