# Releasing Yahoo! KeyKey 2

This describes how to produce a downloadable build of **Yahoo! KeyKey 2** (an
InputMethodKit input method) for distribution **outside the Mac App Store**.
App Store distribution is **not** used for this version.

The tagged release is published by CI: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
is a thin caller that delegates to the shared pipeline
`teddychan/dragon-release-ci/.github/workflows/release-macos.yml@v6`, which builds,
Developer ID-signs, notarizes, staples, and zips the app. The `@v6` pin is not
interchangeable with the older `@v5`: v6 gates the trigger on an exact `vX.Y.Z` tag (v5's
version parse turned a `workflow_dispatch` on a branch into version `main`) and requires
the `whats_new_path` input, so a release whose What's New text never changed is rejected —
see the caller's comments for why that input names the `.strings` files too.

**A release ships exactly one file: the `.zip`. No `.pkg`, no `.dmg`.** That `.zip`
(`YahooKeyKey2-<version>.zip`) is the user download, the Sparkle update payload, and
what the Homebrew cask `Casks/yahoo-keykey-2.rb` installs from.

Two scripts still package the app **locally**, outside CI: `tools/package-release.sh`
(builds + signs + notarizes the app and produces the same `.zip` containing the app +
`Install.txt`) and `tools/package-installer.sh` (wraps it in a GUI `.pkg`). They are a
**legacy / local-testing path — neither is what the tagged release publishes**, and the
`.pkg` is not published anywhere.

---

## Versioning convention

`CFBundleShortVersionString` holds the **target version** — the release the code is being
developed *toward*, not the last one released. So the moment work starts on a fix for a
released `X.Y.Z`, bump it in `App/Info.plist` to `X.Y.(Z+1)` — before the fix is finished, not
at the end. Every debug build from that branch then reports the version it will ship as:

```
v2.13.0          # released production version
v2.13.1 Debug    # bug fix under development
v2.13.1 Debug    # further debug builds still target 2.13.1
v2.13.1          # final production release
```

Never do the opposite — leaving modified code on the released number:

```
v2.13.0          # production
v2.13.0 Debug    # WRONG: modified code wearing a shipped version
v2.13.1          # eventual release
```

**A released version is immutable.** Once `2.13.0` is tagged, no modified code may ever report
`2.13.0` again. That is the whole point: a version in a bug report has to identify one exact
set of code, and it cannot if the release and everything developed after it share a number.

**The version stays strictly numeric `X.Y.Z`.** No `-dev.1`, `-beta.2` or `-rc.1` inside it —
`tools/build-app.sh` asserts the format and fails the build otherwise, because
`CFBundleShortVersionString` is the sole value the release tag is compared against, and a
non-numeric value breaks that gate.

`Debug` is therefore a **build-state label, never part of the number**. It is carried by a
separate key, `DragonBuildChannel = Debug`, which the About pane renders alongside the version.
To distinguish several debug builds of the same version, use the build identifiers — never a
version suffix:

| Field | Where it comes from | Example |
| --- | --- | --- |
| `CFBundleShortVersionString` | the **target version** in `App/Info.plist` | `2.13.1` |
| `DragonBuildChannel` | `Debug` on a debug build, absent otherwise | `Debug` |
| `CFBundleVersion` | `git rev-list --count HEAD` at build time | `214` |
| `DragonCommitDate` | the HEAD commit's date at build time | `2026-Aug-17 00:59:01 UTC` |

rendered as `v2.13.1 Debug (214) · 2026-Aug-17 00:59:01 UTC`. Quote that whole line in a bug
report: the version says which release the code targets, and the build number and commit date
say which build of it you were running. On 2026-08-16 a debug IME reporting build 210 with an
Aug-13 commit date was traced to another worktree while the branch under test was at build 212
— the version alone could not have caught it, which is exactly why the build identifiers exist
beside it rather than inside it.

**At release time** nothing about the version needs to change, because it was bumped when the
work started. The release commit carries the CHANGELOG section and the What's New notes naming
that same version, and the `vX.Y.Z` tag must match `CFBundleShortVersionString` exactly or CI
fails. Confirm the plist already reads the version you are tagging — step 1 of *Per release*
below.

