# AGENTS.md

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on `teddychan/yahoo-keykey-2`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), used as-is. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.

## Project rules

- Keep a dot-separated `inputmethod` component in the bundle id (`com.dragonapp.inputmethod.yahoo-keykey`,
  and in any future input method's id). Without it macOS never registers the bundle as an input source: it
  never appears in Input Sources, nothing is logged, and `TISRegisterInputSource` still returns `noErr`.
  v2.0.0 shipped broken this way. If the id ever has to change, change every copy in one go: `App/Info.plist`
  (bundle id, `TISInputSourceID`, `InputMethodConnectionName`, the mode keys), the `App/*.lproj/InfoPlist.strings`
  keys, `RELEASE_BUNDLE_ID` in `tools/build-app.sh`, `releaseBundleID` in `App/AppMenuController.swift`, the
  fallback in `App/SettingsModel.swift`, and the Homebrew cask. Sparkle only updates within the same id.
- `vendor/` is gitignored, so a fresh clone or worktree has no `vendor/dragon-kit`, or a stale one.
  `tools/build-app.sh` resolves the pinned DragonKit itself; `swift test --package-path Packages/KeyKeyApp`
  does not. Before running it or trusting a failure, resolve the pin:
  `./tools/resolve-dragon-kit.sh vendor/dragon-kit "$(sed -n 's/^DRAGONKIT_TAG="\(.*\)"/\1/p' tools/build-app.sh)" https://github.com/teddychan/dragon-kit`.
  A KeyKeyApp compile error about DragonKit argument labels means a stale kit checkout, not broken app code.
