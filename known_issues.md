# Known issues

Common problems and what to do about them. If yours is not here, please
[open an issue](https://github.com/teddychan/yahoo-keykey-2/issues) — say which macOS version
you are on and which mode you were typing in.

1. [Yahoo KeyKey 2 does not show up after installing](#1-yahoo-keykey-2-does-not-show-up-after-installing)
2. [倉頡 is greyed out and will not turn on](#2-倉頡-is-greyed-out-and-will-not-turn-on)
3. [A character's code is not what I expect](#3-a-characters-code-is-not-what-i-expect)
4. [Space pages instead of accepting my code](#4-space-pages-instead-of-accepting-my-code)
5. [Typing a number inserts a word instead](#5-typing-a-number-inserts-a-word-instead)
6. [A rare character never moves to the top](#6-a-rare-character-never-moves-to-the-top)
7. [Already fixed in earlier versions](#7-already-fixed-in-earlier-versions)

Also: [documentation gaps](#documentation-gaps) — things missing from these docs rather than
problems with the app.

## 1. Yahoo KeyKey 2 does not show up after installing

macOS only looks for new input methods when you log in.

**Fix:** log out and back in. Then add it under **System Settings ▸ Keyboard ▸ Input Sources ▸
+ ▸ Traditional Chinese** and pick **倉頡** and/or **速成**. Until it is on that list, **⌃Space**
has nothing to switch to.

## 2. 倉頡 is greyed out and will not turn on

Another app has switched on a macOS privacy feature called **secure input**, the one normally
used while you type a password. While it is on, macOS blocks every input method that did not
come from Apple — so 倉頡 goes grey while the U.S. keyboard keeps working.

Nothing is wrong with your installation, and no update to Yahoo KeyKey 2 can change this: only
the app that switched secure input on is able to switch it off again.

Usually that app simply forgot to turn it off after showing a password box. **1Password** is the
most common culprit — a known bug on their side, with no setting to prevent it. Chrome, Dropbox,
WeChat and similar apps can do the same.

**Fix:** quit the app holding it, and 倉頡 works again immediately — no restart and no logging
out. If you are not sure which app it is, quit them one at a time until 倉頡 lights up; trying
1Password first is a good bet, and you can reopen it straight away.

Be aware that tools claiming to name the responsible app are unreliable — they tend to report
whichever app happened to be in front when secure input was switched on, not the one holding it.

## 3. A character's code is not what I expect

**三代** and **五代** are two different Cangjie tables, and they spell some characters
differently — 面 is `一田卜中` in 三代 but `一田尸中` in 五代; 鬼 is `竹戈` versus `竹山戈`.

**Fix:** check which table is selected in **設定… ▸ 輸入方式**. Turning on **反查提示** shows
each candidate's code next to it, so you can see what the current table expects.

## 4. Space pages instead of accepting my code

In **速成**, and in **倉頡** when you use the `*` wildcard, candidates appear before you have
finished typing the code — so Space pages through them instead of confirming.

**Fix:** turn on **設定… ▸ 一般 ▸ 輸入方式 ▸ 以空白鍵確認字根**. The first Space then confirms
the code and stays on page 1, a second Space pages, and `1–9` picks.

## 5. Typing a number inserts a word instead

After you commit a character, Yahoo KeyKey 2 suggests words that commonly follow it
(**聯想字詞**), and `1–9` picks one of those suggestions.

**Fix:** in **設定… ▸ 一般**, change the 聯想 selection key to **Shift + 1–9**. A plain `1–9`
then types the digit and clears the suggestions, so numbers flow normally right after a
character.

## 6. A rare character never moves to the top

**Still open.** By default the characters you pick most often move up the candidate list, but
that only works among characters the built-in dictionary already knows. A rare character the
dictionary does not know can never overtake one it does, however many times you choose it. Under
`卜月卜尸心`, for example, 龍 is in the dictionary and the variant 㡣 is not, so 㡣 stays in
second place permanently.

This affects the candidate list only, not 聯想字詞, and roughly four in five characters in the
五代 table sit outside the dictionary. Learning still reorders such characters relative to one
another, and works normally when every character involved is known.

**Workaround:** none at present. See
[#111](https://github.com/teddychan/yahoo-keykey-2/pull/111) for the measurements.

## 7. Already fixed in earlier versions

Update if you are on an older release.

- **In 速成, typing past a two-key code got stuck** — fixed in **2.13.1**. The extra key was
  added to the finished code, emptying the candidate list.
- **三代 offered a character under the wrong code** — fixed in **2.8.0**. `人一弓口` (何) also
  offered 含, which really decomposes as `人戈弓口`. 五代 was never affected.
- **⌘C / ⌘X / ⌘V did not copy, cut or paste** — fixed in **2.7.0**. ⌘ and ⌃ combinations now
  pass through to the app instead of being read as radicals.

## Documentation gaps

Not problems with the app — things missing from these docs, recorded here so they are not
forgotten.

- **The README has no screenshots.** The
  [unified README design](docs/superpowers/specs/2026-07-25-unified-readme-design.md) gives every
  Dragon app a `## Screenshots` section above the badge row, but this repo has no `docs/images/`
  and has never had that heading — `clipmenu-2` is in the same position. Filling it needs real
  captures from an **installed release build**, not a local debug build, which would render as
  "Yahoo KeyKey 2 Debug" in the menus and About pane. Worth showing: the candidate window mid-code
  with 反查提示 on, the input menu, and the 設定… 一般 pane.
