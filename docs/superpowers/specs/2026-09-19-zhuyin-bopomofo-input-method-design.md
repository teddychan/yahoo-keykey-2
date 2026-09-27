# Design: 注音 (ㄅ半) Input Method for Yahoo! KeyKey 2

**Date:** 2026-09-19
**Status:** Implemented (2.14.0)
**Target stack:** Swift + InputMethodKit + AppKit/SwiftUI, macOS (arm64)

---

## 0. Background & context

The original Yahoo! KeyKey shipped **注音**, and for most of its users that meant **ㄅ半** — the
classic, non-predictive phonetic method: type the 注音 symbols for one character, end the syllable
with a tone, pick the character from a numbered list, repeat. The Swift rebuild shipped 倉頡, 速成
and 拼音, so a lifelong ㄅ半 typist had nothing to move to when the original stopped working on a
current macOS.

This adds 注音 as a fourth input method. It is deliberately **ㄅ半 and not 新注音**: no
sentence-level conversion, no phrase engine, one syllable at a time.

### Why not the 拼音 engine with a bopomofo front end

拼音 (2.13.x) already walks the McBopomofo language model to build whole phrases, and a bopomofo
front end for it would be a small change. It is the wrong product, for two reasons:

1. **ㄅ半 is the request and the muscle memory.** A typist who has used it for decades chooses each
   character; a sentence engine that guesses and needs correcting is a different instrument.
2. **Tone.** 拼音 v1 is toneless and ranks over a tone-stripped index. ㄅ半 is tone-exact: `ㄕ` and
   `ㄕˋ` are different lists, and typing the tone is half of the method.

So 注音 is a **single-character engine**, shaped like `CangjieEngine`/`SimplexEngine` — which also
means it inherits 聯想字詞, adaptive candidate ordering, 反查提示, 繁→簡 and the candidate window
with no new work in any of them.

## 1. Data: the original ㄅ半 table, not the language model

Candidates come from `Resources/zhuyin-yahoo.txt`, converted from
`DataTables/bpmf-ext.cin` in the open-sourced Yahoo! KeyKey release — the **same release and the
same "large character set" lineage** as the 三代 tables this app already bundles, and the table
the ㄅ半 method was built around. Provenance, licence and the exact conversion are recorded in
`Resources/ZHUYIN-DATA-LICENSE.txt`; the generator is `tools/build-zhuyin-table.py`.

**Keyed by reading, not by keystrokes.** A `.cin` row is keyed by the key sequence a 大千 typist
presses (`su3`). Storing that would hard-wire one keyboard into the data, so every row is
translated through the table's own `%keyname` map into the reading it spells (`ㄋㄧˇ`). The
keyboard layout then stays a pure key→symbol map that can vary per user, and both layouts share
one table — and one set of learned counts.

**Tone convention:** first tone unmarked, every other tone a suffix (`ㄋㄧˇ`, `ㄉㄜ˙`). This is the
source table's own convention and McBopomofo's, so a reading built by the engine is a lookup key
in either.

**No language-model re-ranking.** The table's own line order is the built-in candidate order, as
三代倉頡's is for 倉頡. Checked against the real table: the everyday character leads its reading
(ㄍㄨㄛˊ → 國, ㄉㄜ˙ → 的, ㄨㄛˇ → 我, ㄖㄣˊ → 人). The alternative — the existing global
`characterRank` — would answer a 破音字 reading with the character's commonest *other* reading
(的 would lead `ㄉㄧˊ`), and a per-reading toned index means parsing the 7 MB model for a table we
already have. Learning applies on top, per reading.

**Loading.** ~1.2 MB of text, ~35k characters after the renderable filter, built on FIRST USE in
`SharedResources` and kept. Not at launch (a 倉頡 user should not pay for it) and not ref-counted
like the 拼音 index (it is nowhere near the 55–80 MB that made releasing that one worthwhile).

## 2. Engine

Three small types, all in `KeyKeyEngine`:

