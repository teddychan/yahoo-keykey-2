# Design: Yahoo! KeyKey Rewrite — Sub-project 1: Lexicon + Smart Phonetic Vertical Slice

**Date:** 2026-06-21
**Status:** Approved (design); pending spec review
**Target stack:** Swift + InputMethodKit + AppKit/SwiftUI, macOS (arm64 + x86_64)

---

## 0. Background & program context

The `Yahoo_KeyKey` repository is an **installer-packaging project** (`build.sh` +
`pkgbuild`/`productbuild` + plists + scripts) that wraps a **prebuilt, closed-source
binary** of the Yahoo! KeyKey input method (`root/Library/Input Methods/Yahoo! KeyKey.app`).
The IME is a Traditional Chinese Bopomofo input method built on **OpenVanilla** +
Apple's **InputMethodKit** + WebKit. There is **no source code** for the IME anywhere
in the repo — only the compiled universal binary (ppc/i386/x86_64, no arm64), resources,
and a 12 MB proprietary lexicon (`KeyKey.db`).

**Goal of the overall program:** rewrite the *input method itself* in a modern macOS
language (Swift), reproducing its exact features — no features added, no features
removed — beyond what is technically impossible.

### Decisions already made

- **Scope:** rewrite the **IME**, not the installer.
- **Language/stack:** **Swift + InputMethodKit + AppKit/SwiftUI**.
- **Dead dependencies:** reproduce every feature's UI/behavior faithfully, but the three
  features whose backends are permanently gone (Yahoo's shutdown in 2013) become
  **clearly-disabled no-ops**: the online Yahoo Dictionary lookup, the software update
  check, and MobileMe/iDisk phrase sync. The lexicon (`KeyKey.db`) is **reverse-engineered
  and reused exactly**.
- **Sequencing:** **vertical slice first** — prove the riskiest path (lexicon → engine →
  IMK) end-to-end before adding breadth.

### Feature inventory (full program — for context only)

- **Input methods:** Smart Phonetic (好打注音), Traditional Phonetic (傳統注音),
  Cangjie (倉頡), Simplex (簡易).
- **Phonetic keyboard layouts:** Standard, ETen, ETen 26, Hsu.
- **Filters / aux modules:** Han conversion (TC↔SC), full-width characters, associated
  phrases, Bopomofo correction, One-Key (一點通).
- **UI surfaces:** horizontal / vertical / plain candidate windows, symbol table, smiley
  view, tooltip, notify window, online dictionary window (WebKit + Speak/TTS).
- **Helper apps:** Preferences (General/Phonetic/Cangjie/Simplex/Phrase/Misc/Update),
  Phrase Editor, reverse lookup, Takao word count, Download/Update.
- **Data/sync:** custom phrase add, predefined texts, phrase DB import/export,
  MobileMe/iDisk backup; user learning store (encrypted SQLite: `user_unigrams`,
  `user_bigram_cache`, `DynamicCandidateOrder.sqlite3`).

### Program decomposition (each gets its own spec → plan → build)

| # | Sub-project | Risk |
|---|---|---|
| **1 (this doc)** | Lexicon spike + Smart Phonetic vertical slice | 🔴/🟠 |
| 2 | Remaining input methods + layouts + filters + aux modules | 🟠 |
| 3 | Full candidate & UI surface family | 🟡 |
| 4 | Preferences app | 🟡 |
| 5 | Phrase Editor (+ reverse lookup, word count) | 🟡 |
| (later) | Modern installer / notarized packaging | 🟢 |

---

## 1. Goal & scope of this sub-project

**Goal:** A user can install the rewritten app to `~/Library/Input Methods`, select it on
current macOS (arm64), and type Traditional Chinese in **Smart Phonetic** mode with the
**Standard** Bopomofo layout — composing buffer, candidate window, selection, and
commit-to-any-app all working, with candidates drawn from KeyKey's **exact** lexicon.

### Out of scope for this slice (deferred to later sub-projects)

Traditional Phonetic / Cangjie / Simplex modes; ETen / ETen 26 / Hsu layouts; Han-convert
& full-width filters; associated phrases, Bopomofo correction, One-Key; Preferences app;
Phrase Editor; symbol / smiley / tooltip / notify / dictionary windows; update & sync;
localization beyond zh-Hant; notarized installer packaging.

---

## 2. Architecture / components

### 2.1 `lexicon-tools` — offline Swift CLI

Decodes `KeyKey.db` → a documented, Swift-loadable language model and validates it.

- **Input:** the original `KeyKey.db` (12 MB, custom packed format: a big-endian offset
  table at the head indexing into records).
- **Output:** an intermediate LM with two relations, in a **single** format — a
  plain-text, mmap-loadable LM (McBopomofo-style), inspectable and fast enough at runtime:
  - **unigram:** `reading → [(phrase, score)]`
  - **bigram:** `(previousPhrase, currentPhrase) → score`
- **Validation (no live-binary oracle):** the original is an `LSBackgroundOnly` IMK
  server, not a CLI, so it cannot be driven headlessly to produce reference outputs.
  Validate the decoded LM instead by:
  - **Structural checks** — readings decode to valid Bopomofo, phrases are valid CJK,
    scores are monotonic/plausible, counts are sane.
  - **Cross-check against McBopomofo's open LM** — coverage and top-candidate ranking
    agreement for a sample of readings (sanity, not byte-equality).

### 2.2 `KeyKeyEngine` — pure Swift package, no UI, fully unit-tested

- **`BopomofoComposer`** — Standard layout only for this slice. Maps keystrokes to a
  Bopomofo syllable (initial / medial / final / tone), supports backspace and syllable
  boundaries; emits completed syllables (readings).
- **`LanguageModel`** — loads the extracted LM; unigram lookup by reading, bigram lookup
  by (prev, current).
- **`SmartPhoneticEngine`** — holds the sequence of syllable readings; runs a DP/Viterbi
  best-path walk over the LM to produce the composing string and per-node candidate lists;
  supports manual candidate override, cursor movement, and backspace.

All APIs are pure/total and deterministic; no force-unwraps on externally-loaded data.

### 2.3 `YahooKeyKey.app` — IMK shell

- **`InputController: IMKInputController`** — `inputText:`/`handleEvent:`, marked-text
  rendering of the composing buffer (with highlight/underline), `commitComposition`,
  and candidate-key dispatch (space / number keys / arrows / Enter / Esc / Backspace).
- **TIS registration** via Info.plist InputMethodKit keys; `LSUIElement`/background-only;
  connection name; principal class.
- **Minimal menu** — shows the active mode (Smart Phonetic). Full mode switching deferred.
- **Bundle id:** `com.github.teddychan.YahooKeyKey` (fresh id; not the legacy
  `com.yahoo.inputmethod.KeyKey`).

### 2.4 Minimal candidate window — AppKit `NSPanel`

Borderless panel showing numbered candidates with space/arrow paging and number/click
selection. The full window family (vertical / plain / symbol / smiley) arrives in
sub-project 3.

---

## 3. Data flow

```
keystroke
  → IMKInputController.handleEvent
    → engine.handleKey
      → BopomofoComposer assembles syllable; SmartPhoneticEngine updates best path
      → engine returns { composingString, candidates, cursor }
    → controller sets marked text + shows/updates candidate window
  → Enter / auto-commit
    → controller insertText: to the client application
```

---

## 4. Lexicon spike (Step 0) — the gating work

KeyKey's "Smart Phonetic" is the OpenVanilla **`OVIMSmartMandarin`** engine (confirmed in
the binary's symbols) — the same lineage already open-sourced in Swift as **McBopomofo**
and **vChewing**, including an open language model and the Viterbi-walk algorithm. So the
*engine algorithm* is a known quantity; the only genuinely risky part is obtaining an
*exact* lexicon from `KeyKey.db`.

The whole program depends on the lexicon, so this is done first as a **strictly timeboxed
spike** with a **go/no-go gate**:

1. Map the offset-table + record layout of `KeyKey.db`.
2. Extract unigram and bigram entries.
3. Emit the intermediate LM (§2.1) and load it from `KeyKeyEngine`.
4. Validate per §2.1 (structural checks + McBopomofo cross-check).

**Go/no-go gate:** if the format cannot be decoded within the timebox, the **defined
fallback** is the open **McBopomofo** language model (same engine family). This is an
explicit deviation from "exact" candidate ordering and is surfaced to the user for a
decision before proceeding. Either way, the engine and IMK path are unaffected.

---

## 5. Error handling

InputMethodKit controllers run in-process inside other applications, so the controller
**must never crash the host app**:

- LM load failure → log and **fail safe**: the controller does not crash the host and
  does not present candidates. (No alternate "passthrough" typing mode — that would be a
  second input method, out of scope.)
- Candidate-window failures never block text commit.
- All engine entry points are pure/total; no force-unwraps on data read from disk.

---

## 6. Testing

- **Engine:** unit tests against a small hand-built fixture LM, plus golden tests against
  the real extracted LM for a set of known inputs → expected top candidates.
- **Lexicon:** the structural checks + McBopomofo cross-check from §2.1.
- **IMK layer:** a headless harness that drives the engine exactly as `InputController`
  does (so engine↔controller wiring is testable without a live IMK session), plus a
  manual smoke test typing in TextEdit after installing to `~/Library/Input Methods`.

---

## 7. Notes / open items

- **IP caveat (non-blocking):** reusing Yahoo's proprietary lexicon and reproducing a
  defunct proprietary product carries IP considerations. Treated here as a personal
  preservation rewrite; flagged, not blocking.
