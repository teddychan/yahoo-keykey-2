#!/bin/bash
# Build a GUI .pkg installer for "Yahoo KeyKey 2" (an InputMethodKit input method).
#
# The resulting double-clickable .pkg drives the native macOS Installer.app flow,
# installs YahooKeyKey2.app into the CURRENT user's ~/Library/Input Methods/
# (NO admin password required), and ends with a "Log Out" button so the user can
# log out/in to activate the input method (macOS only scans Input Methods at login).
#
# Signing and notarization are OPTIONAL and driven entirely by environment
# variables so this script never embeds Teddy's identity:
#
#   DEVELOPER_ID_APP        "Developer ID Application: NAME (TEAMID)"
#                           When set (optionally with NOTARY_PROFILE), the .app is
#                           built+signed (and notarized) via tools/package-release.sh.
#                           When unset, an ad-hoc app is built via tools/build-app.sh.
#
#   DEVELOPER_ID_INSTALLER  "Developer ID Installer: NAME (TEAMID)"
#                           When set, the .pkg is signed (productbuild --sign).
#                           Required for download distribution; absent => UNSIGNED pkg.
#
#   NOTARY_PROFILE          notarytool keychain profile. When set together with
#                           DEVELOPER_ID_INSTALLER, the signed .pkg is notarized+stapled.
#                           (Also used by package-release.sh to notarize the app.)
#
# Requires: tools/build-app.sh deps, plus pkgbuild, productbuild, plutil, xcrun.
# Produces ./build/YahooKeyKey2-<version>.pkg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/YahooKeyKey2.app"
INSTALLER_SRC="$ROOT/installer"
PKG_IDENTIFIER="com.github.teddychan.inputmethod.YahooKeyKey2.pkg"

# --- 1. Build the .app (signed/notarized if env set, else ad-hoc) -----------
if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> DEVELOPER_ID_APP set -- building signed app via package-release.sh"
  "$ROOT/tools/package-release.sh"
else
  echo "==> DEVELOPER_ID_APP not set -- building ad-hoc app via build-app.sh"
  "$ROOT/tools/build-app.sh"
fi

if [ ! -d "$APP" ]; then
  echo "ERROR: expected $APP after build" >&2
  exit 1
fi

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
if [ -z "$VERSION" ]; then
  echo "ERROR: could not read CFBundleShortVersionString from Info.plist" >&2
  exit 1
fi
echo "==> Version: $VERSION"

PKG="$BUILD/YahooKeyKey2-$VERSION.pkg"
COMPONENT_PKG="$BUILD/component.pkg"

# --- 2. Component pkg: payload installed to ~/Library/Input Methods/ --------
# Stage a root whose layout mirrors the user's home. With the distribution's
# enable_currentUserHome domain, "/Library/Input Methods" resolves under the
# installing user's home, so no admin rights are needed.
echo "==> Staging payload"
STAGE="$BUILD/pkg-stage"
SCRIPTS="$BUILD/pkg-scripts"
rm -rf "$STAGE" "$SCRIPTS"
mkdir -p "$STAGE/Library/Input Methods" "$SCRIPTS"
cp -R "$APP" "$STAGE/Library/Input Methods/YahooKeyKey2.app"

cp "$INSTALLER_SRC/postinstall" "$SCRIPTS/postinstall"
chmod +x "$SCRIPTS/postinstall"

echo "==> Building component pkg"
rm -f "$COMPONENT_PKG"
pkgbuild \
  --root "$STAGE" \
  --install-location "/" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  --scripts "$SCRIPTS" \
  "$COMPONENT_PKG"

# --- 3. Distribution pkg via productbuild -----------------------------------
# Materialize distribution.xml + welcome/conclusion into a temp dir, substituting
# the version and component pkg filename.
echo "==> Preparing distribution resources"
DIST_DIR="$BUILD/pkg-dist"
RES_DIR="$BUILD/pkg-resources"
rm -rf "$DIST_DIR" "$RES_DIR"
mkdir -p "$DIST_DIR" "$RES_DIR"

