# Design: Pinyin (拼音) Input Method for Yahoo KeyKey 2

**Date:** 2026-07-06
**Status:** Approved with changes (2026-07-06 review folded in: resource contract, lazy LM lifecycle, `ü`/`v`, walker bounds, controller branch order)
**Target stack:** Swift + InputMethodKit + AppKit/SwiftUI, macOS (arm64)

---

## 0. Background & context

The original Yahoo! KeyKey supported a **拼音 (Pinyin)** input method. The current
Swift rewrite (`yahoo-keykey-2`) ships **Cangjie (倉頡)** and **Simplex (速成)** only —
both strictly **single-character** engines (type a code → pick one character → repeat).

This sub-project adds a **phrase/sentence Pinyin input method**, faithful to the original
KeyKey feel: the user types a run of pinyin syllables (`nihao`, `womenqu`) and the engine
composes the best multi-character result, editable before commit.

### Lineage — this revives a designed-but-never-built subsystem

The program's original sub-project 1
(`docs/superpowers/specs/2026-06-21-keykey-lexicon-smart-phonetic-slice-design.md`)
planned a **"Smart Phonetic" Bopomofo engine** with a DP/Viterbi best-path walk over the
open **McBopomofo language model**. The project later pivoted to Cangjie+Simplex only, so
that walker was **never built**. This Pinyin feature builds that walker, driven by **pinyin
readings** instead of bopomofo keystrokes. The engine consumes the exact same bundled LM
(`Resources/data.txt`, generated from OpenVanilla/McBopomofo, keyed by **注音/zhuyin with
tones**).

### Key enabling fact

The **syllable-level correspondence between zhuyin and Hanyu Pinyin is deterministic**: each
zhuyin syllable maps to exactly one pinyin syllable and back. The bundled LM is keyed by
hyphen-joined toned zhuyin (e.g. `ㄋㄧˇ-ㄏㄠˇ → 你好`). Converting the user's pinyin into
zhuyin *readings* lets Pinyin reuse the existing model wholesale: full character + phrase
coverage and ranking, **no new corpus to source and no licensing hunt.**

Two caveats keep this honest (it is *not* a blanket "lossless" claim about user input):
- **Tone is discarded on input** (v1 is toneless), so a pinyin reading maps to a *set* of
  toned zhuyin keys, resolved via the tone-stripped index (§2.5).
- **`ü` has no ASCII key.** v1 accepts **`v` for `ü`** (`lv`→`lü`, `nv`→`nü`, `lve`→`lüe`,
  `nve`→`nüe`), the standard IME convention. Without this, first use of those syllables is a
  nasty surprise. The `pinyin-zhuyin.txt` table therefore keys `ü`-syllables under their `v`
  spelling.

---

## 1. Goal & scope

**Goal:** A user selects "拼音" from the input-source switcher and types Traditional
Chinese by pinyin: a composing buffer shows the best-path characters, a candidate window
offers alternatives per node, and the cursor can move across nodes to correct before
committing to any app.

### Decisions (locked in brainstorming)

- **Input model:** phrase/sentence composition (not single-character).
- **Walker:** full best-path (Viterbi-style) walk — a clean Swift port of McBopomofo's
  approach, **not** vendoring McBopomofo's sources.
- **LM residency:** the full language model is **lazily loaded while Pinyin is active** and
  freed when switching back to Cangjie/Simplex, so non-Pinyin users pay no extra memory.
- **Delivery:** phased — (1) headless engine, (2) IMK composing-buffer UX, (3) polish.

### Assumptions

- **Hanyu Pinyin only** (not Wade-Giles / Tongyong). YAGNI.
- **Toneless input**: the user types letters only; the model is matched via a **tone-stripped
  index** so `hao` matches ㄏㄠˇ好 / ㄏㄠˊ豪 / … Optional tone digits are a *future*
  refinement, not v1.
- **`v` = `ü`** in v1 (see §0 caveat). No other romanization conventions.
- **Traditional Chinese output**, consistent with the app being a zh-Hant IME (identical to
  what Cangjie/Simplex produce). Simplified output could later ride the existing
  `HanConvertFilter`.
- **Unigram-scored walk.** The shipped `LanguageModel` parses unigrams only (no bigram
  parsing exists today); multi-syllable phrase entries carry their own scores, so the walk
  naturally prefers good phrases. Bigrams are a noted future enhancement.

### Out of scope for this sub-project

Tone-digit disambiguation; fuzzy pinyin (zh/z, sh/s, in/ing…); a dedicated Pinyin settings
pane; simplified-output toggle; a reusable Bopomofo front-end (the walker is *kept* generic
enough to allow one later, but no Bopomofo mode is built here); bigram scoring.

