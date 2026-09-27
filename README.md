<div align="center">
  <img src="App/AppIcon.png" width="160" height="160" alt="Yahoo! KeyKey 2 app icon">
  <h1>Yahoo! KeyKey 2</h1>
  <p><strong>Four Traditional-Chinese input methods for macOS: Cangjie (倉頡), Simplex (速成), Zhuyin (注音) &amp; Pinyin (拼音)</strong></p>
</div>

**Yahoo! KeyKey 2** is an independent, open-source rebuild — in Swift — of the classic
**Yahoo! KeyKey (Yahoo!奇摩輸入法)** Traditional-Chinese input method that many Mac users
loved. It brings that typing experience back to modern macOS with four input methods — **倉頡**
(Cangjie), **速成** (Simplex), **注音** (Zhuyin, ㄅ半) and **拼音** (Pinyin) — native, fast, and
free.

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/teddychan/yahoo-keykey-2/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2026%2B-fa4e49?style=flat-square)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/yahoo-keykey-2/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Features](#features)
- [Input methods](#input-methods)
- [Troubleshooting](#troubleshooting)
- [Building from source](#building-from-source)
- [Tests](#tests)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

## Requirements

- **macOS 26 Tahoe** or later
- A Mac with **Apple Silicon** — there is no Intel version
- Signed with a Developer ID and notarized by Apple, so it opens without warnings

## Install

> [!IMPORTANT]
> Whichever way you install, **log out and back in afterwards**. macOS only looks for new input
> methods when you log in — this is the most common reason KeyKey seems not to work.

### Homebrew

```sh
brew install --cask teddychan/tap/yahoo-keykey-2
```

The cask lives in [teddychan/homebrew-tap](https://github.com/teddychan/homebrew-tap) and is
updated automatically on every release. It installs for all users, in `/Library/Input Methods`, so
Homebrew asks for your password — that is what keeps Yahoo! KeyKey 2 working when another app turns
on secure input (see [known issue #2](known_issues.md#2-倉頡-is-greyed-out-and-will-not-turn-on)).

### Manual

1. Download the `.zip` from the
   [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest) and unzip it.
   There is no installer, so no admin password is needed to get started.
2. Move `YahooKeyKey2.app` into `~/Library/Input Methods/` — create the folder if it is not
   there.
3. **Log out and back in.**
4. Add the input source: **System Settings ▸ Keyboard**, then **Edit…** beside **Input Sources**
   (the `+` is inside that sheet, not on the settings page), **+ ▸ Chinese, Traditional** →
   **倉頡**, **速成**, **注音** and/or **拼音**.
5. Press **⌃Space** to switch to Yahoo! KeyKey 2 and start typing. Space or `1–9` picks a
   candidate; the arrow keys page through them.
6. **Recommended:** open **設定… ▸ 一般** and choose **為所有使用者安裝…** (*Install for All
   Users…*). After asking for an administrator password it moves itself to
   `/Library/Input Methods`, so it keeps working when another app, such as 1Password, turns on
   secure input — see [known issue #2](known_issues.md#2-倉頡-is-greyed-out-and-will-not-turn-on).

Not showing up? See
[known issues](known_issues.md#1-yahoo-keykey-2-does-not-show-up-after-installing).

### Update

- **In-app:** open the input menu from the menu bar and choose **檢查更新…**
- **Homebrew:** `brew upgrade --cask yahoo-keykey-2`. A copy Homebrew installed before 2.16.0
  stays in `~/Library/Input Methods` until you run `brew reinstall --cask yahoo-keykey-2` once,
  which moves it to `/Library/Input Methods`.
- **Manual:** download the newest `.zip` and replace the app in `~/Library/Input Methods`.
  Installed for all users? Update with **檢查更新…** instead — copying the zip's app into
  `~/Library/Input Methods`, as its `Install.txt` says, would leave a second copy.

Log out and back in afterwards, so macOS reloads the input method. Installed for all users, each
update asks for an administrator password.

### Uninstall

1. **Remove the input source first:** **System Settings ▸ Keyboard ▸ Input Sources**, select
   Yahoo! KeyKey 2 and remove it. The app's own Uninstall pane cannot do this part for you.
2. **Then remove the app** — Homebrew: `brew uninstall --cask teddychan/tap/yahoo-keykey-2`;
   otherwise open **設定… ▸ 解除安裝**, or drag `~/Library/Input Methods/YahooKeyKey2.app` — or,
   installed for all users, `/Library/Input Methods/YahooKeyKey2.app` — to the Trash (Finder asks
   for an administrator password for the all-users copy).
3. **Log out and back in.**

The **解除安裝** pane also clears your settings, learning data and cache. If you deleted the app
by hand and want those gone too:

```sh
rm -f  ~/Library/Preferences/com.dragonapp.inputmethod.yahoo-keykey.plist
rm -rf ~/Library/Caches/com.dragonapp.inputmethod.yahoo-keykey
rm -rf ~/Library/HTTPStorages/com.dragonapp.inputmethod.yahoo-keykey
```

## Features

- **Four input methods** — add the ones you use under Input Sources and switch with ⌃Space.
  See [Input methods](#input-methods) for how each one types.
  - **倉頡 (Cangjie)** — the classic radical method, with `*` as a wildcard for when you cannot
    remember every radical.
  - **速成 (Simplex)** — 倉頡's shorthand: just the first and last radical.
  - **注音 (Zhuyin, ㄅ半)** — the classic phonetic method, one character at a time. 標準 (大千) and
    倚天 keyboards.
  - **拼音 (Pinyin)** — builds whole phrases from pinyin without tones.
- **Candidates that learn, or stay put** — by default the characters you pick move up the list.
  Turn **依選字習慣調整候選字順序** off in Settings and the built-in order stands, in all four
  input methods and 聯想字詞 alike.
- **Associated words (聯想字詞)** — after you commit a character, KeyKey suggests the words that
  usually follow, pickable with `1–9` or `Shift + 1–9`.
- **繁 → 簡 and full-width punctuation** — toggle both straight from the input menu.
- **Candidate window that follows your cursor** — never clipped off-screen, paged with the arrow
  keys, Space or Page Up / Page Down, at whatever size you set.
- **See the code (反查／拆碼提示)** — show each candidate's 倉頡 code, or its pinyin reading — so
  in 注音 you can look up how to type the same character in 倉頡.
- **臨時英數** — hold **Shift** and press a letter to type that one English letter without
  switching input source.
- **全形空白** — turn on **Shift + 空白鍵輸入全形空白** in Settings and **Shift + Space** types a
  full-width space (　) in all four input methods.
- **Backup and restore** — save your settings to a folder from **設定…** and bring them back
  later, handy when setting up a new Mac.
- **Free and open source** — MIT licensed, signed and notarized, with in-app updates.

> [!NOTE]
> Yahoo! KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an independent project
> that exists to honor the original work and keep a KeyKey-style experience alive on modern
> macOS.

## Input methods

Yahoo! KeyKey 2 installs **four input methods**. Each one is a separate entry under **Input
Sources** (Chinese, Traditional), so add only the ones you use and switch between them with
**⌃Space**.

| Input method | How you type | Its own setting (設定… ▸ 輸入方式) |
|---|---|---|
| **倉頡** (Cangjie) | 倉頡 radicals on the letter keys; `*` is a wildcard | **倉頡版本** — 五代 or 三代 |
| **速成** (Simplex) | the first and last radical of a character's 倉頡 code | follows **倉頡版本** |
| **注音** (Zhuyin, ㄅ半) | 注音 symbols, then a tone — one character at a time | **注音鍵盤** — 大千 or 倚天 |
| **拼音** (Pinyin) | pinyin without tones — whole phrases at once | — |

繁 → 簡, full-width punctuation, 反查提示 and **依選字習慣調整候選字順序** apply to all four.

### 倉頡 and 速成: 倉頡版本

Choose the decomposition table in **設定… ▸ 輸入方式**. It drives both 倉頡 and 速成, and applies
immediately.

| Mode | Based on | Candidate order | Example codes |
|---|---|---|---|
| **五代倉頡** (default) | ibus `cangjie5` | corpus frequency | 面 `一田尸中`, 鬼 `竹山戈` |
| **三代倉頡** (Yahoo! KeyKey compatible) | original Yahoo! KeyKey tables | Yahoo's original order | 面 `一田卜中`, 鬼 `竹戈` |

**五代** is the default, so existing users are unaffected until they opt in. Both orders are
fixed, and in 倉頡/速成 each is the tie-breaker rather than a score the learning layer adjusts:
with **依選字習慣調整候選字順序** on, every candidate list is ordered by how often you have
committed each candidate *in that list*, and the table order decides between candidates you have
committed equally often. Turning it off shows the table order alone — so 三代 with learning off is
the original Yahoo! KeyKey order and nothing else. Usage is counted per candidate list, so a 倉頡
code, a 倉頡 wildcard pattern and a 速成 code each learn separately, while 倉頡 and 速成 share
what they learn about 聯想字詞. 拼音 is outside that scheme: it ranks candidates as it always has,
and the same setting turns its learning on and off.

Yahoo! KeyKey's *associated-phrase* ranking cannot be reproduced — that data was never
open-sourced — so associations use Yahoo! KeyKey 2's own ordering in both modes.

### 注音 (ㄅ半)

The **ㄅ半** method, as it has always worked: one syllable, one character. Type the 注音 symbols,
finish the syllable with a tone, and the candidate window opens; `1–9` picks, Space and the arrow
keys page, and typing the next character's first symbol commits the one on screen so you can run
on without pressing Enter. 聯想字詞 follows every commit, exactly as in 倉頡 and 速成.

| | |
|---|---|
| **First tone** | **Space** — the one tone with no key of its own |
| **Other tones** | 大千 `6` ˊ · `3` ˇ · `4` ˋ · `7` ˙  ·  倚天 `2` ˊ · `3` ˇ · `4` ˋ · `1` ˙ |
| **Pick a candidate** | `1–9` · **Return** takes the first on the page · Space pages (and takes the first when there is only one page) |
| **Fix a wrong tone** | **Backspace** removes the tone and leaves the symbols |
| **聯想字詞** | **Shift + 1–9** (a bare number types 注音, so it cannot also pick) |
| **，。** | **Shift + `,`** and **Shift + `.`** — `,` and `.` themselves type ㄝ and ㄡ |

Choose the keyboard in **設定… ▸ 輸入方式 ▸ 注音鍵盤**, or straight from the input menu while 注音
is active. **標準（大千）** is the default: the layout printed on Taiwanese keyboards, and the one
the original Yahoo! KeyKey shipped. **倚天** puts the symbols on the letters that spell them.
許氏 and the 26-key layouts are not offered — they put two symbols on one key, which needs
disambiguation rules this mode does not have.

Candidates come from the original Yahoo! KeyKey ㄅ半 table (`bpmf-ext.cin`), in its own order —
the everyday character for a reading leads it, and there is no dictionary re-ranking on top. What
you pick is then learned per reading, the same way 倉頡 learns per code.

### 拼音 (Pinyin)

Type pinyin without tones and 拼音 builds the whole phrase; `'` splits an ambiguous spot, so
`xi'an` gives 西安. The arrow keys move between syllables, `1–9` picks the candidate for the
syllable under the cursor and moves on to the next, and Space or Return commits the whole phrase.

## Troubleshooting

Common problems, and what each one turns out to be, are collected in
**[known_issues.md](known_issues.md)**:

| Problem | |
|---|---|
| It does not show up after installing | [#1](known_issues.md#1-yahoo-keykey-2-does-not-show-up-after-installing) |
| 倉頡 is greyed out and will not turn on | [#2](known_issues.md#2-倉頡-is-greyed-out-and-will-not-turn-on) |
| A character's code is not what you expect | [#3](known_issues.md#3-a-characters-code-is-not-what-i-expect) |
| Space pages instead of accepting your code | [#4](known_issues.md#4-space-pages-instead-of-accepting-my-code) |
| Typing a number inserts a word | [#5](known_issues.md#5-typing-a-number-inserts-a-word-instead) |
| In 注音, `,` and `.` type ㄝ and ㄡ | [#6](known_issues.md#6-in-注音-the-comma-and-period-keys-type-ㄝ-and-ㄡ) |
| In 注音, a tone key picks a candidate | [#7](known_issues.md#7-in-注音-my-tone-key-picks-a-candidate) |

That file also lists what has **[already been fixed](known_issues.md#8-already-fixed-in-earlier-versions)**,
so check your version before reporting a bug. Anything else —
[open an issue](https://github.com/teddychan/yahoo-keykey-2/issues).

## Building from source

There is no Xcode project: the app is assembled by shell scripts around `swiftc`, and the test
suites are SwiftPM packages. Requires the **Xcode 26 toolchain** on Apple Silicon.

```sh
git clone https://github.com/teddychan/yahoo-keykey-2.git
cd yahoo-keykey-2
./tools/build-lm.sh    # build the language model into Resources/data.txt (first time only)
./tools/build-app.sh   # assemble + ad-hoc sign build/YahooKeyKey2.app
```

For hands-on testing, `./tools/run-debug.sh` builds and installs a separate
**Yahoo! KeyKey 2 Debug** input method with its own bundle id, so it never collides with an
installed release copy. It reports the **target version** — the release being developed toward —
so a fix for 2.13.0 builds as `v2.13.1 Debug` and no modified code ever wears a released number.
See [Versioning convention](docs/RELEASE.md#versioning-convention). Signed release builds come
from [`.github/workflows/release.yml`](.github/workflows/release.yml) on a `v*` tag — see
[docs/RELEASE.md](docs/RELEASE.md).

## Tests

The suite spans two SwiftPM packages. **KeyKeyEngine** covers the 倉頡 and 速成 tables (both 五代
and 三代), code lookup and wildcard matching, frequency ranking and the adaptive walker,
associated phrases (聯想字詞), 注音 keyboards / syllable building / the ㄅ半 table, 拼音
segmentation, and 繁 → 簡 conversion. **KeyKeyApp** covers preferences, key-event policy, and
input-engine conformance across all four modes. CI runs both
on every push and pull request to `main`.

[![Tests](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml/badge.svg)](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml)

```bash
swift test --package-path Packages/KeyKeyEngine
swift test --package-path Packages/KeyKeyApp
```

| Metric | Value |
|---|---|
| Test cases | 459 passing (334 engine, 125 app) |
| Line coverage | 97.8% of `KeyKeyEngine`, 95.8% of `KeyKeyApp` |
| Measured on | v2.16.0, Swift 6.4 |

One further engine test (`RealPinyinWalkerTests`) skips itself unless `Resources/data.txt` has
been generated by `./tools/build-lm.sh`. Coverage is measured with `--enable-code-coverage` over
each package's own `Sources/`, excluding the test files themselves and the vendored DragonKit
dependency.

## Contributing

Bug reports and pull requests are welcome on the
[issue tracker](https://github.com/teddychan/yahoo-keykey-2/issues). Before opening a pull
request, run both test suites (see [Building from source](#building-from-source)) and add a
plain-language entry to [CHANGELOG.md](CHANGELOG.md) describing the user-visible change.
Release mechanics are documented in [docs/RELEASE.md](docs/RELEASE.md).

## Credits

Yahoo! KeyKey 2 is built in tribute to the original **Yahoo! KeyKey (Yahoo!奇摩輸入法)**.
See [CREDITS.md](CREDITS.md) for the original projects, data sources, and engine
attributions, and [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md) for full
third-party license details.

## License

Yahoo! KeyKey 2 is released under the [MIT License](LICENSE). Bundled third-party data keeps
its own permissive license — see [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md).
