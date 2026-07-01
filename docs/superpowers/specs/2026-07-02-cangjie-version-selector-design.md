# Cangjie generation selector (第三代 / 第五代)

**Issue:** [#30](https://github.com/teddychan/yahoo-keykey-2/issues/30)
**Date:** 2026-07-02
**Status:** Approved design → implementation

## Problem

KeyKey ships only the Cangjie **5th-generation** decomposition table
(`Resources/cangjie.txt`, from `ibus-table-chinese/tables/cangjie/cangjie5.txt`).
Long-time Yahoo! 輸入法 users learned **3rd-generation** Cangjie and cannot adapt
to the 5th-gen 拆碼 (decomposition rules). Issue #30 asks for 3rd-gen support.

The Cangjie "generation" is the **decomposition table** — how a character breaks
into radicals, i.e. what letter code you type to get it. It is **not** the
candidate sort order. Candidate ordering stays driven by the McBopomofo LM rank
plus the user-learning bonus, exactly as today.

## Scope

**In scope:** a user-selectable Cangjie generation (3rd / 5th) that swaps the
decomposition table for both the Cangjie and Simplex (速成) engines.

**Out of scope:**
- The associated-phrases ordering complaint (issue #30 point 1). We do not have
  Yahoo's ranking data; the association list comes from the McBopomofo LM. Left
  for a separate follow-up.
- **Cangjie 4th generation.** No distributable v4 table exists upstream
  (`ibus-table-chinese` ships only `cangjie3.txt` and `cangjie5.txt`). Not offered.

## Decisions (confirmed with owner)

1. Scope = version selector only; association reordering deferred.
2. The version setting drives **both** Cangjie and Simplex (one control). Simplex
   is derived from the same generation's table.
3. **Live reload** on change (no IME reselect/restart required).
4. Control lives in the **Settings ▸ 輸入方式** tab only (not the quick input menu).
5. v3 data = **commit the converted file** + document the conversion command
   (matches how the existing v5 `cangjie.txt` is handled). No new converter script.
6. Default = **5th generation** → zero behavior change for existing users.

## Data

- **New:** `Resources/cangjie3.txt`, converted from upstream
  `ibus-table-chinese/tables/cangjie/cangjie3.txt` using the same transform as the
  existing v5 file: take only the rows between `BEGIN_TABLE`/`END_TABLE`, keep the
  first two tab-separated columns (`<code>\t<char>`), drop the trailing frequency
  column and the file header.
- **Unchanged:** `Resources/cangjie.txt` remains the 5th-gen table (default).
- **Updated:** `Resources/CANGJIE-DATA-LICENSE.txt` documents the v3 file (same
  "Freely redistributable without restriction" license; author Roy Hiu-yueng Chan
  / chinesecj.com; source `cangjie3.txt`) and records the exact conversion command
  for reproducibility.

Both files share the format the existing `CangjieTable(text:)` parser already
accepts, so the parser is unchanged.

## Components

### Preferences (`App/Preferences.swift`)
- Add `enum CangjieVersion: String { case v3 = "3"; case v5 = "5" }`.
- Add `static var cangjieVersion: CangjieVersion` (get/set backed by a
  `"cangjieVersion"` UserDefaults string key; unknown/missing → `.v5`).
- Register default `"cangjieVersion": "5"` in `registerDefaults()`.

### SharedResources (`App/SharedResources.swift`)
- Change `cangjieTable` and `simplexTable` from `let` to `private(set) var`.
- Extract `private func loadCangjieTables(version:)`:
  - v5 → bundle resource `cangjie.txt`; v3 → `cangjie3.txt`.
  - Fail-safe to an empty `CangjieTable` (matches current behavior) if the file
    is missing, then derive `simplexTable = SimplexTable(cangjie:)`.
- `init` calls `loadCangjieTables(version: Preferences.cangjieVersion)`.
- Add `func reloadCangjieTables()`:
  - Re-reads `Preferences.cangjieVersion`, rebuilds both tables, then posts
    `NotificationCenter.default.post(name: .cangjieVersionChanged, ...)`.
- Define `extension Notification.Name { static let cangjieVersionChanged = ... }`.

`characterRank`, `associatedPhrases`, `hanConvertFilter`, `userFreq` are unchanged
(the generation does not affect them).

### InputController (`App/InputController.swift`)
- The two module `makeEngine` closures read the tables **live** from
  `SharedResources.shared.cangjieTable` / `.simplexTable` instead of capturing
  local copies at `init`. `characterRank` and `userRank` capture is unchanged.
- Register a `.cangjieVersionChanged` observer (in `init`, removed in `deinit`)
  that rebuilds the active engine using the existing reset path:
  commit any in-progress composition, `candidatePage = 0`, `associations = []`,
  `candidateWindow.hide()`, then `engine = currentModule.makeEngine()`.
  This mirrors what `setValue(_:forTag:client:)` already does on a mode switch.

Because IMK runs one process with one controller per client, the notification
reaches every live controller and each rebuilds its own engine.

### SettingsWindow (`App/SettingsWindow.swift`)
- In `inputMethodsView()` (輸入方式 tab), add a "倉頡版本" `NSPopUpButton` with items
  第五代 (tag→v5) and 第三代 (tag→v3), selection reflecting `Preferences.cangjieVersion`.
- On change: set `Preferences.cangjieVersion`, call
  `SharedResources.shared.reloadCangjieTables()`.
- Retain the popup as a property and set its selection in `refreshControls()` so it
  stays in sync when the window is re-shown.
- Add a short 說明 label: switching applies immediately; affects both 倉頡 and 速成.

### Build & packaging
- `tools/build-app.sh`: copy `Resources/cangjie3.txt` into
  `Contents/Resources/` alongside `cangjie.txt` (error if missing, same pattern).
- `tools/run-debug.sh`: ensure the debug build includes `cangjie3.txt` (mirror
  whatever it does for `cangjie.txt`).

## Data flow

```
Settings popup change
  → Preferences.cangjieVersion = v3|v5
  → SharedResources.reloadCangjieTables()
      → loadCangjieTables(version:)  (rebuild cangjieTable + simplexTable)
      → post .cangjieVersionChanged
  → each InputController observer
      → commit in-progress composition, reset paging/associations, hide window
      → engine = currentModule.makeEngine()   (reads new shared tables live)
  → next keystroke uses the new generation's decomposition
```

## Error handling
- Missing `cangjie3.txt` at runtime → fail-safe to an empty Cangjie table (logs,
  no candidates), identical to the existing missing-`cangjie.txt` handling.
- Unknown/absent `cangjieVersion` default → `.v5`.
- Reload commits (not discards) any in-progress composition so no typed input is
  silently lost when the user flips the setting mid-composition.

## Testing
- **RealCangjieTableTests** (or a new v3 case): the bundled `cangjie3.txt` loads,
  is non-empty, and differs from `cangjie.txt` for at least one character whose
  decomposition changed between generations (assert a concrete code→char pair that
  is v3-only, and one that is v5-only).
- **Preferences round-trip:** setting `cangjieVersion` persists and reads back;
  unknown stored value falls back to `.v5`.
- Existing CangjieTable/Simplex/engine tests remain green (parser unchanged).

## Docs & release
- `CHANGELOG.md`: new-feature entry (可選 倉頡第三代/第五代 拆碼).
- Version bump to **v2.1.0** (minor — additive feature).
- README + About: note the selectable generation.
- Memory: update `yahoo-keykey-2-project.md`.

## Non-goals / risks
- Not changing candidate sort order or association ranking.
- Reload reparses the table (~68k lines for v5) on an explicit, rare user action —
  acceptable; not on any hot path.
