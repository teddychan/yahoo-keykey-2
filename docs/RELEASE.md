# Releasing Yahoo KeyKey 2

This describes how to produce a downloadable build of **Yahoo KeyKey 2** (an
InputMethodKit input method) for distribution **outside the Mac App Store**.
App Store distribution is **not** used for this version.

Packaging is handled by `tools/package-release.sh` (builds + signs + notarizes
the app, and produces a `.zip` containing the app + `Install.txt`) and
`tools/package-installer.sh` (additionally produces a GUI `.pkg`).

**A release ships exactly two files: the `.pkg` and the `.zip`. No `.dmg`.**
The `.zip` is both the user download and the Sparkle update payload.

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

## Build & package

Signing and notarization are controlled by two environment variables. Set both
for a public release:

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

`tools/package-installer.sh` additionally produces:

- `build/YahooKeyKey2-<version>.pkg` — the GUI installer (see below).

Upload **both** to the release. No `.dmg` is produced.

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

### Per release

1. Bump `CFBundleShortVersionString` **and** `CFBundleVersion` in `App/Info.plist`.
   `CFBundleVersion` must strictly increase — Sparkle compares it to decide what's
   newer.
2. Run `tools/package-release.sh` with `DEVELOPER_ID_APP` (and `NOTARY_PROFILE`)
   set. In addition to the `.zip`, it writes **`build/appcast.xml`**
   (EdDSA-signed; enclosure URL → the GitHub release zip).
3. Create the GitHub release at tag `v<version>` and upload the `.zip` (Sparkle
   downloads this) alongside the `.pkg` (first-time users). The zip must be named
   `YahooKeyKey2-<version>.zip` so the appcast URL matches.
4. **Publish the appcast:** copy `build/appcast.xml` into the website repo at
   `docs/keykey/appcast.xml`, commit, and push. GitHub Pages serves it at
   `https://www.dragonapp.com/keykey/appcast.xml` — the `SUFeedURL` the app reads.
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

1. **Easiest:** download and run the `.pkg` installer (click through; no admin
   password). Skip to step 3. **Or** download the `.zip` and continue:
2. **Copy `YahooKeyKey2.app`** (from the zip) into `~/Library/Input Methods/`
   (create the folder if it doesn't exist).
3. **Log out and log back in** — macOS only scans for input methods at login.
4. Open **System Settings ▸ Keyboard ▸ Input Sources ▸ `+`**, choose
   **Traditional Chinese**, and add **Yahoo KeyKey 2 — Cangjie** and/or
   **Yahoo KeyKey 2 — Simplex**.
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

## GUI installer (`.pkg`)

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

- `build/YahooKeyKey2-1.0.0.pkg` — the GUI installer.

The installer resources (`distribution.xml.template`, `welcome.txt`,
`conclusion.txt`, `postinstall`) live in `installer/`; the script materializes
them into temp build dirs at run time and cleans up afterwards. The component
pkg uses `enable_currentUserHome` (current-user-home domain → no admin) and
`onConclusion="RequireLogout"` (the Log Out prompt). The summary states the
version, pkg signing status, and notarization status.

### End-user experience

1. **Double-click `YahooKeyKey2-1.0.0.pkg`** → the macOS Installer GUI opens.
   (For an unsigned pkg, right-click ▸ **Open** the first time.)
2. Click through; it installs **without** an admin password into
   **`~/Library/Input Methods/`**.
3. At the end, click **Log Out** (then log back in) — required so macOS
   registers the new input method.
4. Open **System Settings ▸ Keyboard ▸ Input Sources ▸ `+`**, choose
   **Traditional Chinese**, and add **Yahoo KeyKey 2 — Cangjie** and/or
   **Yahoo KeyKey 2 — Simplex**.
5. Switch input source with **Ctrl-Space** and start typing.