---

## 2. Architecture / components

All engine work lands in the existing `Packages/KeyKeyEngine` package; app wiring lands in
`App/`. Cangjie/Simplex engines are **untouched**.

### 2.1 `Resources/pinyin-zhuyin.txt` — checked-in syllable map

A small (~410-line) plain-text data file, one entry per line: `pinyin⇥zhuyin` (tab-separated),
e.g. `wo⇥ㄨㄛ`. Only single syllables are entries, and **`ü`-syllables are keyed under their
`v` spelling** (`lv⇥ㄌㄩ`, `nve⇥ㄋㄩㄝ`, …) per the §0 caveat. Unlike the huge, generated
`data.txt`, this table is small, static, and reviewable, so it is **versioned directly**.
A short generator note / script (`tools/`) documents its provenance (canonical
zhuyin↔pinyin correspondence).

### 2.2 `PinyinSyllableTable` — Swift type

Loads `pinyin-zhuyin.txt`. Exposes:
- the **valid-syllable set** (for the segmenter),
- `zhuyin(forSyllable:) -> String?`.

### 2.3 `PinyinSegmenter` — Swift type

Splits a latin string into syllables: **greedy longest-match with backtracking** against
the valid-syllable set. `'` (apostrophe) forces a syllable boundary (`xi'an` → `xi | an`).
Returns `(syllables: [String], tail: String)` where `tail` is any trailing unparsable
fragment (kept visible, never crashes). Handles the classic ambiguities (`xian` = one
syllable; `fangan` = `fan | gan`).

### 2.4 `ReadingGrid` + `Walker` — reading-source-agnostic composition core

The ported Gramambular-style core. **Operates on zhuyin reading strings**, so it is
independent of pinyin (a future Bopomofo front-end could feed it directly).

- **`ReadingGrid`** — given readings `[String]` (toneless zhuyin), builds spans; each span
  of readings `i..<j` is keyed `readings[i..<j].joined("-")` and its candidate unigrams are
  fetched from the LM's **tone-stripped index**.
- **`Walker`** — a DAG shortest-path (Viterbi-style) walk maximizing the summed unigram
  log-prob across the whole reading sequence. Produces an ordered list of **nodes**; each
  node covers a span and exposes its **chosen text** plus its **alternative candidates**
  (ordered by score, then table order, with the `UserFrequency` bonus applied to the
  leading character).

**Hard bounds (this path runs on every keystroke inside the host app):**
- **`maxComposingSyllables`** cap (e.g. 24): beyond it, further syllable input is refused
  (beep/no-op) rather than growing the grid unboundedly.
- **`maxSpanLength`** = the longest phrase length present in the LM (McBopomofo phrases are
  short, typically ≤ ~8 syllables). Spans longer than this are never built, so grid
  construction is `O(n · maxSpanLength)`, not `O(n²)`.
- **Total-path guarantee:** every position always has at least a single-reading node
  (per-syllable single-character fallback), and if even that misses, a **raw-text node**
  carrying the literal syllable — so the walk always has a valid complete path (§4).
- **Perf tests/benchmarks** for long input (near the cap) live alongside the unit tests;
  a regression that makes the walk super-linear should fail CI.

### 2.5 `TonelessLanguageModelIndex` — a **separate**, lazily-built index

**Do not add this to `LanguageModel.init`.** Startup builds a `LanguageModel` from `data.txt`
*only* to derive `characterRank`, then discards it
([`SharedResources.swift:37`](../../../App/SharedResources.swift)). Baking a tone-stripped
index into `LanguageModel.init` would force every Cangjie/Simplex-only user to pay the Pinyin
cost at startup — violating the memory requirement.

Instead, a distinct type — **`TonelessLanguageModelIndex`** (or `PinyinLanguageModel`) —
is constructed **only when Pinyin is first activated** (§2.7). It maps **tone-stripped key →
aggregated unigrams** (tone marks `ˊ ˇ ˋ ˙` and the implicit first tone stripped from each
key). `LanguageModel` itself is **unchanged** — its `init` and `characterScores` stay as they
are, so the Cangjie/Simplex startup path is byte-for-byte the same.

### 2.6 `PinyinEngine` — the composing-buffer engine

Conforms to the existing `InputEngine` protocol **plus** a new small
**`PhraseComposingEngine`** protocol (kept separate so Cangjie/Simplex are unaffected):

- state: raw latin buffer, derived syllables, current best-path nodes, and a **node cursor**.
- `handleKey` appends letters, re-segments, and re-walks.
- cursor movement across nodes; **candidates-at-cursor**; **pick-candidate → pin that node
  and re-walk** the remainder; **commit-all**; backspace deletes the last syllable (or the
  last raw letter of an unparsed tail).

