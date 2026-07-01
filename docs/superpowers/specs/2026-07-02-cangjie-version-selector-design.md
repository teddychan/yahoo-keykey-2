# Cangjie generation selector (五代倉頡 / 三代倉頡 · Yahoo KeyKey 相容)

**Issue:** [#30](https://github.com/teddychan/yahoo-keykey-2/issues/30)
**Date:** 2026-07-02
**Status:** Approved design → implementation

## Problem

KeyKey ships only the Cangjie **5th-generation** decomposition table
(`Resources/cangjie.txt`, from `ibus-table-chinese/cangjie5.txt`) and orders
candidates by the McBopomofo LM. Yahoo! KeyKey's Cangjie is **3rd-generation**:
same radical keys, different **decomposition rules** (the code you type for a
character) and its own **candidate order**. Long-time Yahoo users have 三代 muscle
memory, so 五代-only breaks familiar codes and first-candidates.

Two distinct "orders" are involved, with opposite data availability:
- **Cangjie candidate order** (which char is first for a code) — **available** as
  the line order of Yahoo's `cj-ext.cin`. We use it.
- **關聯字表 / phrase ranking** (associated words after committing a char) —
  **not available**: `bency/YahooKeyKey` `.gitignore`s the ranking corpora
  (`SinicaCorpus`, `YahooSearchTerms`, `BPMFMappings` — README placeholders only)
  and shipped them via a commercial encrypted SQLite (CEROD) DB. Open code ≠ open
  data. Left as the current McBopomofo associations.

### Verified 三代 vs 五代 (ibus data matches Yahoo `cj-ext.cin` and the reporter's examples)

| Char | 三代 (`cj-ext.cin` = ibus `cangjie3`) | 五代 (ibus `cangjie5`) |
|---|---|---|
| 面 | `mwyl` 一田卜中 | `mwsl` 一田尸中 |
| 鬼 | `hi` 竹戈 | `hui` 竹山戈 |
| 醜 | `mwhi` | `mwhui` |
| 樓 | `dlwv` 木中田女 | `dllv` 木中中女 |
| 涵 | `enue` 水弓山水 | `eune` 水山弓水 |

## Scope

**In scope:** one Settings control selecting the Cangjie generation (五代 default /
三代 Yahoo-compatible) for both the 倉頡 and 速成 engines. The 三代 mode uses
Yahoo's table **and its native candidate order**.

**Out of scope (with reasons):**
- **關聯字 / associated-phrase Yahoo ordering.** Data was never open-sourced (see
  above). Associations stay as current McBopomofo ordering for both modes. Recorded
  on issue #30. (This is where a competing spec's "must reproduce Yahoo 關聯字表"
  requirement is not satisfiable — no data exists to import or reconstruct.)
- **Compatibility mode** (accept both 三代 and 五代 codes at once). Deferred; can be
  added later as a third option.
- **Cangjie 4th generation.** No distributable v4 table exists.

## Decisions (confirmed with owner)

1. Two options under a `倉頡版本` control: `五代倉頡` and `三代倉頡（Yahoo KeyKey 相容）`.
2. **Default = 五代** — existing behavior preserved; 三代 is opt-in (no surprise
   for current users).
3. The setting drives **both** 倉頡 and 速成.
4. **三代 candidate order = Yahoo `cj-ext.cin` native (table) order** — not the LM.
   **五代 keeps the current LM ranking** (unchanged). User-learning applies on top
   in both modes.
5. 三代 data source = Yahoo's own `cj-ext.cin` / `simplex-ext.cin` (faithful to
   "Yahoo original order"), not ibus `cangjie3.txt`.
6. Live reload on change (no IME reselect/restart).
7. Control lives in the **Settings ▸ 輸入方式** tab only.
8. Data = **commit converted files** + document the conversion commands. No script.

## Data files

