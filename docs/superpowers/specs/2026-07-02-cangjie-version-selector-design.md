# Cangjie generation selector (三代倉頡 / 五代倉頡)

**Issue:** [#30](https://github.com/teddychan/yahoo-keykey-2/issues/30)
**Date:** 2026-07-02
**Status:** Approved design → implementation

## Problem

KeyKey currently ships only the Cangjie **5th-generation** decomposition table
(`Resources/cangjie.txt`, from `ibus-table-chinese/tables/cangjie/cangjie5.txt`).
Yahoo! KeyKey's Cangjie is **3rd-generation** (第三代倉頡). The generations share
the same radical keys but differ in **character-decomposition rules** — i.e. the
letter code you type to produce a character. Long-time Yahoo!/old-Windows Cangjie
users have 三代 muscle memory, so 五代-only breaks familiar codes.

This is a **decomposition-table** feature. It is **not** about candidate sorting;
candidate ordering stays driven by the McBopomofo LM rank + user-learning, exactly
as today, for both generations.

### Verified difference (ibus data matches Yahoo KeyKey and the reporter's examples)

| Char | 三代 (ibus `cangjie3` = Yahoo `cj-ext.cin`) | 五代 (ibus `cangjie5`) |
|---|---|---|
| 面 | `mwyl` 一田卜中 | `mwsl` 一田尸中 |
| 假 | `orye` | `orse` |
| 非 | `lmyyy` 中一卜卜卜 | `lmsy` 中一尸卜 |
| 鬼 | `hi` 竹戈 | `hui` 竹山戈 |
| 醜 | `mwhi` | `mwhui` |
| 樓 | `dlwv` 木中田女 | `dllv` 木中中女 |
| 涵 | `enue` 水弓山水 | `eune` 水山弓水 |

The ibus `cangjie3.txt` codes are **identical to Yahoo's own `cj-ext.cin`** for
every example, so ibus `cangjie3.txt` is a faithful, clean source for the
Yahoo-compatible 三代 table — no need to import `cj-ext.cin`.

## Scope

**In scope:** one Settings control selecting the Cangjie generation (三代 / 五代)
for both the 倉頡 and 速成 engines. Default 三代 (Yahoo-compatible).

**Out of scope (with reasons):**
- **Candidate / associated-phrase sorting.** The issue's point 1 (聯想 ordering ≠
  Yahoo) cannot be reproduced: Yahoo's ranking corpus (`SinicaCorpus`,
  `YahooSearchTerms`, `BPMFMappings`) was never open-sourced and its runtime used a
  commercial encrypted SQLite DB. Recorded on issue #30; associations unchanged.
- **Compatibility mode** (accept both 三代 and 五代 codes at once). Considered,
  deferred by owner; can be added later as a third option.
- **Cangjie 4th generation.** No distributable v4 table exists upstream.

## Decisions (confirmed with owner)