### 2.7 App wiring (`App/`)

- **`InputMethodModule`** registry (`InputController.swift`): add
  `InputMethodModule(modeSuffix: "Pinyin", displayName: "拼音") { PinyinEngine(...) }`.
  **Registration must stay cheap** — building the module list must *not* touch the Pinyin LM
  (that only happens on activation, below).
- **`InputController` key routing — branch order matters.** The current candidate block
  ([`InputController.swift:302`](../../../App/InputController.swift)) assumes "candidates
  exist ⇒ digits commit, arrows page". Pinyin needs digits to **pin a node without
  committing** and arrows to **move the node cursor**. So the **`PhraseComposingEngine`
  branch must run *before* that existing Cangjie/Simplex candidate block** and fully own key
  dispatch for Pinyin (arrows = cursor, digits = pin candidate + re-walk, space/enter =
  commit-all, backspace = delete last syllable/tail letter). Cangjie/Simplex fall through to
  the unchanged existing path. Marked text renders the best-path characters with the cursor
  node highlighted/underlined.
- **`SharedResources` — reference-counted Pinyin LM lifecycle.** IMK creates **one
  `InputController` per client app**, so several controllers may be in Pinyin at once.
  `SharedResources` owns an **optional Pinyin LM cache** (`TonelessLanguageModelIndex`) with
  a **thread-safe, reference-counted acquire/release**:
  - `acquirePinyinModel()` — called when a controller enters Pinyin; builds the index on the
    first acquire (0→1), returns the shared instance, increments the count.
  - `releasePinyinModel()` — called when a controller leaves Pinyin *or* is deinited;
    decrements, and **drops the strong reference only when the count reaches 0** (no active
    Pinyin controller remains).
  - Guarded by a lock; `characterRank`/Cangjie/Simplex state is untouched.
  - **Acceptance is about the object graph, not Activity Monitor:** the criterion is "no
    retained Pinyin LM while no controller is in Pinyin," since Swift/malloc may not return
    RSS to the OS immediately.
- **Info.plist**: add mode `com.dragonapp.inputmethod.yahoo-keykey.Pinyin`
  (`TISIntendedLanguage` `zh-Hant`, `tsInputModeScriptKey` `smTradChinese`) to
  `tsInputModeListKey` and append it to `tsVisibleInputModeOrderedArrayKey`.

### 2.8 Build / packaging contract (do not skip — tests can pass while the installed IME fails)

The app build script copies resources and lists sources **explicitly**, so new files must be
wired in by hand:

- **`tools/build-app.sh`**: add a `cp "$ROOT/Resources/pinyin-zhuyin.txt"
  "$APP/Contents/Resources/"` step (mirroring the `data.txt`/Cangjie copies, with the same
  fail-if-missing guard), **and** add every new `App/*.swift` file (e.g. the Pinyin
  controller helpers) to the explicit `swiftc` source list at
  [`build-app.sh:106`](../../../tools/build-app.sh). New `KeyKeyEngine` package sources are
  picked up by SwiftPM automatically; new **App** sources are **not**.
- **Release/installer packaging** (`installer/`, CI `dragon-release-ci` which runs
  `build-app.sh`): confirm the new resource ships in the packaged `.pkg`/`.zip`.
- **Runtime lookup test:** verify `Bundle.main.url(forResource: "pinyin-zhuyin", …)` resolves
  in the *installed* bundle, not just in the test harness.

### 2.9 Reused as-is

- **`UserFrequency`** — the existing store is **per-character**, and the bonus is applied to a
  candidate's **leading character** only. This nudges ordering; it is **not** true phrase
  learning (a committed phrase does not become a learned unit). Stated plainly so v1 doesn't
  oversell it; phrase-level learning is a future item.
- **`AssociatedPhrases`** — offered after commit **only for single-character commits**,
  matching current behavior ([`InputController.swift:391`](../../../App/InputController.swift)
  already guards `text.count == 1`). Multi-character Pinyin commits do **not** trigger 聯想.
- **`CandidateWindow`**, **`Punctuation`** — unchanged.

---

## 3. Data flow

```
keystroke (letter)
  → InputController.handle → PinyinEngine.handleKey (append to raw buffer)
    → PinyinSegmenter → [syllables] (+ tail)
    → PinyinSyllableTable → [zhuyin readings]
    → ReadingGrid (spans + LM tone-stripped lookup) → Walker → best-path nodes
    → engine returns { composingText, cursorNode, candidatesAtCursor }
  → controller sets marked text (best path, cursor node highlighted) + candidate window
  → digit: pick candidate for cursor node → pin + re-walk
  → arrows: move node cursor
  → space / enter: commit all → insertText: to client app → offer AssociatedPhrases
  → backspace: remove last syllable / last tail letter → re-walk
```

