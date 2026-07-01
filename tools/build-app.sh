#!/bin/bash
# Build "Yahoo KeyKey 2" (YahooKeyKey2.app) headlessly with swiftc, assemble the .app
# bundle, ad-hoc sign it.
#
# This is a deliberate deviation from the plan's "create the Xcode project in the IDE"
# step: we cannot drive the Xcode GUI, so we compile and assemble the bundle by hand.
# The artifact is identical in shape to what Xcode would produce: an LSUIElement IMK
# host app containing the engine, data.txt, and the IMK Info.plist.
#
# Requires: swiftc (Xcode toolchain), codesign, plutil. Produces ./build/YahooKeyKey2.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
# Debug identity (opt-in via KEYKEY_DEBUG_ID=1): build a SEPARATE input method named
# "Yahoo KeyKey 2 Debug" with bundle id com.dragonapp.inputmethod.yahoo-keykey.debug, so a local test
# build never collides with / shadows the installed RELEASE IME. (Two bundles sharing the
# release id register as duplicates in Launch Services and hide the real input source from
# the Input Sources picker.) Release/CI builds leave KEYKEY_DEBUG_ID unset and are unaffected.
RELEASE_BUNDLE_ID="com.dragonapp.inputmethod.yahoo-keykey"
if [[ "${KEYKEY_DEBUG_ID:-}" == "1" ]]; then
  APP_BUNDLE_NAME="Yahoo KeyKey 2 Debug"
  DEBUG_BUNDLE_ID="${RELEASE_BUNDLE_ID}.debug"
else
  APP_BUNDLE_NAME="YahooKeyKey2"
fi
APP="$BUILD/${APP_BUNDLE_NAME}.app"
ENGINE_SRC="$ROOT/Packages/KeyKeyEngine/Sources/KeyKeyEngine"
APP_SRC="$ROOT/App"
MODULE_DIR="$BUILD/modules"
EXECUTABLE_NAME="YahooKeyKey2"
ENTITLEMENTS="$APP_SRC/YahooKeyKey2.entitlements"
SPARKLE_CACHE="$ROOT/build/sparkle"

SDK="$(xcrun --show-sdk-path)"
# Apple Silicon only: pin the target to arm64 regardless of the build host's
# architecture. Yahoo KeyKey 2 does not ship an Intel (x86_64) slice. macOS 26 minimum.
TARGET="arm64-apple-macosx26.0"

# Optional: regenerate the bundled LM (Resources/data.txt) first. A clean checkout omits
# data.txt by design; pass --build-lm to generate it via tools/build-lm.sh before building.
if [[ "${1:-}" == "--build-lm" ]]; then
  echo "==> Building language model (data.txt)"
  "$ROOT/tools/build-lm.sh"
fi

echo "==> Ensuring Sparkle is vendored"
"$ROOT/tools/fetch-sparkle.sh"

echo "==> Cleaning previous build"
rm -rf "$APP" "$MODULE_DIR"
mkdir -p "$MODULE_DIR"

