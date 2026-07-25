<div align="center">
  <img src="App/AppIcon.png" width="160" height="160" alt="Yahoo KeyKey 2 app icon">
  <h1>Yahoo KeyKey 2</h1>
  <p><strong>Cangjie (倉頡) &amp; Simplex (速成) Traditional-Chinese input method for macOS</strong></p>
</div>

**Yahoo KeyKey 2** is an independent, open-source rebuild — in Swift — of the classic
**Yahoo! KeyKey (Yahoo!奇摩輸入法)** Traditional-Chinese input method that many Mac users
loved. It brings the familiar Cangjie (倉頡) and Simplex (速成) typing experience back to
modern macOS — native, fast, and free.

[![Latest release](https://img.shields.io/github/v/release/teddychan/yahoo-keykey-2?style=flat-square&label=download&color=brightgreen)](https://github.com/teddychan/yahoo-keykey-2/releases/latest)
[![Homebrew](https://img.shields.io/badge/homebrew-teddychan%2Ftap-orange?style=flat-square)](#homebrew-recommended)
[![Tests](https://img.shields.io/github/actions/workflow/status/teddychan/yahoo-keykey-2/tests.yml?branch=main&style=flat-square&label=tests)](https://github.com/teddychan/yahoo-keykey-2/actions/workflows/tests.yml)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-blue?style=flat-square)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-blue?style=flat-square)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/yahoo-keykey-2/)

> **Note:** Yahoo KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an
> independent project that exists to honor the original work and keep a KeyKey-style
> experience alive on modern macOS.

## What's new in 2.8.0

- **Press Space to confirm the code (new option).** In **速成**, and in **倉頡** with the `*`
  wildcard, candidates show up before your code is finished — so **Space** paged forward instead
  of confirming what you typed. Turn on **設定… ▸ 一般 ▸ 輸入方式 ▸ 以空白鍵確認字根** and the first
  Space confirms the code and stays on page 1; press Space again to page, or **1–9** to pick.
  Off by default, and plain 倉頡 is unaffected.
- **Fixed: 三代倉頡 offered characters under the wrong code.** Typing `人一弓口` (何's code) also
  offered 含, which really decomposes as `人戈弓口`. The bundled 三代 table carried ~800 duplicate
  codes from an upstream merge; those are gone, Yahoo's original candidate order is untouched,
  and **五代倉頡 was never affected**.

Recently before that: **Page Up / Page Down paging** in both candidate windows, a configurable
**聯想 selection key** (`1–9` or `Shift + 1–9`), and **⌘/⌃ shortcuts passing through** to the app
so ⌘C / ⌘X / ⌘V work normally. Full history in [CHANGELOG.md](CHANGELOG.md).

## Features

- **倉頡 + 速成 input** — both classic modes, with wildcard `*` matching when you don't
  remember every radical.
- **Frequency-ranked &amp; adaptive** — candidates are ordered by how common they are, and
  the characters you pick rank higher over time.
- **Associated phrases (聯想字詞)** — after you commit a character, Yahoo KeyKey 2 suggests
  the words that usually follow, pickable with `1–9` or `Shift + 1–9`.
- **繁 → 簡 &amp; full-width punctuation** — toggle Traditional-to-Simplified output (輸出簡體字)
  and full-width punctuation (全形標點) right from the input menu.
- **Native candidate window** — a vertical candidate list that follows the text caret and
  never gets clipped off-screen, with arrow-key, Space, and Page Up / Page Down paging.
- **反查／拆碼提示** — see the code a character decomposes to, right beside the candidate.
- **Lightweight &amp; open source** — full source on GitHub, MIT licensed, Developer ID-signed
  and notarized, with in-app updates.

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

## Requirements

- A Mac with **Apple Silicon (arm64)**
- **macOS 26 Tahoe** or later
- Signed with a Developer ID and notarized by Apple, so it opens cleanly

## Install

Pick either channel below — both install the same signed, notarized app into
`~/Library/Input Methods/`. Then follow **[Finish setup](#finish-setup)**.

### Homebrew (recommended)

```sh
brew install --cask teddychan/tap/yahoo-keykey-2
```

The cask lives in [teddychan/homebrew-tap](https://github.com/teddychan/homebrew-tap) and is
bumped automatically on every release. To add the tap explicitly first:

```sh
brew tap teddychan/tap
```

### Manual download (`.zip`)

1. Download `YahooKeyKey2-<version>.zip` from the
   [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest) and unzip it.
2. Move `YahooKeyKey2.app` into `~/Library/Input Methods/` (create the folder if it does not
   exist). No admin rights needed — releases ship a `.zip`, never a `.pkg` or `.dmg`.

### Finish setup

1. **Log out and back in** — macOS only scans input methods at login.
2. Add the input source: **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸ Traditional Chinese**
   → add **倉頡** and/or **速成**.
3. Press **Ctrl-Space** to switch to Yahoo KeyKey 2 and start typing.

## Update

- **In-app (both channels):** open the input menu from the input-source icon in the menu bar and
  choose **檢查更新…**. Updates are delivered over Sparkle from a signed appcast at
  `https://www.dragonapp.com/yahoo-keykey-2/appcast.xml`.
- **Homebrew:**

  ```sh
  brew upgrade --cask yahoo-keykey-2
  ```

- **Manual:** download the newest `.zip` and replace the app in `~/Library/Input Methods/`.

After any update, log out and back in so macOS reloads the input method.

## Uninstall

- **Homebrew:** `brew uninstall --cask yahoo-keykey-2` (add `--zap` to remove preferences and
  caches too).
- **Manual:** choose **解除安裝…** from the input menu, or delete
  `~/Library/Input Methods/YahooKeyKey2.app` and log out and back in.

## Build from source

Requires the Xcode 26 toolchain (`swiftc`, Swift 6.2) on Apple Silicon.

```sh
git clone https://github.com/teddychan/yahoo-keykey-2.git
cd yahoo-keykey-2
./tools/build-lm.sh    # build the language model into Resources/data.txt (first time only)
./tools/build-app.sh   # assemble + ad-hoc sign build/YahooKeyKey2.app
```

Run the test suites:

```sh
swift test --package-path Packages/KeyKeyEngine
```

```sh
swift test --package-path Packages/KeyKeyApp
```

For hands-on testing, `./tools/run-debug.sh` builds and installs a separate
**Yahoo KeyKey 2 Debug** input method with its own bundle id, so it never collides with an
installed release copy. Signed release builds are produced by
[`.github/workflows/release.yml`](.github/workflows/release.yml) on a `v*` tag — see
[docs/RELEASE.md](docs/RELEASE.md).

## Credits

Yahoo KeyKey 2 is built in tribute to the original **Yahoo! KeyKey (Yahoo!奇摩輸入法)**.
See [CREDITS.md](CREDITS.md) for the original projects, data sources, and engine
attributions, and [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md) for full
third-party license details.

## License

Yahoo KeyKey 2 is released under the [MIT License](LICENSE). Bundled third-party data keeps
its own permissive license — see [docs/THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md).
