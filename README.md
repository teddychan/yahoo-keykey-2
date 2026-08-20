<div align="center">
  <img src="App/AppIcon.png" width="160" height="160" alt="Yahoo! KeyKey 2 app icon">
  <h1>Yahoo! KeyKey 2</h1>
  <p><strong>Cangjie (倉頡) &amp; Simplex (速成) Traditional-Chinese input method for macOS</strong></p>
</div>

**Yahoo! KeyKey 2** is an independent, open-source rebuild — in Swift — of the classic
**Yahoo! KeyKey (Yahoo!奇摩輸入法)** Traditional-Chinese input method that many Mac users
loved. It brings the familiar Cangjie (倉頡) and Simplex (速成) typing experience back to
modern macOS — native, fast, and free.

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/teddychan/yahoo-keykey-2/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2026%2B-fa4e49?style=flat-square)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/yahoo-keykey-2/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Features](#features)
- [Cangjie generation (倉頡版本)](#cangjie-generation-倉頡版本)
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
updated automatically on every release.

### Manual

1. Download the `.zip` from the
   [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest) and unzip it.
   There is no installer, so no admin password is needed.
2. Move `YahooKeyKey2.app` into `~/Library/Input Methods/` — create the folder if it is not
   there.
3. **Log out and back in.**
4. Add the input source under **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸
   Traditional Chinese** → **倉頡** and/or **速成**.
5. Press **⌃Space** to switch to Yahoo! KeyKey 2 and start typing. Space or `1–9` picks a
   candidate; the arrow keys page through them.

Not showing up? See
[known issues](known_issues.md#1-yahoo-keykey-2-does-not-show-up-after-installing).

### Update

- **In-app:** open the input menu from the menu bar and choose **檢查更新…**
- **Homebrew:** `brew upgrade --cask yahoo-keykey-2`
- **Manual:** download the newest `.zip` and replace the app

Log out and back in afterwards, so macOS reloads the input method.

### Uninstall

1. **Remove the input source first:** **System Settings ▸ Keyboard ▸ Input Sources**, select
   Yahoo! KeyKey 2 and remove it. The app's own Uninstall pane cannot do this part for you.
2. **Then remove the app** — Homebrew: `brew uninstall --cask teddychan/tap/yahoo-keykey-2`;
   otherwise open **設定… ▸ 解除安裝**, or drag `~/Library/Input Methods/YahooKeyKey2.app` to
   the Trash.
3. **Log out and back in.**

The **解除安裝** pane also clears your settings, learning data and cache. If you deleted the app
by hand and want those gone too:

```sh
rm -f  ~/Library/Preferences/com.dragonapp.inputmethod.yahoo-keykey.plist
rm -rf ~/Library/Caches/com.dragonapp.inputmethod.yahoo-keykey
rm -rf ~/Library/HTTPStorages/com.dragonapp.inputmethod.yahoo-keykey
```

## Features

- **倉頡 and 速成** — both classic modes, with `*` as a wildcard for when you cannot remember
  every radical.
- **拼音 (Pinyin)** — a third mode that builds whole phrases from pinyin without tones; `'`
  splits ambiguous syllables, so `xi'an` gives 西安.
- **Candidates that learn, or stay put** — by default the characters you pick move up the list.
  Turn **依選字習慣調整候選字順序** off in Settings and the built-in order stands, across all
  three modes and 聯想字詞 alike.
- **Associated words (聯想字詞)** — after you commit a character, KeyKey suggests the words that
  usually follow, pickable with `1–9` or `Shift + 1–9`.
- **繁 → 簡 and full-width punctuation** — toggle both straight from the input menu.
- **Candidate window that follows your cursor** — never clipped off-screen, paged with the arrow
  keys, Space or Page Up / Page Down, at whatever size you set.
- **See the code (反查／拆碼提示)** — show each candidate's 倉頡 code, or its pinyin reading.
- **臨時英數** — hold **Shift** and press a letter to type that one English letter without
  switching input source.
- **Backup and restore** — save your settings to a folder from **設定…** and bring them back
  later, handy when setting up a new Mac.
- **Free and open source** — MIT licensed, signed and notarized, with in-app updates.

> [!NOTE]
> Yahoo! KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an independent project
> that exists to honor the original work and keep a KeyKey-style experience alive on modern
> macOS.

## Cangjie generation (倉頡版本)

Choose the decomposition table in **設定… ▸ 輸入方式**. It drives both 倉頡 and 速成, and applies
immediately.

| Mode | Based on | Candidate order | Example codes |
|---|---|---|---|
| **五代倉頡** (default) | ibus `cangjie5` | corpus frequency | 面 `一田尸中`, 鬼 `竹山戈` |
| **三代倉頡** (Yahoo! KeyKey compatible) | original Yahoo! KeyKey tables | Yahoo's original order | 面 `一田卜中`, 鬼 `竹戈` |

**五代** is the default, so existing users are unaffected until they opt in. Both orders are
fixed; the learning layer sits on top and **依選字習慣調整候選字順序** turns it off — so 三代
with learning off is the original Yahoo! KeyKey order and nothing else.

Yahoo! KeyKey's *associated-phrase* ranking cannot be reproduced — that data was never
open-sourced — so associations use Yahoo! KeyKey 2's own ordering in both modes.

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
| A rare character never moves to the top | [#6](known_issues.md#6-a-rare-character-never-moves-to-the-top) |

That file also lists what has **[already been fixed](known_issues.md#7-already-fixed-in-earlier-versions)**,
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
associated phrases (聯想字詞), 拼音 segmentation, and 繁 → 簡 conversion. **KeyKeyApp** covers
preferences, key-event policy, and input-engine conformance across all three modes. CI runs both
on every push and pull request to `main`.

[![Tests](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml/badge.svg)](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml)

```bash
swift test --package-path Packages/KeyKeyEngine
swift test --package-path Packages/KeyKeyApp
```

| Metric | Value |
|---|---|
| Test cases | 281 passing (202 engine, 79 app) |
| Line coverage | 98.0% of `KeyKeyEngine`, 100% of `KeyKeyApp` |
| Measured on | v2.13.2 (`08b6f1c`), Swift 6.3.3 |

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
