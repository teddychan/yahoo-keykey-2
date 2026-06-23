# Yahoo KeyKey 2 — Sparkle auto-update (design)

Date: 2026-06-23
Status: approved (brainstorm)

## Goal

`YahooKeyKey2.app` (the direct-download / Developer-ID build) updates itself
via [Sparkle 2](https://sparkle-project.org), mirroring the ClipMenu 2 setup,
adapted to KeyKey's hand-rolled `swiftc` build and **local** release flow.
Homebrew-cask users already update via `brew upgrade --cask yahoo-keykey-2`;
this closes the gap for users who installed the `.pkg`/`.dmg` directly.

Non-goals (YAGNI): GitHub Actions CI (releases stay local), delta updates,
a custom release-notes UI, and the App Store edition (still "coming soon").

## Constraints / context

- The app is an **InputMethodKit agent** (`LSUIElement`), built by hand with
  `swiftc` in `tools/build-app.sh` (no Xcode project, no SPM resolution for the
  app target). The engine is a local Swift package, `Packages/KeyKeyEngine`.
- Releases are produced locally by `tools/package-release.sh` (build → optional
  Developer ID sign → optional notarize → DMG + ZIP). There is no CI.
- Distribution: a notarized `.pkg` installs `YahooKeyKey2.app` into
  `~/Library/Input Methods/` (current-user domain, no admin). A `.zip` of the
  same app is also published — **Sparkle consumes the `.zip`**.
- Reference: ClipMenu 2 already ships Sparkle (SPM-built framework embedded +
  signed inside-out; EdDSA-signed appcast on GitHub Pages). KeyKey reuses the
  appcast format and the inside-out signing recipe.

## Approach

Embed the Sparkle 2 framework into the bundle, drive it from a small `Updater`
wrapper, expose update checks in the input menu plus automatic background
checks, publish an EdDSA-signed appcast at
`https://www.dragonapp.com/keykey/appcast.xml`, and extend the local release
script to sign each release `.zip` and regenerate the appcast.

### 1. Vendor + embed Sparkle (build)

- **`tools/fetch-sparkle.sh`** (new): download a *pinned* Sparkle 2 release
  (target: latest 2.9.x at implementation time), verify its SHA-256 against a
  checksum hardcoded in the script, and extract `Sparkle.framework` into a
  cached, gitignored location (e.g. `build/sparkle/Sparkle.framework`). Idempotent.
- **`tools/build-app.sh`** (edit): after compiling the app,
  - copy `Sparkle.framework` into `YahooKeyKey2.app/Contents/Frameworks/`;
  - link the app with `-F <frameworks-dir> -framework Sparkle` and add an
    rpath of `@executable_path/../Frameworks`;
  - sign **inside-out** before signing the app: each
    `Sparkle.framework/Versions/*/XPCServices/*.xpc`, then `Autoupdate`,
    `Updater.app`, then `Sparkle.framework` itself, then the app bundle —
    `--options runtime` throughout. Ad-hoc locally; Developer ID at release.

### 2. Wire Sparkle into the app

- **`App/Updater.swift`** (new): a thin singleton wrapping
  `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil,
  userDriverDelegate: nil)`. It reads `SUFeedURL` / `SUPublicEDKey` from
  Info.plist (single source of truth). Exposes `checkForUpdates()`.
- **`App/main.swift`** (edit): instantiate `Updater.shared` once at launch so
  automatic checks start.
- **`App/Info.plist`** (edit): add
  - `SUFeedURL = https://www.dragonapp.com/keykey/appcast.xml`
  - `SUPublicEDKey = <generated EdDSA public key>`
  - `SUEnableAutomaticChecks = true`
  - `SUScheduledCheckInterval = 86400` (daily)
  - keep `LSUIElement`, `CFBundleVersion`, `CFBundleShortVersionString`.
- **`App/InputController.swift`** (edit): add a **"檢查更新…"** item to `menu()`,
  grouped with 關於, whose action calls `Updater.shared.checkForUpdates()`.

### 3. Signing key (local)

- Generate the EdDSA keypair once with Sparkle's `generate_keys`. The **private
  key lives in the build Mac's login Keychain** and never enters the repo. The
  **public key** is embedded as `SUPublicEDKey`. Document the one-time setup in
  `docs/RELEASE.md`.

### 4. Release flow (local, extends `package-release.sh`)

- After the existing build + Developer-ID sign + notarize + ZIP steps, the
  script (or a new helper `tools/update-appcast.sh` it calls):
  1. runs Sparkle's `sign_update` on the release `.zip` → EdDSA signature +
     byte length;
  2. regenerates `keykey/appcast.xml` with one `<item>` per released version
     (newest first): `<sparkle:version>` = `CFBundleVersion`,
     `<sparkle:shortVersionString>`, `<sparkle:minimumSystemVersion>12.0`,
     `<sparkle:hardwareRequirements>arm64`, and an `<enclosure>` whose `url`
     points at the GitHub release zip
     (`…/releases/download/vX.Y.Z/YahooKeyKey2-X.Y.Z.zip`), with `length` and
     `sparkle:edSignature`.
- The generated `appcast.xml` is copied/committed to the website repo as
  `docs/keykey/appcast.xml` (served at `/keykey/appcast.xml`). ClipMenu's root
  `docs/appcast.xml` is **not** touched.

### 5. Website

- Add `docs/keykey/appcast.xml` to `teddychan/www.dragonapp.com` (GitHub Pages).
  `robots.txt` already allows it. No template/i18n involvement (it is a feed,
  not a page).

## Data flow

App launch → `SPUStandardUpdaterController` starts → on schedule it fetches
`keykey/appcast.xml` → compares the newest `sparkle:version` to the running
`CFBundleVersion` → if newer, **verifies the EdDSA signature** against
`SUPublicEDKey` → downloads the enclosure `.zip` → installs it over
`~/Library/Input Methods/YahooKeyKey2.app` → relaunches.

## Input-method lifecycle nuance

Sparkle replaces the bundle in place and relaunches the app. KeyKey is an IMK
agent loaded on demand by the OS, so the relaunched process is the IMK server.
In practice the new version takes effect once the input method restarts; the
user may need to toggle the input source or log out/in for the OS to load the
new bundle. The relaunch is best-effort and we add a short note to the release
/ conclusion text. This matches how other IMEs (e.g. McBopomofo) ship Sparkle.

## One-time migration caveat

The first Sparkle-enabled build ships as **v1.3.0**. Existing v1.2.1 users have
no Sparkle and must update to v1.3.0 once manually (download or `brew upgrade`).
Every release after v1.3.0 auto-updates.

## Security

- Appcast served over HTTPS; every update is **EdDSA-signed** and verified by
  Sparkle before install (the private key is local-only).
- Hardened runtime + existing entitlements preserved on the app and on the
  embedded Sparkle code (signed inside-out with `--options runtime`).

## Testing / verification

1. **Build integrity:** `Sparkle.framework` is embedded;
   `codesign --verify --strict --deep` and `spctl -a -vvv -t install` pass on
   the signed release app (XPC services, `Autoupdate`, `Updater.app`, framework,
   app).
2. **Appcast validity:** the generated `appcast.xml` is well-formed RSS, the
   enclosure `length` matches the zip, and the `edSignature` verifies against
   the public key.
3. **End-to-end (staged):** install vN; point a *local* test appcast at a
   vN+1 zip; confirm Sparkle detects, downloads, verifies, and installs it.
4. **Menu:** "檢查更新…" triggers a check (and reports "up to date" when current).
5. **No regression:** typing, candidates, toggles, and 關於 still work; the app
   still launches as an `LSUIElement` IMK agent.

## Files touched

New: `tools/fetch-sparkle.sh`, `tools/update-appcast.sh`, `App/Updater.swift`,
`docs/keykey/appcast.xml` (in the website repo), `docs/RELEASE.md` (key setup).
Edit: `tools/build-app.sh`, `tools/package-release.sh`, `App/main.swift`,
`App/Info.plist`, `App/InputController.swift`, `.gitignore` (cache dir).