sed -e "s/__VERSION__/$VERSION/g" \
    -e "s|__COMPONENT_PKG__|$(basename "$COMPONENT_PKG")|g" \
    "$INSTALLER_SRC/distribution.xml.template" > "$DIST_DIR/distribution.xml"

cp "$INSTALLER_SRC/welcome.txt" "$RES_DIR/welcome.txt"
cp "$INSTALLER_SRC/conclusion.txt" "$RES_DIR/conclusion.txt"

echo "==> Building distribution pkg: $PKG"
rm -f "$PKG"

PRODUCTBUILD_SIGN=()
SIGN_STATUS="UNSIGNED"
if [ -n "${DEVELOPER_ID_INSTALLER:-}" ]; then
  echo "==> Signing pkg with: $DEVELOPER_ID_INSTALLER"
  PRODUCTBUILD_SIGN=(--sign "$DEVELOPER_ID_INSTALLER")
  SIGN_STATUS="Developer ID Installer ($DEVELOPER_ID_INSTALLER)"
else
  echo "WARNING: DEVELOPER_ID_INSTALLER not set -- the .pkg will be UNSIGNED."
  echo "         An unsigned pkg is fine for LOCAL testing (right-click > Open)."
  echo "         For download distribution you need a \"Developer ID Installer\""
  echo "         certificate. Create it once in Xcode > Settings > Accounts >"
  echo "         Manage Certificates > + > Developer ID Installer, then set"
  echo "         DEVELOPER_ID_INSTALLER. See docs/RELEASE.md."
fi

productbuild \
  --distribution "$DIST_DIR/distribution.xml" \
  --package-path "$BUILD" \
  --resources "$RES_DIR" \
  ${PRODUCTBUILD_SIGN[@]+"${PRODUCTBUILD_SIGN[@]}"} \
  "$PKG"

# --- 4. Notarization (optional; signed pkgs only) ---------------------------
NOTARY_STATUS="skipped"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  if [ -n "${DEVELOPER_ID_INSTALLER:-}" ]; then
    echo "==> Notarizing pkg with keychain profile: $NOTARY_PROFILE"
    xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling notarization ticket onto the pkg"
    xcrun stapler staple "$PKG"
    NOTARY_STATUS="notarized + stapled"
  else
    echo "WARNING: NOTARY_PROFILE is set but DEVELOPER_ID_INSTALLER is not."
    echo "         Notarizing a pkg requires a Developer ID Installer signature -- skipping."
    NOTARY_STATUS="skipped (no Developer ID Installer signature)"
  fi
else
  echo "==> NOTARY_PROFILE not set -- skipping pkg notarization."
fi

# --- 5. Clean up temp artifacts ---------------------------------------------
rm -rf "$STAGE" "$SCRIPTS" "$DIST_DIR" "$RES_DIR" "$COMPONENT_PKG"

# --- 6. Summary -------------------------------------------------------------
echo
echo "================== INSTALLER SUMMARY ==================="
echo "Version          : $VERSION"
echo "Installer pkg    : $PKG"
echo "Pkg signing      : $SIGN_STATUS"
echo "Notarization     : $NOTARY_STATUS"
echo "Install location : ~/Library/Input Methods/YahooKeyKey2.app (current user, no admin)"
echo "Activation       : Installer ends with a Log Out button; user logs out/in,"
echo "                   then enables it in System Settings > Keyboard > Input Sources."
echo "========================================================"
if [ "$SIGN_STATUS" = "UNSIGNED" ]; then
  echo "NOTE: UNSIGNED pkg -- local testing only (right-click > Open)."
  echo "      For public download, set DEVELOPER_ID_INSTALLER (and NOTARY_PROFILE)."
  echo "      See docs/RELEASE.md."
fi
