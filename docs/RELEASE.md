# Releasing Yahoo KeyKey 2

This describes how to produce a downloadable build of **Yahoo KeyKey 2** (an
InputMethodKit input method) for distribution **outside the Mac App Store**.
App Store distribution is **not** used for this version.

The packaging is handled by `tools/package-release.sh`, which builds the app,
optionally signs and notarizes it, and produces a `.dmg` and a `.zip`.

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

Both runs produce, in `build/`:

- `build/YahooKeyKey2-1.0.0.dmg` — the DMG to upload to your release/download page.
- `build/YahooKeyKey2-1.0.0.zip` — a zip alternative containing the same `.app`.

The DMG contains `YahooKeyKey2.app` plus an `Install.txt` with the user steps below.

The script prints a final summary stating the version, signing status
(Developer ID vs ad-hoc), and notarization status.

---

## End-user install instructions

(Put these in the release notes / download page.)

1. **Download** and open the DMG.
2. **Copy `YahooKeyKey2.app`** into `~/Library/Input Methods/`
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
