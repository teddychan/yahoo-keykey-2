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
- A Mac with **Apple Silicon (arm64)** — there is no Intel slice
- Signed with a Developer ID and notarized by Apple, so it opens cleanly

## Install

Both channels install the same signed, notarized app into `~/Library/Input Methods/`.

### Homebrew

```sh
brew install --cask teddychan/tap/yahoo-keykey-2
```

Then **log out and back in** — macOS only registers input methods at login. The cask lives in
[teddychan/homebrew-tap](https://github.com/teddychan/homebrew-tap) and is bumped automatically
on every release.

### Manual

1. Download `YahooKeyKey2-X.Y.Z.zip` from the
   [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest) and unzip it.
   Releases ship a `.zip` — never a `.pkg` or `.dmg` — so no admin rights are needed.
2. Move `YahooKeyKey2.app` into `~/Library/Input Methods/` (create the folder if it does not
   exist).
3. **Log out and back in** — macOS only registers input methods at login.
4. Add the input source under **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸
   Traditional Chinese** → **倉頡** and/or **速成**.
5. Press **⌃Space** to switch to Yahoo KeyKey 2 and start typing.

### Update

- **In-app (both channels):** open the input menu from the input-source icon in the menu bar and
  choose **檢查更新…**. Updates arrive over Sparkle from a signed appcast at
  `https://www.dragonapp.com/yahoo-keykey-2/appcast.xml`.
- **Homebrew:** `brew upgrade --cask yahoo-keykey-2`
- **Manual:** download the newest `.zip` and replace the app in `~/Library/Input Methods/`.

Log out and back in after any update so macOS reloads the input method.

### Uninstall

1. Deactivate the input method: **System Settings ▸ Keyboard ▸ Input Sources**, select
   Yahoo KeyKey 2, and remove it.
2. Remove the app — **Homebrew:** `brew uninstall --cask teddychan/tap/yahoo-keykey-2`;
   **manual:** open **設定…** from the input menu and use the **解除安裝** pane, or delete
   `~/Library/Input Methods/YahooKeyKey2.app`.
3. Remove the leftover preferences and caches (what `brew uninstall --zap` deletes):

   ```sh
   rm -f  ~/Library/Preferences/com.dragonapp.inputmethod.yahoo-keykey.plist
   rm -rf ~/Library/Caches/com.dragonapp.inputmethod.yahoo-keykey
   rm -rf ~/Library/HTTPStorages/com.dragonapp.inputmethod.yahoo-keykey
   ```

4. Log out and back in.

## Features

- **倉頡 + 速成 input** — both classic modes, with wildcard `*` matching when you don't
  remember every radical.
- **拼音 (Pinyin) phrase input** — a third mode that composes whole phrases from toneless
  pinyin; `'` splits ambiguous syllables, so `xi'an` gives 西安.
- **Frequency-ranked &amp; adaptive** — candidates are ordered by how common they are, and
  the characters you pick rank higher over time.
- **Associated phrases (聯想字詞)** — after you commit a character, Yahoo KeyKey 2 suggests
  the words that usually follow, pickable with `1–9` or `Shift + 1–9`, and optionally showing
  only the continuation (聯想只顯示接續字).
- **繁 → 簡 &amp; full-width punctuation** — toggle Traditional-to-Simplified output (輸出簡體字)
  and full-width punctuation (全形標點) right from the input menu.
- **Native candidate window** — a vertical candidate list that follows the text caret and
  never gets clipped off-screen, paged with the arrow keys, Space, or Page Up / Page Down, at
  whatever size you set with the 候選字大小 slider.
- **反查／拆碼提示** — see the code a character decomposes to right beside the candidate: its
  倉頡 code, or its pinyin reading in 拼音.
- **以空白鍵確認字根 (optional)** — make the first Space confirm the code instead of paging, for
  速成 and for 倉頡 with the `*` wildcard. Off by default.
- **臨時英數 (quick English)** — hold **Shift** and press a letter to type that English letter
  without switching input source; the case follows Caps Lock.
- **Sync &amp; Backup** — back up your settings to a folder from **設定…** and restore them
  later, handy when setting up a new Mac.
- **Lightweight &amp; open source** — full source on GitHub, MIT licensed, Developer ID-signed
  and notarized, with in-app updates.

> [!NOTE]
> Yahoo KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an independent project
> that exists to honor the original work and keep a KeyKey-style experience alive on modern
> macOS.

## Cangjie generation (倉頡版本)

Choose the decomposition table in **設定… ▸ 輸入方式**. The choice drives both 倉頡 and
速成 and applies immediately.

| Mode | Table source | Candidate order | Example codes |
|---|---|---|---|
| **五代倉頡** (default) | ibus `cangjie5` (`Resources/cangjie.txt`) | frequency / adaptive ranking | 面 `一田尸中`, 鬼 `竹山戈` |
| **三代倉頡（Yahoo KeyKey 相容）** | original Yahoo! KeyKey `cj-ext.cin` / `simplex-ext.cin` | Yahoo's original native order | 面 `一田卜中`, 鬼 `竹戈` |

The default is **五代**, so existing users are unaffected until they opt in. Note that
Yahoo! KeyKey's *associated-phrase (關聯字表) ranking* cannot be reproduced — that data was
never open-sourced — so associations use Yahoo KeyKey 2's own ordering in both modes.

## Troubleshooting

**Yahoo KeyKey 2 doesn't appear in Input Sources.** macOS scans
`~/Library/Input Methods/` only at login, so log out and back in after installing or updating.
Then add it under **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸ Traditional Chinese**;
until it is added there, **⌃Space** has nothing to switch to.

**A character takes a code I don't recognise.** 三代 and 五代 give different codes for the same
character — 面 is `一田卜中` in 三代 but `一田尸中` in 五代, and 鬼 is `竹戈` versus `竹山戈`.
Check which table is selected in **設定… ▸ 輸入方式** (see
[Cangjie generation](#cangjie-generation-倉頡版本)), and turn on **反查提示** to see the code
beside each candidate.

**Space pages forward instead of confirming my code.** In 速成, and in 倉頡 with the `*`
wildcard, candidates appear before the code is finished, so Space paged instead of confirming.
Turn on **設定… ▸ 一般 ▸ 輸入方式 ▸ 以空白鍵確認字根**: the first Space then confirms the code
and stays on page 1, a second Space pages, and `1–9` picks.

**Typing a digit picks an associated phrase instead.** Switch the 聯想 selection key to
**Shift + 1–9** in **設定… ▸ 一般**; a plain `1–9` then types the digit and dismisses the
suggestions, so numbers flow naturally right after a character.

**⌘C / ⌘X / ⌘V don't copy, cut, or paste.** Fixed in **2.7.0** — ⌘ and ⌃ combinations now pass
through to the app instead of being read as radicals. Update if you are on an older version.

**三代 offers a character under the wrong code.** Fixed in **2.8.0** — the bundled 三代 table
carried duplicate codes from an upstream merge, so `人一弓口` (何) also offered 含, which really
decomposes as `人戈弓口`. 五代 was never affected.

## Building from source

There is no Xcode project — the app is assembled by shell scripts around `swiftc`, and the
test suites are SwiftPM packages. Requires the Xcode 26 toolchain (Swift 6.2) on Apple Silicon.

```sh
git clone https://github.com/teddychan/yahoo-keykey-2.git
cd yahoo-keykey-2
./tools/build-lm.sh    # build the language model into Resources/data.txt (first time only)
./tools/build-app.sh   # assemble + ad-hoc sign build/YahooKeyKey2.app
```

For hands-on testing, `./tools/run-debug.sh` builds and installs a separate
**Yahoo KeyKey 2 Debug** input method with its own bundle id, so it never collides with an
installed release copy. Signed release builds are produced by
[`.github/workflows/release.yml`](.github/workflows/release.yml) on a `v*` tag — see
[docs/RELEASE.md](docs/RELEASE.md).

## Tests

The suite spans two SwiftPM packages: **KeyKeyEngine** covers the 倉頡 and 速成 tables (both 五代
and 三代), code lookup and wildcard matching, frequency ranking and the adaptive walker,
associated phrases (聯想字詞), 拼音 segmentation, and 繁 → 簡 conversion; **KeyKeyApp** covers
preferences, key-event policy, and input-engine conformance across all three modes. CI runs both
on every push and pull request to `main`.

[![Tests](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml/badge.svg)](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml)

```bash
swift test --package-path Packages/KeyKeyEngine
swift test --package-path Packages/KeyKeyApp
```

| Metric | Value |
|---|---|
| Test cases | 224 passing (189 engine, 35 app) |
| Line coverage | 97.5% of `KeyKeyEngine`, 99.0% of `KeyKeyApp` |
| Measured on | v2.8.0 (`49d311d`), Swift 6.3.3 |

One further engine test (`RealPinyinWalkerTests`) skips itself unless `Resources/data.txt` has
been generated by `./tools/build-lm.sh`, so a clean checkout reports 189 passed and 1 skipped.
Coverage is measured with `--enable-code-coverage` over each package's own `Sources/`, excluding
the test files themselves and the vendored DragonKit dependency.

## Contributing

Bug reports and pull requests are welcome on the
[issue tracker](https://github.com/teddychan/yahoo-keykey-2/issues). Before opening a pull
request, run both test suites (see [Building from source](#building-from-source)) and add a
plain-language entry to [CHANGELOG.md](CHANGELOG.md) describing the user-visible change.
Release mechanics are documented in [docs/RELEASE.md](docs/RELEASE.md).

## Credits

Yahoo KeyKey 2 is built in tribute to the original **Yahoo! KeyKey (Yahoo!奇摩輸入法)**.
See [CREDITS.md](CREDITS.md) for the original projects, data sources, and engine
attributions, and [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md) for full
third-party license details.

## License

Yahoo KeyKey 2 is released under the [MIT License](LICENSE). Bundled third-party data keeps
its own permissive license — see [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md).
