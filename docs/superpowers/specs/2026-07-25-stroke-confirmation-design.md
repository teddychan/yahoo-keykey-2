# Space-to-confirm the code in 速成 / 倉頡-with-wildcard

**Date:** 2026-07-25
**Issue:** [#61](https://github.com/teddychan/yahoo-keykey-2/issues/61)
**Status:** Implemented

## Problem

In 倉頡 the classic typing flow is *type the radicals → press Space → the character
is committed*. KeyKey matches that today: `H` `Q` `I` `Space` commits the first
candidate, because a plain 倉頡 code is looked up **exactly**, so it usually
resolves to a single page of candidates and Space falls through to
"commit the first candidate".

Two input styles break that flow:

- **速成 (Simplex)** — the code is a first+last-radical shorthand, so it matches
  many characters.
- **倉頡 with the `*` wildcard** — `characters(matching:)` expands the wildcard
  across the whole table.

Both resolve to **multiple pages** of candidates *before* the user has finished
describing the character. `InputController.handle(_:client:)` pages on Space
whenever `lastPage > 0`, so the Space pressed out of muscle memory flips to
**page 2** instead of confirming the code. The user must instead type
`H` `*` `I` `1` — dropping the Space from the sequence entirely, which is what
breaks the muscle memory the issue describes.

## Goal

An opt-in setting: when on, an auto-completed composition needs **one Space to
confirm the code** before Space resumes its normal meaning. The reported flow
`H` `*` `I` `Space` `1` then works.

Off by default, so existing users see no change.

## Non-goals

- **No change to plain 倉頡.** Its code is determinate; Space already means
  "confirm + commit" there.
- **No change to 拼音.** It owns its own key handling (`PhraseComposingEngine`)
  and Space already commits the whole buffer.
- **No change to digit selection.** `1`–`9` keep picking a candidate whether or
  not the code has been confirmed — the option adds a Space step, it does not
  take the direct pick away.
- **No new candidate-window chrome.** Confirming is silent: the marked text and
  the current page are untouched.

## Design

### Behaviour

With the option ON and an auto-completed composition showing candidates:

| Key | Result |
| --- | --- |
| 1st Space | Confirms the code. Page and marked text unchanged; the key is swallowed. |
| 2nd Space | Exactly today's behaviour — pages (wrapping last → first), or commits the first candidate when there is only one page. |
| `1`–`9` | Picks that candidate, confirmed or not. |
| Arrows / Page Up / Page Down | Page, confirmed or not. |

The confirmation is **per composition**: any change to the composition (a new
radical, Backspace, Esc, commit, an engine/table swap) requires it again.

### 1. Setting — `App/Preferences.swift`

A plain Bool alongside the existing toggles:

```swift
static var strokeConfirmationEnabled: Bool   // key "strokeConfirmationEnabled", default false
```

Registered `false` in `registerDefaults()` so a fresh install and an existing
install both start with today's behaviour.

### 2. Decision — `App/KeyEventPolicy.swift`

The rule lives in the existing pure-policy enum so it is unit-testable without
IMK:

```swift
static func spaceConfirmsStroke(enabled: Bool, autoCompletedCode: Bool,
                                alreadyConfirmed: Bool) -> Bool
```

Callers apply it only while candidates are on screen — with none there is no
page to flip and no character to pick, so Space keeps its existing
commit / pass-through meaning.

### 3. Wiring — `App/InputController.swift`

- `strokeConfirmed: Bool` — per-composition state, sitting next to `candidatePage`.
- `resetCompositionState()` — resets `candidatePage` **and** `strokeConfirmed`.
  It replaces the bare `candidatePage = 0` at every site where the composition
  itself changes (new radical, Backspace, Esc, commit, 倉頡版本 change, input-mode
  switch, wildcard start). Paging sites keep assigning `candidatePage`
  directly, so flipping pages does not drop the confirmation.
- `isAutoCompletedComposition` — `engine is SimplexEngine ||
  engine.composingText.contains("*")`. `*` has no radical glyph, so
  `composingText` renders it literally and the wildcard is visible there.
- The new Space branch sits inside the existing `!engine.candidates.isEmpty`
  block, **after** the arrow-key paging switch and **before** the Space-paging
  check, so it intercepts only the case that regressed.

### 4. UI — `App/GeneralPane.swift`, `App/SettingsModel.swift`, `Localizable.strings`

A toggle in the existing **輸入方式 / Input Method** section (with the 倉頡版本
picker, since this is 倉頡/速成 typing behaviour rather than a global input
option), bound to a computed `SettingsModel.strokeConfirmation` forwarder — a
plain Toggle does not need the stored-property treatment the Picker/Slider do.

- `keykey.general.strokeConfirmation` — 以空白鍵確認字根 / "Press Space to confirm the code"
- `keykey.general.strokeConfirmationHint` — explains the 速成/`*` scope and that
  plain 倉頡 is unaffected.

Not added to the IMK input menu; like the 聯想選字鍵 picker (#52) it stays in 設定….

## Tests

- `KeyEventPolicyTests` — truth table for `spaceConfirmsStroke`: first Space
  confirms, second does not, plain 倉頡 never does, and the disabled default
  never does.
- `PreferencesTests` — round-trip, absent-key default (`false`), and inclusion in
  `registerDefaults()`.

`InputController` itself is IMK-bound and outside the SwiftPM test package, so
the key-routing change is covered through the policy function it consults —
the same approach used for issue #56.