echo "==> Compiling KeyKeyEngine module"
# Build the engine as a static library + .swiftmodule so the app can `import KeyKeyEngine`.
swiftc \
  -emit-library -static -emit-module \
  -module-name KeyKeyEngine \
  -emit-module-path "$MODULE_DIR/KeyKeyEngine.swiftmodule" \
  -o "$MODULE_DIR/libKeyKeyEngine.a" \
  -sdk "$SDK" -target "$TARGET" \
  -swift-version 5 \
  "$ENGINE_SRC"/*.swift

echo "==> Compiling App against KeyKeyEngine"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc \
  -o "$APP/Contents/MacOS/$EXECUTABLE_NAME" \
  -sdk "$SDK" -target "$TARGET" \
  -swift-version 5 \
  -I "$MODULE_DIR" -L "$MODULE_DIR" -lKeyKeyEngine \
  -framework InputMethodKit -framework Cocoa \
  -F "$SPARKLE_CACHE" -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "$APP_SRC"/main.swift "$APP_SRC"/InputController.swift "$APP_SRC"/SharedResources.swift "$APP_SRC"/InputEngine.swift "$APP_SRC"/InputMethodModule.swift "$APP_SRC"/CandidateWindow.swift "$APP_SRC"/Preferences.swift "$APP_SRC"/AboutWindow.swift "$APP_SRC"/SettingsWindow.swift "$APP_SRC"/Uninstaller.swift "$APP_SRC"/Updater.swift

echo "==> Assembling Info.plist (resolving \${EXECUTABLE_NAME})"
sed "s/\${EXECUTABLE_NAME}/$EXECUTABLE_NAME/g" "$APP_SRC/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

echo "==> Copying bundled LM (data.txt)"
if [ ! -f "$ROOT/Resources/data.txt" ]; then
  echo "ERROR: Resources/data.txt missing; run tools/build-lm.sh first" >&2
  exit 1
fi
cp "$ROOT/Resources/data.txt" "$APP/Contents/Resources/data.txt"

echo "==> Copying bundled Cangjie table (cangjie.txt)"
if [ ! -f "$ROOT/Resources/cangjie.txt" ]; then
  echo "ERROR: Resources/cangjie.txt missing" >&2
  exit 1
fi
cp "$ROOT/Resources/cangjie.txt" "$APP/Contents/Resources/cangjie.txt"

echo "==> Copying Yahoo! KeyKey 三代 tables (cangjie-yahoo.txt, simplex-yahoo.txt)"
for f in cangjie-yahoo.txt simplex-yahoo.txt; do
  if [ ! -f "$ROOT/Resources/$f" ]; then
    echo "ERROR: Resources/$f missing" >&2
    exit 1
  fi
  cp "$ROOT/Resources/$f" "$APP/Contents/Resources/$f"
done

echo "==> Copying bundled Han-conversion table (opencc-TSCharacters.txt)"
if [ ! -f "$ROOT/Packages/KeyKeyEngine/Resources/opencc-TSCharacters.txt" ]; then
  echo "ERROR: Packages/KeyKeyEngine/Resources/opencc-TSCharacters.txt missing" >&2
  exit 1
fi
cp "$ROOT/Packages/KeyKeyEngine/Resources/opencc-TSCharacters.txt" "$APP/Contents/Resources/opencc-TSCharacters.txt"

echo "==> Copying app icon (AppIcon.icns)"
if [ ! -f "$APP_SRC/AppIcon.icns" ]; then
  echo "ERROR: App/AppIcon.icns missing; run tools/make-icon.sh first" >&2
  exit 1
fi
cp "$APP_SRC/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Copying input-mode icons (YahooKeyKey.tiff + @2x)"
for tiff in "$APP_SRC/YahooKeyKey.tiff" "$APP_SRC/YahooKeyKey@2x.tiff"; do
  if [ ! -f "$tiff" ]; then
    echo "ERROR: $(basename "$tiff") missing; run tools/make-icon.sh first" >&2
    exit 1
  fi
  cp "$tiff" "$APP/Contents/Resources/"
done

echo "==> Copying localized strings (.lproj)"
for lproj in "$APP_SRC"/*.lproj; do
  [ -d "$lproj" ] && cp -R "$lproj" "$APP/Contents/Resources/"
done

if [[ "${KEYKEY_DEBUG_ID:-}" == "1" ]]; then
  echo "==> Applying debug identity ($DEBUG_BUNDLE_ID / \"$APP_BUNDLE_NAME\")"
  PLIST="$APP/Contents/Info.plist"
  # Single pass moves every release-id occurrence into the .debug namespace: CFBundleIdentifier,
  # TISInputSourceID, InputMethodConnectionName, and the two ComponentInputModeDict mode ids
  # (...Cangjie / ...Simplex). InputController matches modes by the ".Cangjie"/".Simplex" SUFFIX,
  # which is preserved, so mode switching keeps working. SUFeedURL/SUPublicEDKey don't contain
  # the base id, so they're untouched.
  sed -i '' "s|${RELEASE_BUNDLE_ID}|${DEBUG_BUNDLE_ID}|g" "$PLIST"
  # Distinct name in the menu bar / Input Sources picker.
  sed -i '' "s|<string>Yahoo KeyKey 2</string>|<string>Yahoo KeyKey 2 Debug</string>|g" "$PLIST"
  # A throwaway local build must not offer to auto-update itself off the release appcast.
  plutil -replace SUEnableAutomaticChecks -bool false "$PLIST"
  # Re-key the localized input-mode display names (倉頡 / 速成) to the .debug mode ids, and
  # re-label the localized app name so the picker/menu show "Yahoo KeyKey 2 Debug" (the
  # localized CFBundleDisplayName here would otherwise override the Info.plist value above).
  for sf in "$APP/Contents/Resources"/*.lproj/InfoPlist.strings; do
    [ -f "$sf" ] || continue
    sed -i '' "s|${RELEASE_BUNDLE_ID}|${DEBUG_BUNDLE_ID}|g" "$sf"
    sed -i '' 's|"Yahoo KeyKey 2"|"Yahoo KeyKey 2 Debug"|g' "$sf"
  done
  plutil -lint "$PLIST"
fi

echo "==> Embedding Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_CACHE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
chmod -R u+w "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> Code-signing Sparkle inside-out, then the app (ad-hoc)"
SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_V="$(/bin/ls -d "$SPARKLE_FW"/Versions/* | grep -v '/Current$' | head -1)"
# Hardened runtime is required for notarized RELEASE builds. For a local ad-hoc DEBUG build it
# must be OMITTED: ad-hoc code carries no Team ID, and the hardened runtime's Library Validation
# then refuses to load the (also ad-hoc) Sparkle.framework — the app dies on launch with a dyld
# "different Team IDs" error, so the IME never registers its menu. A local debug build doesn't
# need the hardened runtime. Unquoted on purpose: empty string must expand to no argument.
if [[ "${KEYKEY_DEBUG_ID:-}" == "1" ]]; then RUNTIME_OPT=""; else RUNTIME_OPT="--options runtime"; fi
for item in "$SPARKLE_V"/XPCServices/*.xpc "$SPARKLE_V/Autoupdate" "$SPARKLE_V/Updater.app"; do
  [ -e "$item" ] && codesign --force $RUNTIME_OPT -s - "$item"
done
codesign --force $RUNTIME_OPT -s - "$SPARKLE_FW"
# Sign the app last. No --deep: nested code (Sparkle) is already signed above.
codesign --force $RUNTIME_OPT --entitlements "$ENTITLEMENTS" -s - "$APP"
codesign -dv "$APP"

echo "==> Done: $APP"
