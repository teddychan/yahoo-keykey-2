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
![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue?style=flat-square)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-blue?style=flat-square)
[![License](https://img.shields.io/github/license/teddychan/yahoo-keykey-2?style=flat-square)](LICENSE)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/yahoo-keykey-2/)

> **Note:** Yahoo KeyKey 2 is not affiliated with, or endorsed by, Yahoo. It is an
> independent project that exists to honor the original work and keep a KeyKey-style
> experience alive on modern macOS.

## Features

- **倉頡 + 速成 input** — both classic modes, with wildcard `*` matching when you don't
  remember every radical.
- **Frequency-ranked &amp; adaptive** — candidates are ordered by how common they are, and
  the characters you pick rank higher over time.
- **Associated phrases (聯想字詞)** — after you commit a character, Yahoo KeyKey 2 suggests
  the words that usually follow.
- **繁 → 簡 &amp; full-width punctuation** — toggle Traditional-to-Simplified output (輸出簡體字)
  and full-width punctuation (全形標點) right from the input menu.
- **Native candidate window** — a vertical candidate list that follows the text caret and
  never gets clipped off-screen.
- **Lightweight &amp; open source** — full source on GitHub, MIT licensed.

## Requirements

- A Mac with **Apple Silicon (arm64)**
- **macOS 12 Monterey** or later
- Signed with a Developer ID and notarized by Apple, so it opens cleanly

## Install

### Installer (`.pkg`)

1. Download `YahooKeyKey2.pkg` from the [latest release](https://github.com/teddychan/yahoo-keykey-2/releases/latest)
   and double-click it. It installs to `~/Library/Input Methods` without admin rights.
2. Log out and back in when prompted.
3. Add the input source: **System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸ Traditional Chinese**
   → add **倉頡** and/or **速成**.
4. Press **Ctrl-Space** to switch to Yahoo KeyKey 2 and start typing.

### Homebrew

```sh
brew install --cask teddychan/tap/yahoo-keykey-2
```

Then log out and back in to load the input method.

## Credits

Yahoo KeyKey 2 is built in tribute to the original **Yahoo! KeyKey (Yahoo!奇摩輸入法)**.
See [CREDITS.md](CREDITS.md) for the original projects, data sources, and engine
attributions, and `docs/THIRD-PARTY-NOTICES.md` for full third-party license details.

## License

Yahoo KeyKey 2 is available under the [MIT License](LICENSE).