Converted to the `<code>\t<char>` (Cangjie) / `<quickcode>\t<char>` (Simplex)
format the engines already parse; header + trailing `%`-directives dropped;
**line order preserved** (it is Yahoo's native candidate order).

| Mode | Cangjie table | Simplex table | Source |
|---|---|---|---|
| 五代 (default) | `Resources/cangjie.txt` (existing) | derived via `SimplexTable(cangjie:)` | ibus `cangjie5.txt` |
| 三代 (Yahoo) | `Resources/cangjie-yahoo.txt` (new) | `Resources/simplex-yahoo.txt` (new) | `bency/YahooKeyKey` `cj-ext.cin`, `simplex-ext.cin` |

- `cj-ext.cin` chardef format is `<code><ws><char>` (mixed tab/space); convert with
  first-whitespace split, keep code + char, preserve order. The `CangjieTable`
  renderable filter drops CNS/Ext-B tofu entries at load (as it already does for v5).
- Yahoo 速成: `simplex-ext.cin` is already quick-coded (`<quickcode><ws><char>`,
  native order); load directly (see SimplexTable) rather than re-deriving.
- **License caveat to flag:** `cj-ext.cin`/`simplex-ext.cin` derive from
  opendesktop.org.tw's `cj.cin`/`simplex.cin` (yylin & b6s) within the New-BSD
  Yahoo! KeyKey project, but carry **no explicit per-file license line**. Provenance
  + attribution + this caveat documented in `CANGJIE-DATA-LICENSE.txt`.

## Components

### Preferences (`App/Preferences.swift`)
- `enum CangjieVersion: String { case v5 = "5"; case v3 = "3" }`.
- `static var cangjieVersion` (UserDefaults `"cangjieVersion"`; unknown → `.v5`).
- Register default `"cangjieVersion": "5"`.

### SimplexTable (`Packages/KeyKeyEngine/.../SimplexTable.swift`)
- Add an initializer that loads **already-quick-coded** `<quickcode>\t<char>` lines
  directly (no first+last re-derivation), preserving order — for `simplex-yahoo.txt`
  (e.g. `init(quickCodeText:)`). Existing `init(cangjie:)` / `init(text:)` unchanged.

### SharedResources (`App/SharedResources.swift`)
- `cangjieTable`, `simplexTable` → `private(set) var`. Add
  `private(set) var cangjieRank: [Character: Double]` — the effective single-char
  rank the engines use: `characterRank` (LM) for 五代, `[:]` for 三代 (empty →
  engine's stable sort preserves Yahoo native table order).
- `private func loadCangjieTables(version:)`:
  - 五代 → `cangjie.txt`, `simplexTable = SimplexTable(cangjie:)`, `cangjieRank =
    characterRank`.
  - 三代 → `cangjie-yahoo.txt`, `simplexTable = SimplexTable(quickCodeText:)` from
    `simplex-yahoo.txt` (fail-safe: derive from cangjie if missing), `cangjieRank = [:]`.
  - Fail-safe to empty `CangjieTable` if a file is missing (as today).
- `init` calls it with `Preferences.cangjieVersion`.
- `func reloadCangjieTables()`: re-read preference, rebuild the three, post
  `.cangjieVersionChanged`.
- `extension Notification.Name { static let cangjieVersionChanged }`.
- `characterRank` (full LM rank) still computed once at init and retained (switching
  back to 五代 needs no LM rebuild).

### InputController (`App/InputController.swift`)
- Both module `makeEngine` closures read `SharedResources.shared.cangjieTable`,
  `.simplexTable`, and **`.cangjieRank`** live (not captured copies). `userRank`
  (user-learning) unchanged → learning stays on in both modes.
- Observe `.cangjieVersionChanged` (added in `init`, removed in `deinit`): commit
  any in-progress composition, reset `candidatePage`/`associations`, hide the
  candidate window, then `engine = currentModule.makeEngine()` — same reset path
  `setValue(_:forTag:client:)` uses on a mode switch.

### SettingsWindow (`App/SettingsWindow.swift`)
- In `inputMethodsView()`, add an `NSPopUpButton` "倉頡版本": `五代倉頡` (tag → v5,
  default) and `三代倉頡（Yahoo KeyKey 相容）` (tag → v3), reflecting the preference.
- On change: set `Preferences.cangjieVersion`; call
  `SharedResources.shared.reloadCangjieTables()`. Retain the popup; set selection in
  `refreshControls()`. Short 說明: applies immediately; affects 倉頡 and 速成; 三代
  uses Yahoo's original codes and candidate order.

### Build & packaging
- `tools/build-app.sh` and `tools/run-debug.sh`: copy `cangjie-yahoo.txt` and
  `simplex-yahoo.txt` into `Contents/Resources/` (same error-if-missing pattern).

## Data flow

```
Settings popup change
  → Preferences.cangjieVersion = v5 | v3
  → SharedResources.reloadCangjieTables()
      → loadCangjieTables(version:)   (rebuild cangjieTable, simplexTable, cangjieRank)
      → post .cangjieVersionChanged
  → each InputController observer
      → commit in-progress composition, reset paging/associations, hide window
      → engine = currentModule.makeEngine()   (reads new shared tables + rank live)
  → next keystroke uses the selected generation's table and (三代) native order
```

## Error handling
- Missing 三代 data file → fail-safe (empty Cangjie table / derive Simplex from
  cangjie), logged; matches current missing-file handling.
- Unknown/absent stored `cangjieVersion` → `.v5` (the default).
- Reload **commits** (not discards) any in-progress composition.

## Testing
- **Decomposition difference:** load `cangjie.txt` (v5) and `cangjie-yahoo.txt`
  (v3); assert the reporter's examples — 面 for `mwyl`(v3)/`mwsl`(v5), 鬼 for
  `hi`(v3)/`hui`(v5), 樓 `dlwv`/`dllv`. Confirms tables differ.
- **三代 native order:** `CangjieEngine(table: yahooTable, characterRank: [:])`
  returns candidates in table order (e.g. 我 first for `hqi`).
- **Yahoo Simplex:** `SimplexTable(quickCodeText:)` parses `simplex-yahoo.txt`,
  preserves native order for a known quick code (e.g. `hi`).
- **五代 unchanged:** v5 candidates still ordered by LM rank (regression guard).
- **Preferences round-trip:** set/read `v5`/`v3`; unknown → `.v5`.
- Existing engine/table tests remain green (parsers unchanged; new Simplex
  initializer additive).

## Docs & release
- **`README.md`:** add the mode table (Mode · Table source · example codes) making
  the 三代/五代 distinction and the 三代-uses-Yahoo-order behavior explicit.
- `CHANGELOG.md`: new-feature entry (opt-in 三代倉頡 Yahoo 相容; default stays 五代).
- Version bump to **v2.1.0**.
- Issue #30: comment — 三代 mode reproduces Yahoo's Cangjie codes **and candidate
  order**; the 關聯字 phrase ranking cannot be reproduced (corpus withheld, evidence).
- Memory: update `yahoo-keykey-2-project.md`.

## Non-goals / risks
- Not reproducing Yahoo's 關聯字 phrase ranking (data withheld — see Scope).
- 三代 and 五代 order candidates differently by design (native vs LM); intended.
- `cj-ext.cin`/`simplex-ext.cin` lack explicit per-file license lines (flagged;
  provenance documented).
- Reload reparses a table (cj-ext ~82.9k lines) on a rare explicit action —
  acceptable; not a hot path.
