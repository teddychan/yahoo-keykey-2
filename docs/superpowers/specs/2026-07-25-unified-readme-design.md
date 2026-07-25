# Unified README design — Dragon App macOS repos

**Date:** 2026-07-25
**Scope:** `ice-2`, `clipmenu-2`, `yahoo-keykey-2`, `spectacle-2`
**Goal:** one README shape, one voice, the same H2 sections everywhere, plus a
top-of-file table of contents so readers can jump straight to what they need.

## Canonical skeleton

Section order is fixed. Every repo gets **all twelve H2s**, in exactly this order.

```markdown
<div align="center">
  <img src="<ICON>" width="160" height="160" alt="<APP> app icon">
  <h1><APP></h1>
  <p><strong><TAGLINE></strong></p>
</div>

<intro: 2–3 sentences, plain prose, no bullet list>

## Screenshots

![<caption>](<image>)

<BADGE ROW>

## Contents

- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Install](#install)
- [Features](#features)
- [<USAGE HEADING>](#<anchor>)
- [Troubleshooting](#troubleshooting)
- [Building from source](#building-from-source)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

## Requirements
## Install
### Homebrew
### Manual
### Uninstall
## Features
> [!NOTE]
> <provenance>
## <USAGE HEADING>
## Troubleshooting
## Building from source
## Contributing
## Credits
## License
```

Notes on the shape:

- **Screenshots sits above the badge row**, directly under the hero block. This
  generalizes ice-2's existing banner-under-title layout.
- **Contents lists H2s only.** No nested H3s — it stays short and stays accurate.
  `Screenshots` is listed even though it appears above Contents.
- **`<USAGE HEADING>`** is the one app-specific slot. Name it for the app
  (`Keyboard shortcuts`, `Cangjie generation (倉頡版本)`, `Actions and snippets`,
  `Menu bar sections`). Everything app-specific goes here, not in new top-level H2s.
- **Uninstall is `### Uninstall`** under Install — never its own H2.
- `Requirements` states the real minimum macOS and, where it applies, the
  Apple-Silicon-only constraint.

## Badge row

Five badges, this order, all `style=flat-square`:

```markdown
[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/teddychan/<REPO>/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%20<NN>%2B-fa4e49?style=flat-square)
[![Website](https://img.shields.io/badge/Website-dragonapp.com-015FBA?style=flat-square)](https://www.dragonapp.com/<SLUG>/)
[![License](https://img.shields.io/badge/license-<LIC>-blue?style=flat-square)](<LICENSE-FILE>)
```

**Use a static license badge**, not `shields.io/github/license/...`. The dynamic
one depends on GitHub's license auto-detection, which silently renders "unknown"
when the license lives in a non-standard filename (spectacle-2 uses `LICENSE.md`).
Static text is uniform and cannot break.

## Voice

- Second person, present tense. "Press ⌃Space to switch input methods."
- Lead each Features bullet with a **bold noun phrase**, then an em-dash, then one
  sentence. No trailing periods on fragments; full stops on sentences.
- No marketing inflation ("blazingly fast", "revolutionary"). State what it does.
- Don't document behavior you have not verified in the repo. If a fact can't be
  confirmed from source, config, or a workflow file, leave it out and say so in the PR.

## Per-repo facts (verified 2026-07-25)

