# Known issues

Common problems and what to do about them. If yours is not here, please
[open an issue](https://github.com/teddychan/yahoo-keykey-2/issues) — say which macOS version
you are on and which mode you were typing in.

1. [Yahoo! KeyKey 2 does not show up after installing](#1-yahoo-keykey-2-does-not-show-up-after-installing)
2. [倉頡 is greyed out and will not turn on](#2-倉頡-is-greyed-out-and-will-not-turn-on)
3. [A character's code is not what I expect](#3-a-characters-code-is-not-what-i-expect)
4. [Space pages instead of accepting my code](#4-space-pages-instead-of-accepting-my-code)
5. [Typing a number inserts a word instead](#5-typing-a-number-inserts-a-word-instead)
6. [In 注音, the comma and period keys type ㄝ and ㄡ](#6-in-注音-the-comma-and-period-keys-type-ㄝ-and-ㄡ)
7. [In 注音, my tone key picks a candidate](#7-in-注音-my-tone-key-picks-a-candidate)
8. [Already fixed in earlier versions](#8-already-fixed-in-earlier-versions)

Also: [documentation gaps](#documentation-gaps) — things missing from these docs rather than
problems with the app.

## 1. Yahoo! KeyKey 2 does not show up after installing

macOS only looks for new input methods when you log in.

**Fix:** log out and back in. Then add it in **System Settings ▸ Keyboard**: click **Edit…**
beside **Input Sources** — the `+` is inside that sheet, not on the settings page itself — then
**+ ▸ Chinese, Traditional**, and pick **倉頡**, **速成**, **注音** and/or **拼音**. Until it is on that list, **⌃Space**
has nothing to switch to.

## 2. 倉頡 is greyed out and will not turn on

Another app has switched on a macOS privacy feature called **secure input**, the one normally
used while you type a password, and has not switched it off again. While it is on, macOS only
lets through its own input methods and the ones **installed for all users**, in
`/Library/Input Methods`. A copy of Yahoo! KeyKey 2 in your own `~/Library/Input Methods` — where
every install used to put it — goes grey, while the U.S. keyboard keeps working. That is also why
some other input methods, such as Google Japanese Input, carry on as if nothing happened: they
install for all users.

**Permanent fix (2.16.0 and later):** open **設定… ▸ 一般** and choose **為所有使用者安裝…**
(*Install for All Users…*). It asks for an administrator password once, moves Yahoo! KeyKey 2 to
`/Library/Input Methods` and restarts it, keeping your settings and everything it has learned. From
then on it keeps working whichever app turns secure input on. Each later update asks for an
administrator password too. Installed with Homebrew? Run `brew reinstall --cask yahoo-keykey-2`
instead — the cask now installs for all users.

**Right now, without changing anything:** bring the app holding secure input to the front, or quit
it. **1Password** is the most common culprit: when your Mac locks, 1Password locks itself too, and
its unlock screen can keep secure input on after you unlock the Mac. Clicking 1Password in the Dock
is usually enough — it lets go within a couple of seconds, no need to quit it. 1Password has fixed
this in its beta, 8.12.38 and later (**1Password ▸ Settings ▸ Advanced ▸ Release channel**), so the
regular release should follow. Chrome, Dropbox, WeChat and similar apps can do the same; if 1Password
is not it, quit apps one at a time until 倉頡 lights up.

While secure input is on, an all-users Yahoo! KeyKey 2 keeps typing but stops learning from what you
pick, so nothing typed then is saved; it picks up again once secure input is off.

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

After you commit a character, Yahoo! KeyKey 2 suggests words that commonly follow it
(**聯想字詞**), and `1–9` picks one of those suggestions.

**Fix:** in **設定… ▸ 一般**, change the 聯想 selection key to **Shift + 1–9**. A plain `1–9`
then types the digit and clears the suggestions, so numbers flow normally right after a
character.

## 6. In 注音, the comma and period keys type ㄝ and ㄡ

They are 注音 keys. On the **標準（大千）** keyboard the symbols ㄝ ㄡ ㄤ ㄥ ㄦ sit on `,` `.` `;`
`/` `-`, so in 注音 those keys have to type 注音 — otherwise no character whose reading starts
with one of them (兒, 偶, 昂…) could be typed at all.

**Fix:** use the shifted keys, where the original Yahoo! KeyKey put them: **Shift + `,`** types
，and **Shift + `.`** types 。 In 大千, `'` types 、 and **Shift + `'`** types ；. 「」『』？！：
are on their usual keys, which 注音 does not use. Nothing changes in 倉頡, 速成 or 拼音.

## 7. In 注音, my tone key picks a candidate

Once a tone has finished the syllable, the candidate window is open — and while it is open,
`1–9` picks a candidate, which is what those keys have always done in this app and in ㄅ半
itself. On 大千 the tone keys are `3` `4` `6` `7`, so a second tone press lands on a row instead
of correcting the tone.

A number whose row is empty is not a pick: since 2.16.2 it types 注音, so after a list shorter
than that number a tone key does correct the tone, and ㄅ ㄉ ㄓ ㄚ ㄞ start the next character.

**Fix:** press **Backspace** once. That removes the tone and leaves the symbols you typed, so you
can enter the right tone. (Before any tone is typed there is no candidate window, so the number
row types 注音 normally.) For the same reason, 聯想字詞 is picked with **Shift + 1–9** in 注音
whatever **聯想選字鍵** is set to, leaving a bare number free to type ㄅ ㄉ ㄓ ㄚ ㄞ ㄢ.

## 8. Already fixed in earlier versions

Update if you are on an older release.

- **A rare character never moved to the top in 倉頡 or 速成** — fixed in **2.13.4**. Choosing a
  character used to be mixed with how common the built-in dictionary considers it, so a character
  the dictionary does not know could never overtake one it does, however many times you chose it:
  under `卜月卜尸心`, 龍 is in the dictionary and the variant 㡣 is not, so 㡣 stayed second
  permanently. Each 倉頡/速成 candidate list (and each 聯想字詞 list) is now counted on its own and
  the count decides the order, so picking 㡣 once puts it first. That learning starts fresh in
  2.13.4 — the previous counts recorded no candidate list and could not be carried over. 拼音
  ranking is unchanged.
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
  "Yahoo! KeyKey 2 Debug" in the menus and About pane. Worth showing: the candidate window mid-code
  with 反查提示 on, the input menu, and the 設定… 一般 pane.