1. Two options: `三代倉頡（Yahoo KeyKey 相容）` and `五代倉頡`, under a `倉頡版本` control.
2. **Default = 三代** (Yahoo fidelity). This changes decompositions for existing
   users on update (they're implicitly on 五代 today) — intended; documented in
   CHANGELOG + About.
3. The setting drives **both** 倉頡 and 速成 (速成 is derived from the selected
   Cangjie table, as today).
4. Candidate ordering unchanged (LM rank + user-learning) for both generations.
5. Live reload on change (no IME reselect/restart).
6. Control lives in the **Settings ▸ 輸入方式** tab only.
7. v3 data = **commit the converted file** + document the conversion command
   (matches the existing v5 `cangjie.txt` handling). No converter script.

## Data

- **New:** `Resources/cangjie3.txt`, converted from
  `ibus-table-chinese/tables/cangjie/cangjie3.txt` with the same transform as the
  existing v5 file: keep only rows between `BEGIN_TABLE`/`END_TABLE`, take the
  first two tab-separated columns (`<code>\t<char>`) via `awk -F'\t'`, drop the
  header and the trailing frequency column.
- **Unchanged:** `Resources/cangjie.txt` stays the 五代 table.
- **Updated:** `Resources/CANGJIE-DATA-LICENSE.txt` documents the 三代 file (same
  "Freely redistributable without restriction" license; author Roy Hiu-yueng Chan /
  chinesecj.com; source `cangjie3.txt`) and records the exact conversion command.

Both files use the format `CangjieTable(text:)` already parses — parser unchanged.

## Components

### Preferences (`App/Preferences.swift`)
- `enum CangjieVersion: String { case v3 = "3"; case v5 = "5" }`.
- `static var cangjieVersion: CangjieVersion` (UserDefaults key `"cangjieVersion"`;
  unknown/missing → `.v3`).
- Register default `"cangjieVersion": "3"`.

### SharedResources (`App/SharedResources.swift`)
- `cangjieTable`, `simplexTable` → `private(set) var`.
- `private func loadCangjieTables(version:)`: v3 → bundle resource `cangjie3.txt`;
  v5 → `cangjie.txt`. Fail-safe to empty `CangjieTable` if missing, then
  `simplexTable = SimplexTable(cangjie: cangjieTable)` (unchanged derivation).
- `init` calls it with `Preferences.cangjieVersion`.
- `func reloadCangjieTables()`: re-reads the preference, rebuilds both tables, posts
  `.cangjieVersionChanged`.
- `extension Notification.Name { static let cangjieVersionChanged }`.

`characterRank`, `associatedPhrases`, `hanConvertFilter`, `userFreq` unchanged.

### InputController (`App/InputController.swift`)
- The two module `makeEngine` closures read `SharedResources.shared.cangjieTable` /
  `.simplexTable` **live** instead of capturing copies at `init`. `characterRank`
  and `userRank` capture unchanged (ranking + learning behave as today).
- Observe `.cangjieVersionChanged` (added in `init`, removed in `deinit`): commit
  any in-progress composition, reset `candidatePage`/`associations`, hide the
  candidate window, then `engine = currentModule.makeEngine()` — the same reset
  path `setValue(_:forTag:client:)` already uses on a mode switch.

### SettingsWindow (`App/SettingsWindow.swift`)
- In `inputMethodsView()`, add a labeled `NSPopUpButton` "倉頡版本" with items
  `三代倉頡（Yahoo KeyKey 相容）` (tag → v3) and `五代倉頡` (tag → v5), selection
  reflecting `Preferences.cangjieVersion`.
- On change: set `Preferences.cangjieVersion`; call
  `SharedResources.shared.reloadCangjieTables()`.
- Retain the popup; set its selection in `refreshControls()` (sync parity).
- Short 說明 label: applies immediately; affects 倉頡 and 速成.

### Build & packaging
- `tools/build-app.sh` and `tools/run-debug.sh`: copy `Resources/cangjie3.txt` into
  `Contents/Resources/` (same error-if-missing pattern as `cangjie.txt`).

## Data flow

```
Settings popup change
  → Preferences.cangjieVersion = v3 | v5
  → SharedResources.reloadCangjieTables()
      → loadCangjieTables(version:)   (rebuild cangjieTable + simplexTable)
      → post .cangjieVersionChanged
  → each InputController observer
      → commit in-progress composition, reset paging/associations, hide window
      → engine = currentModule.makeEngine()   (reads new shared tables live)
  → next keystroke uses the selected generation's decomposition
```

## Error handling
- Missing `cangjie3.txt` at runtime → fail-safe to an empty Cangjie table (logs, no
  candidates), identical to the existing missing-`cangjie.txt` handling.
- Unknown/absent stored `cangjieVersion` → `.v3` (the default).
- Reload **commits** (not discards) any in-progress composition so switching
  mid-composition never silently drops typed input.

## Testing
- **Decomposition difference (locks the feature):** load both bundled tables and
  assert the reporter's examples — e.g. `characters(forCode:)` contains 面 for
  `mwyl` in v3 and for `mwsl` in v5; 鬼 for `hi` (v3) vs `hui` (v5); 樓 for `dlwv`
  (v3) vs `dllv` (v5). Confirms the tables really differ.
- **v3 table loads** non-empty from the bundle.
- **Preferences round-trip:** set/read `v3` and `v5`; unknown stored value → `.v3`.
- Existing CangjieTable / Simplex / engine tests remain green (parser unchanged).

## Docs & release
- **`README.md`:** add a short table — 倉頡版本 · 資料來源 · 範例 (面/鬼) — so the
  三代/五代 distinction and the Yahoo-compatibility default are explicit.
- `CHANGELOG.md`: new-feature entry; explicitly note the **default is 三代倉頡
  (Yahoo KeyKey 相容)**, changing decompositions for users implicitly on 五代.
- Version bump to **v2.1.0** (additive feature).
- About window note if space allows.
- Issue #30: comment confirming Yahoo Cangjie = 三代 (now the default), and that the
  聯想 ordering (point 1) can't be reproduced (data withheld).
- Memory: update `yahoo-keykey-2-project.md`.

## Non-goals / risks
- Not changing candidate/association ordering (LM rank stays).
- Default flip to 三代 changes decompositions for existing users on update
  (intended; documented). User-learning and all other settings are unaffected.
- Reload reparses a table on an explicit, rare user action — acceptable; not on a
  hot path.
