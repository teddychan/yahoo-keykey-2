<div align="center">
  <img src="App/AppIcon.png" width="160" height="160" alt="Yahoo KeyKey 2 app icon">
  <h1>Yahoo KeyKey 2</h1>
  <p><strong>Cangjie (倉頡) &amp; Simplex (速成) Traditional-Chinese input method for macOS</strong></p>
</div>

**Yahoo KeyKey 2** is an independent, open-source rebuild — in Swift — of the classic
**Yahoo! KeyKey (Yahoo!奇摩輸入法)** Traditional-Chinese input method that many Mac users
loved. It brings the familiar Cangjie (倉頡) and Simplex (速成) typing experience back to
modern macOS — native, fast, and free.

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/teddychan/yahoo-keykey-2/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2026%2B-fa4e49?style=flat-square)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/yahoo-keykey-2/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

> [!NOTE]
> Yahoo KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an independent project
> that exists to honor the original work and keep a KeyKey-style experience alive on modern
> macOS.

## Contents

1. [Requirements](#1-requirements)
2. [Install](#2-install)
3. [Features](#3-features)
4. [Cangjie generation (倉頡版本)](#4-cangjie-generation-倉頡版本)
5. [Update & uninstall](#5-update--uninstall)
6. [Help](#6-help)
7. [For developers](#7-for-developers)
8. [Credits & license](#8-credits--license)

## 1. Requirements

- **macOS 26 Tahoe** or later
- A Mac with **Apple Silicon** — there is no Intel version
- Signed with a Developer ID and notarized by Apple, so it opens without warnings

## 2. Install

> [!IMPORTANT]
> Whichever way you install, **log out and back in afterwards**. macOS only looks for new input
> methods when you log in — this is the single most common reason KeyKey seems not to work.

**Homebrew**

```sh
brew install --cask teddychan/tap/yahoo-keykey-2
```

The cask lives in [teddychan/homebrew-tap](https://github.com/teddychan/homebrew-tap) and is
updated automatically on every release.

**Manual**

1. Download the `.zip` from the
   [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest) and unzip it.
   There is no installer, so no admin password is needed.
2. Move `YahooKeyKey2.app` into `~/Library/Input Methods/` — create the folder if it is not
   there.
3. **Log out and back in.**
4. Add the input source under **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸
   Traditional Chinese** → **倉頡** and/or **速成**.
5. Press **⌃Space** to switch to Yahoo KeyKey 2 and start typing. Space or `1–9` picks a
   candidate; the arrow keys page through them.

Not showing up? See [known issues](known_issues.md#1-yahoo-keykey-2-does-not-show-up-after-installing).

## 3. Features

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

## 4. Cangjie generation (倉頡版本)

Choose the decomposition table in **設定… ▸ 輸入方式**. It drives both 倉頡 and 速成, and applies
immediately.

| Mode | Based on | Candidate order | Example codes |
|---|---|---|---|
| **五代倉頡** (default) | ibus `cangjie5` | corpus frequency | 面 `一田尸中`, 鬼 `竹山戈` |
| **三代倉頡** (Yahoo KeyKey compatible) | original Yahoo! KeyKey tables | Yahoo's original order | 面 `一田卜中`, 鬼 `竹戈` |

**五代** is the default, so existing users are unaffected until they opt in. Both orders are
fixed; the learning layer sits on top and **依選字習慣調整候選字順序** turns it off — so 三代
with learning off is the original Yahoo! KeyKey order and nothing else.

Yahoo! KeyKey's *associated-phrase* ranking cannot be reproduced — that data was never
open-sourced — so associations use Yahoo KeyKey 2's own ordering in both modes.

## 5. Update & uninstall

**Update** — then log out and back in.

- **In-app:** open the input menu from the menu bar and choose **檢查更新…**
- **Homebrew:** `brew upgrade --cask yahoo-keykey-2`
- **Manual:** download the newest `.zip` and replace the app

**Uninstall**

1. **Remove the input source first:** **System Settings ▸ Keyboard ▸ Input Sources**, select
   Yahoo KeyKey 2 and remove it. The app's own Uninstall pane cannot do this part for you.
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

## 6. Help

**[Known issues →](known_issues.md)** covers the problems people hit most often:

| Problem | |
|---|---|
| It does not show up after installing | [#1](known_issues.md#1-yahoo-keykey-2-does-not-show-up-after-installing) |
| 倉頡 is greyed out and will not turn on | [#2](known_issues.md#2-倉頡-is-greyed-out-and-will-not-turn-on) |
| A character's code is not what you expect | [#3](known_issues.md#3-a-characters-code-is-not-what-i-expect) |
| Space pages instead of accepting your code | [#4](known_issues.md#4-space-pages-instead-of-accepting-my-code) |
| Typing a number inserts a word | [#5](known_issues.md#5-typing-a-number-inserts-a-word-instead) |

Anything else — [open an issue](https://github.com/teddychan/yahoo-keykey-2/issues). What
changed in each release is in [CHANGELOG.md](CHANGELOG.md).

## 7. For developers

There is no Xcode project: the app is assembled by shell scripts around `swiftc`, and the test
suites are SwiftPM packages. Requires the **Xcode 26 toolchain** on Apple Silicon.

```sh
git clone https://github.com/teddychan/yahoo-keykey-2.git
cd yahoo-keykey-2
./tools/build-lm.sh    # build the language model (first time only)
./tools/build-app.sh   # assemble + ad-hoc sign build/YahooKeyKey2.app
```

[![Tests](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml/badge.svg)](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml)

```sh
swift test --package-path Packages/KeyKeyEngine   # tables, ranking, 拼音, 繁→簡
swift test --package-path Packages/KeyKeyApp      # preferences, key handling, engine conformance
```

`RealPinyinWalkerTests` skips itself until `./tools/build-lm.sh` has run, so a clean checkout
reports one skipped test.

- **Local testing:** `./tools/run-debug.sh` installs a separate **Yahoo KeyKey 2 Debug** input
  method with its own bundle id, so it never collides with an installed release copy.
- **Releases, versioning and signing:** [docs/RELEASE.md](docs/RELEASE.md). Signed builds come
  from [`.github/workflows/release.yml`](.github/workflows/release.yml) on a `v*` tag.
- **Contributing:** run both test suites, and add a plain-language
  [CHANGELOG.md](CHANGELOG.md) entry describing the user-visible change. Bug reports and pull
  requests are welcome on the [issue tracker](https://github.com/teddychan/yahoo-keykey-2/issues).

## 8. Credits & license

Built in tribute to the original **Yahoo! KeyKey (Yahoo!奇摩輸入法)**. See
[CREDITS.md](CREDITS.md) for the original projects, data sources and engine attributions.

Released under the [MIT License](LICENSE). Bundled third-party data keeps its own permissive
license — see [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md).