---

## 4. Error handling

InputMethodKit controllers run in-process inside host apps, so nothing here may crash the
host:

- **Unmappable syllables / tail** stay as **raw latin** in the buffer (shown, not dropped),
  and are represented as a **raw-text node** so the walker's path is always complete.
- **Empty LM lookup** for a span falls back to per-syllable single-character candidates; if
  even that misses, the raw-text node guarantees a valid path (§2.4). A walk over zero valid
  readings is a no-op.
- **Full-LM load failure** (Pinyin activation): fail safe — log, present no candidates, do
  not crash; the mode simply produces nothing until reload.
- All engine entry points are pure/total; **no force-unwraps** on disk-loaded data.

---

## 5. Testing (TDD, headless in `KeyKeyEngineTests`)

- **`PinyinSyllableTable`**: every syllable in the table maps to a non-empty zhuyin; table
  loads without duplicates.
- **`PinyinSegmenter`**: `nihao`→`[ni,hao]`, `womenqu`→`[wo,men,qu]`, `xian`→`[xian]`,
  `xi'an`→`[xi,an]`, `fangan`→`[fan,gan]`, **`lv`→`[lv]`, `nve`→`[nve]` (ü via v)**, plus
  unparsable-tail cases.
- **`Walker`**: with a small hand-built fixture LM, known inputs resolve to expected
  best paths deterministically; ties broken stably. Golden tests against the real extracted
  LM for a set of known phrases (`nihao`→你好, `womenqu`→我們去) → expected top result.
  **Bounds/perf:** input at `maxComposingSyllables` completes within a small time budget
  (asserted), and a raw-text-only input still yields a complete path.
- **`PinyinEngine`**: key-routing — append, re-walk, cursor move, pick-candidate re-walk,
  commit-all, backspace — driven exactly as `InputController` drives it (engine↔controller
  wiring testable without a live IMK session).
- **Lifecycle / resource contract (acceptance criteria):**
  - Building the `InputMethodModule` registry **does not** construct the Pinyin LM (assert
    no acquire happens from registration alone).
  - Cangjie/Simplex **startup path and steady-state object graph do not regress** when Pinyin
    is never selected (no `TonelessLanguageModelIndex` retained; `LanguageModel.init`
    unchanged).
  - Ref-count acquire/release: two simulated controllers in Pinyin keep the index alive;
    releasing one keeps it; releasing both drops the strong reference (assert on the object
    graph, not RSS).
- **Manual smoke test**: build a **`Yahoo KeyKey Debug`** re-id'd bundle (per global macOS
  debug-build rule), install to `~/Library/Input Methods`, type in TextEdit — including a
  `ü`/`v` syllable and a long phrase — and confirm the bundled `pinyin-zhuyin.txt` resolves
  from the installed bundle.

---

## 6. Phased delivery

1. **Phase 1 — headless engine:** `pinyin-zhuyin.txt` (with `v`/`ü` keys),
   `PinyinSyllableTable`, `PinyinSegmenter`, `TonelessLanguageModelIndex` (separate lazy
   type — `LanguageModel` untouched), bounded `ReadingGrid`/`Walker` (with raw-text nodes),
   `PinyinEngine` + full test coverage incl. bounds/perf. No app changes yet.
2. **Phase 2 — IMK UX + resource contract:** `PhraseComposingEngine` protocol,
   `InputController` routing **branched before the existing candidate block**,
   **reference-counted lazy Pinyin LM in `SharedResources`**, `Info.plist` mode, marked-text
   + candidate wiring, **`tools/build-app.sh` resource copy + source-list update** and
   packaging check. Manual smoke test in a re-id'd debug build. Lifecycle acceptance tests.
3. **Phase 3 — polish:** candidate paging/highlight parity with Cangjie/Simplex,
   `AssociatedPhrases` after commit, `UserFrequency` integration, edge-case hardening,
   CHANGELOG + docs.

---

## 7. Notes / open items

- **Future enhancements (explicitly deferred):** bigram scoring (needs LM format + parser
  changes), tone-digit disambiguation, fuzzy pinyin, a Bopomofo front-end reusing the same
  `Walker`, simplified-output toggle.
- **Bundle/mode id** uses the current scheme `com.dragonapp.inputmethod.yahoo-keykey.*`
  (the `inputmethod` component is required for macOS registration — see project memory).
