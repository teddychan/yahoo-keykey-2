# Design: Pinyin (拼音) Input Method for Yahoo KeyKey 2

**Date:** 2026-07-06
**Status:** Approved (design); pending spec review
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

**Zhuyin ↔ Hanyu Pinyin is a deterministic, lossless mapping.** The bundled LM is keyed by
hyphen-joined toned zhuyin (e.g. `ㄋㄧˇ-ㄏㄠˇ → 你好`). Converting the user's pinyin into
zhuyin *readings* lets Pinyin reuse the existing model wholesale: full character + phrase
coverage and ranking, **no new corpus to source and no licensing hunt.**

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
e.g. `wo⇥ㄨㄛ`. Only single syllables are entries. Unlike the huge, generated
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

### 2.5 `LanguageModel` — extended with a tone-stripped index

Add a secondary index: **tone-stripped key → aggregated unigrams**. Tone marks
(`ˊ ˇ ˋ ˙` and the implicit first tone) are removed from each key so toneless pinyin
readings match. Built once when the full model is loaded. Existing unigram/`characterScores`
APIs are unchanged.

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
- **`InputController`**: detect a `PhraseComposingEngine` and route the richer keys —
  arrows (move cursor), space/enter (commit or select), digits 1–9 (pick from candidate
  window), backspace. Marked text renders the best-path characters with the cursor node
  highlighted/underlined.
- **`SharedResources`**: provide **lazy full-LM access** — load the full `LanguageModel`
  (and its tone-stripped index) on first Pinyin activation; release it when Pinyin is
  deactivated. Cangjie/Simplex startup path (extract `characterScores`, discard LM) is
  unchanged.
- **`Info.plist`**: add mode `com.dragonapp.inputmethod.yahoo-keykey.Pinyin`
  (`TISIntendedLanguage` `zh-Hant`, `tsInputModeScriptKey` `smTradChinese`) to
  `tsInputModeListKey` and append it to `tsVisibleInputModeOrderedArrayKey`.

### 2.8 Reused as-is

`UserFrequency` (per-character learning bonus feeds candidate ordering), `AssociatedPhrases`
(offered after a commit), `CandidateWindow`, `Punctuation`.

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

- **Unmappable syllables / tail** stay as **raw latin** in the buffer (shown, not dropped).
- **Empty LM lookup** for a span falls back to per-syllable single-character candidates;
  a walk over zero valid readings is a no-op.
- **Full-LM load failure** (Pinyin activation): fail safe — log, present no candidates, do
  not crash; the mode simply produces nothing until reload.
- All engine entry points are pure/total; **no force-unwraps** on disk-loaded data.

---

## 5. Testing (TDD, headless in `KeyKeyEngineTests`)

- **`PinyinSyllableTable`**: every syllable in the table maps to a non-empty zhuyin; table
  loads without duplicates.
- **`PinyinSegmenter`**: `nihao`→`[ni,hao]`, `womenqu`→`[wo,men,qu]`, `xian`→`[xian]`,
  `xi'an`→`[xi,an]`, `fangan`→`[fan,gan]`, plus unparsable-tail cases.
- **`Walker`**: with a small hand-built fixture LM, known inputs resolve to expected
  best paths deterministically; ties broken stably. Golden tests against the real extracted
  LM for a set of known phrases (`nihao`→你好, `womenqu`→我們去) → expected top result.
- **`PinyinEngine`**: key-routing — append, re-walk, cursor move, pick-candidate re-walk,
  commit-all, backspace — driven exactly as `InputController` drives it (engine↔controller
  wiring testable without a live IMK session).
- **Manual smoke test**: build a **`Yahoo KeyKey Debug`** re-id'd bundle (per global macOS
  debug-build rule), install to `~/Library/Input Methods`, type in TextEdit.

---

## 6. Phased delivery

1. **Phase 1 — headless engine:** `pinyin-zhuyin.txt`, `PinyinSyllableTable`,
   `PinyinSegmenter`, `LanguageModel` tone-stripped index, `ReadingGrid`, `Walker`,
   `PinyinEngine` + full test coverage. No app changes yet.
2. **Phase 2 — IMK UX:** `PhraseComposingEngine` protocol, `InputController` routing,
   lazy full-LM in `SharedResources`, `Info.plist` mode, marked-text + candidate wiring.
   Manual smoke test in a re-id'd debug build.
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