- **`ZhuyinKeyboardLayout`** — key → symbol, `.dachen` (transcribed from the bundled table's own
  `%keyname`) and `.eten` (from McBopomofo's `CreateETenLayout()`). 許氏 and the 26-key layouts are
  out of scope: they put two symbols on one key and need disambiguation rules this engine does not
  have. A test asserts each layout types every symbol and every tone exactly once.
- **`ZhuyinSyllable`** — four slots (initial, medial, final, tone). A symbol writes its own slot,
  replacing what was there (typing ㄆ after ㄅ corrects the initial), and the parts always read in
  canonical order however they were typed. Backspace clears the last-written part.
- **`ZhuyinEngine`** — the `InputEngine` surface, plus two methods the controller reaches by cast.

### Candidates appear only after a tone

This is the classic behaviour, and it is also what keeps the keyboard usable: on 大千 the tone keys
are `3` `4` `6` `7` and six more digits are symbols, while `1–9` pick candidates whenever the
window is open. If the window opened before the tone, the tone could never be typed.

Consequences, both documented in `known_issues.md`: a mis-typed tone is fixed with Backspace rather
than by pressing another tone key, and 聯想字詞 needs Shift + a number (§3).

### Two rules that belong to the controller

Both must commit into the client, which only `InputController` can do:

- **Space is the first-tone key** (`applyFirstTone()`), the one tone with no key of its own. It
  answers false for an empty buffer and for an already-finished syllable, so Space keeps its paging,
  commit and literal-space meanings untouched.
- **A 注音 key against a finished syllable starts the next character**
  (`keyStartsNewComposition(_:)`), so a sentence runs on without Enter. Exactly the shape of
  `SimplexEngine.keyStartsNewComposition(_:)` (issue #113). A *tone* key is excluded — that is a
  correction to the syllable just finished.

## 3. Controller integration

Four branches in `handle()`, each guarded by a cast so no other method is affected:

1. **Punctuation.** 全形標點 must not claim the keys 注音 needs: on 大千, ㄝ ㄡ ㄤ ㄥ ㄦ sit on
   `,` `.` `;` `/` `-`, and without this 兒/偶/昂 would be untypable. 注音 wins on any key its
   layout maps (McBopomofo resolves it the same way), and the marks those keys carry move to their
   shifted forms — `<` → ，, `>` → 。 — transcribed from the original Yahoo! KeyKey's own
   `bpmf-punctuations.cin` (`ZhuyinPunctuation`).
2. **Space** → `applyFirstTone()`.
3. **A 注音 key ending a finished syllable** → commit the page's first candidate, then compose on.
4. **聯想字詞 selection** → `KeyEventPolicy.effectiveAssociationTrigger` forces Shift + 1–9 in 注音,
   whatever 聯想選字鍵 says, because a bare digit there is a 注音 keystroke the user means. Every
   other method keeps the configured trigger.

## 4. Learning

`CandidateListKey.zhuyin(reading:)` — a new case, so a reading's list is learned on its own,
exactly as a 倉頡 code is, under the one 依選字習慣調整候選字順序 setting. The layout is **not** part
of the identity: 大千 and 倚天 are two ways to type the same ㄕˋ and must share what they learn.
No table version either — one ㄅ半 table ships.

## 5. Settings

`Preferences.zhuyinLayout`, defaulting to 大千 (the layout on a Taiwanese keyboard, and the original
Yahoo! KeyKey's default). It is typed as the engine's own `ZhuyinKeyboardLayout.Identifier` rather
than a second app-level enum over the same raw strings. Changing it — from 設定… ▸ 輸入方式 or from
the input menu's method-specific zone, which this is the first method to use — posts
`.zhuyinLayoutChanged`, and every live controller rebuilds its engine, so the next keystroke uses
the new keyboard.

## 6. What is deliberately not here

- **許氏 / 倚天26 / IBM layouts** — multi-symbol keys, as above.
- **Phrase or sentence input in 注音** — that is 新注音, not ㄅ半; 拼音 is the phrase engine.
- **A 注音 code hint** — 反查提示 keeps showing the 倉頡 code in 注音, which is the more useful
  direction (type it phonetically, learn how to type it in 倉頡).
- **Ctrl + punctuation and the `` ` `` punctuation list** (McBopomofo has both) — the shifted keys
  cover ，。、；：？！ and ⌃ is reserved for app shortcuts (issue #56).