---

## Prerequisites (for a signed + notarized public release)

A public download must be signed with a **Developer ID Application** certificate
and notarized by Apple, otherwise Gatekeeper blocks it. You need:

1. **Apple Developer Program** membership.

2. A **"Developer ID Application"** certificate installed in your login keychain.
   Create it in Xcode (Settings ▸ Accounts ▸ Manage Certificates ▸ "+") or on
   the Apple Developer website. Confirm it is present:

   ```sh
   security find-identity -v -p codesigning
   ```

   The identity string looks like:
   `Developer ID Application: Teddy Chan (TEAMID)`

3. A **notarytool keychain profile** that stores your Apple credentials. Create
   it once with an [app-specific password](https://support.apple.com/en-us/HT204397):

   ```sh
   xcrun notarytool store-credentials "YahooKeyKeyNotary" \
     --apple-id "you@example.com" \
     --team-id "TEAMID" \
     --password "abcd-efgh-ijkl-mnop"   # app-specific password, not your Apple ID password
   ```

   `"YahooKeyKeyNotary"` is the profile name you pass via `NOTARY_PROFILE`.

> An **ad-hoc** build (no env vars set) still works for local testing — it just
> can't be distributed without users manually clearing quarantine.

---

## Build & package locally (legacy path)

> This section is the **local** packaging path, kept for building and testing a
> signed/notarized app on your own machine. The published release comes from CI —
> see [Per release (automated)](#per-release-automated).

Signing and notarization are controlled by two environment variables. Set both
to reproduce a public-quality build locally:

```sh
export DEVELOPER_ID_APP="Developer ID Application: Teddy Chan (TEAMID)"
export NOTARY_PROFILE="YahooKeyKeyNotary"
./tools/package-release.sh
```

For a quick **local / ad-hoc** build (Gatekeeper-blocked), just run it with no
env vars:

```sh
./tools/package-release.sh
```

### Artifacts

`tools/package-release.sh` produces, in `build/`:

- `build/YahooKeyKey2-<version>.zip` — contains `YahooKeyKey2.app` + `Install.txt`
  (the user download **and** the Sparkle update payload).
- `build/appcast.xml` — Developer ID-signed builds only (see
  [Sparkle auto-update](#sparkle-auto-update-appcast)).

`tools/package-installer.sh` additionally produces:

- `build/YahooKeyKey2-<version>.pkg` — a GUI installer for local use
  ([details below](#gui-installer-pkg-legacy-not-shipped)).

Only the `.zip` belongs on a release; the `.pkg` is **not** published. Neither
script produces a `.dmg`.

The script prints a final summary stating the version, signing status
(Developer ID vs ad-hoc), and notarization status.

---

## Sparkle auto-update (appcast)

The Developer-ID build ships [Sparkle 2](https://sparkle-project.org) so users
who installed directly (not via Homebrew) get updates automatically.

### One-time setup

1. `tools/fetch-sparkle.sh` vendors `Sparkle.framework` + Sparkle's tools into
   `build/sparkle/` (gitignored, pinned + checksum-verified). `tools/build-app.sh`
   runs this automatically.
2. `build/sparkle/bin/generate_keys` creates an **EdDSA private key in your login
   Keychain** and prints the public key. It is already pinned in `App/Info.plist`
   as `SUPublicEDKey`. **Back up the private key** — losing it means you can no
   longer ship signed updates. (KeyKey reuses the same Sparkle signing key as
   ClipMenu 2.)

### Per release (automated)

The recommended path is CI: bump the version (step 1 below), commit, then push a
`v<version>` tag to `teddychan/yahoo-keykey-2`. `.github/workflows/release.yml`
(GitHub-hosted macOS runner) builds, Developer ID-signs, notarizes, staples, zips,
uploads the `.zip` to the GitHub release, publishes the EdDSA-signed appcast to
`docs/yahoo-keykey-2/appcast.xml` **in this repo**, and bumps the Homebrew cask.
It requires these repository secrets: `DEVELOPER_ID_CERT_P12_BASE64`,
`DEVELOPER_ID_CERT_PASSWORD`, `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID`,
`NOTARY_ISSUER_ID`, `PUBLIC_RELEASE_TOKEN`, `SPARKLE_EDDSA_PRIVATE_KEY` (the same
set used by clipmenu-2 / ice-2).

The appcast became app-owned across 2.11.3 and 2.11.4 — the caller passes `appcast_repo:
teddychan/yahoo-keykey-2`, where it used to take the default of the marketing-site repo. A
Sparkle appcast is update infrastructure, not marketing content, so it belongs in the app's
own repository: an outage, a permission problem, or a rejected change on the marketing site
then cannot interfere with update delivery.

**The website mirror is gone.** `appcast_mirror_repo: teddychan/www.dragonapp.com` published the
identical file to the old location for copies still at 2.11.3 or older, which read the site and
only the site. It was dropped in **2.12.0**, the "next minor release" its own trigger named, so
the release publishes to this repository and nowhere else. The website's old file is left in
place, stale, rather than deleted — a stale file is a quiet no-op where a missing one would be a
visible failure. The three-step migration is spelled out in the comments in
`.github/workflows/release.yml`; nothing about it is still pending.

1. Confirm `CFBundleShortVersionString` in `App/Info.plist` already reads the version you are
   tagging — it should have been bumped when work on this fix *started*, not now; see
   [Versioning convention](#versioning-convention). (The CI build fails if
   the tag doesn't match it.) Leave `CFBundleVersion` alone — the committed value is an
   inert placeholder, `23` since v2.3.0. The real build number is stamped into the bundle
   at build time from `git rev-list --count HEAD` (`tools/build-app.sh` locally, the same
   number in CI), which is why 2.11.3 shipped build 190 and 2.11.4 build 192 while the
   plist never moved. Sparkle does compare `CFBundleVersion` to decide what's newer — the
   commit count is what keeps it increasing, so hand-bumping the placeholder changes
   nothing, and "fixing" a number that is deliberately inert only wastes the next
   releaser's time.

### Per release (manual fallback)

If running locally instead of CI:

1. Bump the version as above.
2. Run `tools/package-release.sh` with `DEVELOPER_ID_APP` (and `NOTARY_PROFILE`)
   set. In addition to the `.zip`, it writes **`build/appcast.xml`**
   (EdDSA-signed; enclosure URL → the GitHub release zip).
3. Create the GitHub release at tag `v<version>` and upload the `.zip` — that single
   file is the entire release (first-time users download it; Sparkle updates from it).
   It must be named `YahooKeyKey2-<version>.zip` so the appcast URL matches.
4. **Publish the appcast:** copy `build/appcast.xml` over `docs/yahoo-keykey-2/appcast.xml`
   **in this repo**, commit, and push. That is the file the app reads — `App/Info.plist`'s
   `SUFeedURL` is
   `https://raw.githubusercontent.com/teddychan/yahoo-keykey-2/main/docs/yahoo-keykey-2/appcast.xml`.
   This repo is the only destination: do **not** also copy it into the website repo. That
   mirror was retired in 2.12.0 ([above](#per-release-automated)).
5. Bump the Homebrew cask `Casks/yahoo-keykey-2.rb` in `teddychan/homebrew-tap`
   (version + the `.zip` sha256; the cask installs the app from the `.zip`).

### Notes

- KeyKey is an input method: after Sparkle installs an update, the new version
  takes effect when the input method restarts — toggle the input source or log
  out and back in.
- The first Sparkle build is **v1.3.0**; v1.2.1 users (no Sparkle) update to it
  once manually, then auto-update thereafter.

---

## End-user install instructions

(Put these in the release notes / download page.)

1. Download `YahooKeyKey2-<version>.zip` from the release and unzip it.
2. **Copy `YahooKeyKey2.app`** (from the zip) into `~/Library/Input Methods/`
   (create the folder if it doesn't exist). No admin password needed.
3. **Log out and log back in** — macOS only scans for input methods at login.
4. Open **System Settings ▸ Keyboard ▸ Input Sources ▸ `+`**, choose
   **Traditional Chinese**, and add **Yahoo! KeyKey 2 — Cangjie** and/or
   **Yahoo! KeyKey 2 — Simplex**.
5. Switch input source with **Ctrl-Space** and start typing.

---

## Troubleshooting

- **"App is damaged" / "from an unidentified developer"**: this only happens for
  **ad-hoc / un-notarized** builds. Either right-click the app ▸ **Open** the
  first time, or remove the quarantine attribute:

  ```sh
  xattr -dr com.apple.quarantine ~/Library/Input\ Methods/YahooKeyKey2.app
  ```

  A **signed + notarized** build (the recommended public release) avoids this
  entirely.

- **Input method doesn't appear** in System Settings: confirm the app is in
  `~/Library/Input Methods/`, then **log out and back in** — the login scan is
  required.

---

## GUI installer (`.pkg`): legacy, not shipped

> **Not part of the release.** CI publishes the `.zip` only, and the Homebrew cask
> installs from that `.zip`. This script is retained as a local option; nothing in
> the release path builds or uploads a `.pkg`, so end users never see one.

For a native double-click experience, `tools/package-installer.sh` builds a
**GUI `.pkg`** that drives the macOS **Installer.app** flow: it installs
`YahooKeyKey2.app` into **`~/Library/Input Methods/`** (the **current user's
home — no admin password**) and ends with a **Log Out** button so the user can
log out/in to activate the input method.

It first builds the app — via `tools/package-release.sh` when `DEVELOPER_ID_APP`
is set (signed/notarized app), otherwise via `tools/build-app.sh` (ad-hoc) — then
wraps it with `pkgbuild` + `productbuild`.

### Prerequisites (for a signed + notarized installer)

A `.pkg` distributed by download must be signed with a **"Developer ID
Installer"** certificate (distinct from the **Developer ID Application** cert
that signs the app) and notarized. You need:

1. The app-signing prerequisites above (Developer ID Application cert + the same
   notarytool keychain profile).

2. A **"Developer ID Installer"** certificate in your login keychain. Create it
   once in **Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ "+" ▸
   "Developer ID Installer"**. Confirm it is present:

   ```sh
   security find-identity -v   # look for: Developer ID Installer: Teddy Chan (TEAMID)
   ```

> Without `DEVELOPER_ID_INSTALLER` the script still builds an **UNSIGNED** `.pkg`,
> which is fine for **local testing** (right-click ▸ **Open** to bypass
> Gatekeeper). It just can't be distributed by download.

### Build the installer

```sh
export DEVELOPER_ID_APP="Developer ID Application: Teddy Chan (TEAMID)"
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Teddy Chan (TEAMID)"
export NOTARY_PROFILE="YahooKeyKeyNotary"
./tools/package-installer.sh
```

For a quick **local / unsigned** installer, run it with no env vars:

```sh
./tools/package-installer.sh
```

Either way it produces, in `build/`:

- `build/YahooKeyKey2-<version>.pkg` — the GUI installer.

The installer resources (`distribution.xml.template`, `welcome.txt`,
`conclusion.txt`, `postinstall`) live in `installer/`; the script materializes
them into temp build dirs at run time and cleans up afterwards. The component
pkg uses `enable_currentUserHome` (current-user-home domain → no admin) and
`onConclusion="RequireLogout"` (the Log Out prompt). The summary states the
version, pkg signing status, and notarization status.

### End-user experience

1. **Double-click `YahooKeyKey2-<version>.pkg`** → the macOS Installer GUI opens.
   (For an unsigned pkg, right-click ▸ **Open** the first time.)
2. Click through; it installs **without** an admin password into
   **`~/Library/Input Methods/`**.
3. At the end, click **Log Out** (then log back in) — required so macOS
   registers the new input method.
4. Open **System Settings ▸ Keyboard ▸ Input Sources ▸ `+`**, choose
   **Traditional Chinese**, and add **Yahoo! KeyKey 2 — Cangjie** and/or
   **Yahoo! KeyKey 2 — Simplex**.
5. Switch input source with **Ctrl-Space** and start typing.