| | ice-2 | clipmenu-2 | yahoo-keykey-2 | spectacle-2 |
|---|---|---|---|---|
| App name | Ice 2 | ClipMenu 2 | Yahoo KeyKey 2 | Spectacle 2 |
| Icon path | `Ice/Assets.xcassets/AppIcon.appiconset/icon_256x256.png` | *needs export from `app/AppIcon.icns`* | `App/AppIcon.png` | `Icon/AppIcon-1024.png` |
| Bundle id | `com.dragonapp.ice` | `com.dragonapp.clipmenu-2` | `com.dragonapp.inputmethod.yahoo-keykey` | `com.dragonapp.spectacle-2` |
| Min macOS | 14 (Sonoma) | 26 (Tahoe) | 26 (Tahoe) | 26 (Tahoe) |
| Arch | *verify* | Apple Silicon only | Apple Silicon only | *verify* |
| License | GPL-3.0, `LICENSE` | MIT, `LICENSE` | MIT, `LICENSE` | MIT, **`LICENSE.md`** |
| Site slug | `ice-2` | `clipmenu-2` | `yahoo-keykey-2` | `spectacle-2` |
| Cask | `teddychan/tap/ice-2` | `teddychan/tap/clipmenu-2` | `teddychan/tap/yahoo-keykey-2` | `teddychan/tap/spectacle-2` |
| Release asset | `Ice-2-vX.Y.Z.zip` | `ClipMenu-2-vX.Y.Z.zip` | `YahooKeyKey2-X.Y.Z.zip` | `Spectacle2-vX.Y.Z.zip` |
| Provenance | fork of [Ice](https://github.com/jordanbaird/Ice) by Jordan Baird | based on [ClipMenu](https://github.com/naotaka/ClipMenu) by Naotaka Morimoto | tribute to Yahoo! KeyKey; **not affiliated with Yahoo** | fork of [Spectacle](https://github.com/eczarny/spectacle) by Eric Czarny |

Uninstall prefs paths come from each app's real bundle id above — **not** from the
Homebrew cask, which is stale for ice-2 (it still references `com.jordanbaird.Ice`).

## Per-repo work

### ice-2 — lightest touch

Reorder to the skeleton. Merge the top `Banner` image and the bottom `## Gallery`
into a single `## Screenshots` (keep all six existing hosted image URLs; do not
re-host). Fold the two loose FAQ H2s — "Why does Ice 2 only support macOS 14 and
later?" and "Can I back up, restore, or sync my settings?" — into `## Troubleshooting`
as H3s. Demote `## Uninstall` to `### Uninstall`. Keep the Features/Roadmap
checkbox lists under `## Features`, and keep the unchecked roadmap items. Add
`## Building from source` (Xcode, `Ice.xcodeproj`) and `## Contributing` (link
`CODE_OF_CONDUCT.md`, `FREQUENT_ISSUES.md`, `docs/RELEASING.md`).

### clipmenu-2 — biggest additions

Currently developer-first with no hero, no badges, and **no Install section at all**.
Add hero (export a PNG from `app/AppIcon.icns` via
`sips -s format png app/AppIcon.icns --out docs/images/AppIcon.png`), badge row,
`## Screenshots`, `## Requirements`, `## Install` (Homebrew cask + Mac App Store +
manual zip), `### Uninstall`, `## Contributing`.

Consolidate `Build & run` + `Tests` + `Project layout` + `Releasing` under
`## Building from source` as H3s. Move the `First-run notes (Accessibility & signing)`
content into `## Troubleshooting`. The `## Fun fact` CLCL homage and its image move
into `## Credits` — keep it, it is character, not noise.

### yahoo-keykey-2 — correct a stale install path

**The current Install section is wrong.** It tells users to download
`YahooKeyKey2.pkg` and double-click it, but `.github/workflows/release.yml` uploads
`YahooKeyKey2-<version>.zip` only — there is no `.pkg` asset. Rewrite Manual install
as: download the zip, unzip, move `YahooKeyKey2.app` into `~/Library/Input Methods/`,
log out and back in, then add 倉頡 / 速成 under
**System Settings ▸ Keyboard ▸ Input Sources ▸ + ▸ Traditional Chinese**, and switch
with ⌃Space.

Move the Cangjie-generation table to `## Cangjie generation (倉頡版本)` as the Usage
slot. Add `## Screenshots`, `## Troubleshooting`, `## Building from source`,
`## Contributing`, `### Uninstall`. Keep the not-affiliated-with-Yahoo note.

### spectacle-2 — effective rewrite

The README is still verbatim upstream Spectacle and is factually wrong today.

**Delete:** the Travis CI badge, the "This project is not being actively maintained"
section, the Rectangle recommendation, all macOS 10.6/10.7/10.9 content and the S3
download links, the Carthage build instructions, and the bare 2017 copyright block.

**Keep, verified:** the modifier-symbol table and the window-action shortcut
descriptions — `Sources/SpectacleCore/DefaultShortcuts.swift` confirms the same 18
defaults (⌥⌘C center, ⌥⌘F fullscreen, ⌥⌘arrows halves, ⌃⌘arrows upper corners,
⌃⇧⌘arrows lower corners, ⌃⌥arrows thirds, ⌃⌥⌘arrows displays, ⌃⌥⇧arrows resize,
⌥⌘Z undo, ⌥⇧⌘Z redo). Move `## Common Issues` into `## Troubleshooting`.

**Add:** hero from `Icon/AppIcon-1024.png`, badge row, `## Requirements` (macOS 26+),
`## Install` (cask + manual zip), `### Uninstall`, `## Features` covering the v2.1.0
additions — drag-to-edge snapping with footprint preview, configurable window gaps,
undo/redo history, multi-display moves, thirds cycling, Sparkle auto-updates, launch
at login, and localization in 7 languages (en, es, fr, ja, ko, zh-Hans, zh-Hant) —
the provenance note, `## Building from source` (SwiftPM: `swift build`,
`scripts/run.sh`, `swift test`), and `## Contributing` (links `CONTRIBUTING.md`).

## Screenshots

New captures are taken from the **installed release builds** (all four are installed
and running), not from local debug builds — a debug build would render as
"<App> Debug" in menus and About panels.

Commit new images to `docs/images/` in each repo and reference them by relative path.
ice-2 keeps its six existing GitHub-hosted URLs.

## Delivery

One PR per repo, each branched fresh off that repo's `main`:

- branch `docs/unify-readme`
- commit subject `docs: unify README structure, style, and table of contents`
- PR body: what changed, plus an explicit **Corrections** list for any stale facts
  fixed (keykey's `.pkg`, spectacle-2's unmaintained notice, etc.)

`gh` is unavailable in this session, so PRs are opened with the GitHub MCP tools.

## Out of scope (flag, don't fix)

- The `ice-2` Homebrew cask quits and zaps `com.jordanbaird.Ice` while the app now
  ships as `com.dragonapp.ice`, so `brew uninstall --zap` leaves real prefs behind
  and targets a bundle id that no longer exists.
- `clipmenu-2` has no `CHANGELOG.md`, `CONTRIBUTING.md`, or `CODE_OF_CONDUCT.md`;
  its `## Contributing` links to the repo's issues page instead.
