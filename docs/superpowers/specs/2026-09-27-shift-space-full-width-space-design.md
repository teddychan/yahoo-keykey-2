# Shift + Space types a full-width space

**Date:** 2026-09-27
**Issue:** [#135](https://github.com/teddychan/yahoo-keykey-2/issues/135)
**Status:** Implemented (target version 2.14.0)

## Problem

Formal Traditional Chinese typesetting uses the full-width space `　` (U+3000 IDEOGRAPHIC
SPACE, one character wide) for paragraph indents and gaps. Yahoo! KeyKey 2 has no way to type
it: the user has to switch input source or paste it from elsewhere.

Shift + Space is free to take. Today it does exactly what plain Space does — no branch in
`InputController.handle(_:client:)` looks at Shift for key code 49 — so giving it a meaning
costs no existing shortcut.

## Goal

An opt-in setting, **設定… ▸ 一般 ▸ 輸入 ▸ Shift + 空白鍵輸入全形空白**. On, Shift + Space
types `　` in 倉頡, 速成 and 拼音. Off (the default), nothing changes for anyone.

## Behaviour (setting on)

| State when Shift + Space is pressed | Result |
| --- | --- |
| Idle | Inserts `　`. |
| 聯想 suggestions on screen | Dismisses them, then inserts `　`. |
| Composing (倉頡 / 速成) | Commits the first candidate of the page on screen, then inserts `　`. |
| Composing (拼音) | Commits the whole phrase, then inserts `　`. |
| With ⌃, ⌥ or ⌘ also held | Not this shortcut. ⌃/⌘ already go to the app; ⌥ falls through to today's Space handling. |

Caps Lock does not matter. Setting off: Shift + Space behaves exactly like Space, as before.

Which character gets committed is the one Return commits: the first candidate of the page on
screen. Under the 速成 code `竹戈` (141 candidates), paging to 符 籌 凡 鬼 … and pressing
Shift + Space types 符　 — not 的　, page 1's first, which is no longer visible. 臨時英數
(Shift + a letter) used to commit page 1's first in that situation; it now follows the same rule,
so both Shift shortcuts commit a character the user can see. No 聯想 is offered: a space or
letter right after would dismiss the suggestions anyway.

The same rule holds in 拼音, where what is on screen is the phrase itself: the window never pages,
and Return commits the whole phrase as shown. Type `womenshishi`, re-pick 實施 over 事實, and
Shift + Space types 我們實施　. Forcing "the first candidate" there would have undone the pick and
committed 我們事實, which is why `selectFirstCandidateOnScreen()` skips 拼音.

## Design

- **`KeyEventPolicy.typesFullWidthSpace(enabled:keyCode:modifierFlags:)`** — the pure decision,
  unit-tested beside the other key policies. Matched by key code 49, like every other Space
  check, so it is layout-independent. `KeyEventPolicy.fullWidthSpace` holds U+3000.
- **`InputController.selectFirstCandidateOnScreen()`** — selects `candidatePage × 9` before the
  commit, for both Shift shortcuts. It skips 拼音, whose commit is the whole phrase and where
  selecting would override the cursor node's own choice.
- **`InputController.handle`** — one block straight after 臨時英數 and before the 聯想,
  candidate and 拼音 branches, which is where Space pages or commits. Placing it there is what
  makes it apply to all three input methods without touching any of them.
- **`Preferences.shiftSpaceFullWidthSpaceEnabled`** — registered default `false`, read live, so
  the toggle applies on the next key press with no restart. Forwarded by
  `SettingsModel.shiftSpaceFullWidthSpace` (a plain toggle, so a computed forwarder is fine).
- **Settings UI** — a Toggle with a hint in the 輸入 section, right after 全形標點, its nearest
  relative. Seven locales.

`　` is the same code point in Traditional and Simplified output, so 輸出簡體字 has nothing to
convert, and 全形標點 is independent of it.

## Non-goals

- **Not in the input menu.** The request is for a setting, and the menu's quick toggles are for
  settings people flip often. It can be added later if asked for.
- **No Shift + Space half-/full-width mode toggle** (the Windows IME meaning). KeyKey has no
  half-width mode to toggle.
- **No change to what plain Space does**, in any mode.

## Testing

- `KeyEventPolicyTests`: on/off, Caps Lock, plain Space, Shift+⌥/⌃/⌘+Space, Shift with other
  keys, and that the inserted string is exactly U+3000.
- `PreferencesTests`: round-trip, absent reads `false`, registered default `false`.
- `ConfigContentTests`: the 2.14.0 What's New entries; every locale defines the same keys.
- The page-2 rule, against the real 五代 速成 table and ranking: `竹戈` on page 1 commits 的, on
  page 2 符, on page 3 么.
- `InputController` needs a live IMK server, so the end-to-end key flow is checked by hand in a
  Debug build.
