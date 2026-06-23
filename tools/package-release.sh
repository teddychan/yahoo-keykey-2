#!/bin/bash
# Package "Yahoo KeyKey 2" for non-App-Store distribution.
#
# Produces a downloadable DMG (and a .zip alternative) containing YahooKeyKey2.app,
# which users copy into ~/Library/Input Methods/ and enable in System Settings.
#
# Code signing and notarization are OPTIONAL and driven entirely by environment
# variables so this script never embeds Teddy's identity and can run on CI or any
# machine in ad-hoc mode. Signing/notarization must be done on a machine that holds
# the Developer ID certificate and notarytool credentials.
#
#   DEVELOPER_ID_APP   e.g. "Developer ID Application: Teddy Chan (TEAMID)"
#                      When set, the .app is re-signed with this identity.
#                      When unset, the .app keeps build-app.sh's ad-hoc signature.
#
#   NOTARY_PROFILE     a notarytool keychain profile name (created via
#                      `xcrun notarytool store-credentials`). When set AND the app
#                      was Developer-ID-signed, the app is notarized and stapled.
#
# Requires: tools/build-app.sh deps, plus codesign, xcrun (notarytool/stapler),
# hdiutil, ditto, plutil. Produces ./build/YahooKeyKey2-<version>.dmg and .zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/YahooKeyKey2.app"
APP_NAME="YahooKeyKey2.app"
ENTITLEMENTS="$ROOT/App/YahooKeyKey2.entitlements"

# --- 1. Build the .app ------------------------------------------------------
echo "==> Building YahooKeyKey2.app"
"$ROOT/tools/build-app.sh"

if [ ! -d "$APP" ]; then
  echo "ERROR: expected $APP after build-app.sh" >&2
  exit 1
fi

# --- 2. Read version from the built Info.plist ------------------------------
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
if [ -z "$VERSION" ]; then
  echo "ERROR: could not read CFBundleShortVersionString from Info.plist" >&2
  exit 1
fi
echo "==> Version: $VERSION"

DMG="$BUILD/YahooKeyKey2-$VERSION.dmg"
ZIP="$BUILD/YahooKeyKey2-$VERSION.zip"

# --- 3. Code signing (optional) ---------------------------------------------
# Track signing status for the final summary.
SIGN_STATUS="ad-hoc"
if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> Signing with Developer ID: $DEVELOPER_ID_APP"
  # --options runtime enables the hardened runtime (required for notarization);
  # --timestamp embeds a secure timestamp. Sparkle is signed inside-out (its XPC
  # services, Autoupdate, Updater.app, then the framework) before the app — never
  # with --deep, which corrupts Sparkle's nested code signatures.
  SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
  SPARKLE_V="$(/bin/ls -d "$SPARKLE_FW"/Versions/* | grep -v '/Current$' | head -1)"
  for item in "$SPARKLE_V"/XPCServices/*.xpc "$SPARKLE_V/Autoupdate" "$SPARKLE_V/Updater.app"; do
    [ -e "$item" ] && codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$item"
  done
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$SPARKLE_FW"
  # Sign the app last; no --deep (Sparkle is already signed inside-out above).
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_APP" "$APP"
  echo "==> Verifying signature"
  codesign --verify --strict --verbose=2 "$APP"
  SIGN_STATUS="Developer ID ($DEVELOPER_ID_APP)"
else
  echo "WARNING: DEVELOPER_ID_APP not set -- the app keeps its AD-HOC signature."
  echo "         Gatekeeper will BLOCK download-distributed copies. Users would need"
  echo "         to right-click > Open, or remove the quarantine attribute manually."
  echo "         See docs/RELEASE.md for the signed+notarized release procedure."
fi

# --- 4. Notarization (optional) ---------------------------------------------
NOTARY_STATUS="skipped"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  if [ -n "${DEVELOPER_ID_APP:-}" ]; then
    echo "==> Notarizing with keychain profile: $NOTARY_PROFILE"
    NOTARIZE_ZIP="$BUILD/YahooKeyKey2-notarize.zip"
    rm -f "$NOTARIZE_ZIP"
    # notarytool wants an archive; ditto preserves the bundle structure.
    ditto -c -k --keepParent "$APP" "$NOTARIZE_ZIP"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
      --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling notarization ticket onto the app"
    xcrun stapler staple "$APP"
    rm -f "$NOTARIZE_ZIP"
    NOTARY_STATUS="notarized + stapled"
  else
    echo "WARNING: NOTARY_PROFILE is set but DEVELOPER_ID_APP is not."
    echo "         Notarization requires a Developer-ID signature -- skipping."
    NOTARY_STATUS="skipped (no Developer ID signature)"
  fi
else
  echo "==> NOTARY_PROFILE not set -- skipping notarization."
fi

# --- 5. Package: DMG + ZIP --------------------------------------------------
# Stage a clean directory holding the app and a plain-text install guide, then
# turn it into a read-only DMG. The staging dir keeps the DMG contents tidy.
echo "==> Staging DMG contents"
STAGE="$BUILD/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME"

cat > "$STAGE/Install.txt" <<EOF
Yahoo KeyKey 2 — Install

1. Copy "YahooKeyKey2.app" into your Input Methods folder:
       ~/Library/Input Methods/
   (Create the folder if it does not exist.)

2. Log out and log back in. macOS only scans input methods at login.

3. Open System Settings > Keyboard > Input Sources > "+",
   choose Traditional Chinese, and add:
       Yahoo KeyKey 2 — Cangjie   and/or   Yahoo KeyKey 2 — Simplex

4. Switch input source with Ctrl-Space and start typing.

If macOS reports the app is damaged or from an unidentified developer
(ad-hoc / un-notarized builds only), remove the quarantine flag:
       xattr -dr com.apple.quarantine "~/Library/Input Methods/YahooKeyKey2.app"
EOF

echo "==> Creating DMG: $DMG"
rm -f "$DMG"
hdiutil create \
  -volname "Yahoo KeyKey 2 $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

echo "==> Creating ZIP: $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

rm -rf "$STAGE"

# --- 5b. Sparkle appcast (only for signed release builds) -------------------
if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> Generating Sparkle appcast"
  APPCAST="$BUILD/appcast.xml"
  "$ROOT/tools/update-appcast.sh" "$ZIP" "$VERSION" "$APPCAST"
  echo "==> Appcast ready: $APPCAST (commit to www.dragonapp.com:docs/keykey/appcast.xml)"
else
  echo "==> Skipping appcast (ad-hoc build; Sparkle needs the Developer ID zip)"
fi

# --- 6. Summary -------------------------------------------------------------
echo
echo "==================== RELEASE SUMMARY ===================="
echo "Version       : $VERSION"
echo "Signing       : $SIGN_STATUS"
echo "Notarization  : $NOTARY_STATUS"
echo "DMG           : $DMG"
echo "ZIP           : $ZIP"
echo "========================================================="
if [ "$SIGN_STATUS" = "ad-hoc" ]; then
  echo "NOTE: This is an AD-HOC build for local testing only."
  echo "      For a public download, set DEVELOPER_ID_APP and NOTARY_PROFILE."
  echo "      See docs/RELEASE.md."
fi
