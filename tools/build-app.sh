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
APP="$BUILD/YahooKeyKey2.app"
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
  "$APP_SRC"/main.swift "$APP_SRC"/InputController.swift "$APP_SRC"/SharedResources.swift "$APP_SRC"/InputEngine.swift "$APP_SRC"/InputMethodModule.swift "$APP_SRC"/CandidateWindow.swift "$APP_SRC"/Preferences.swift "$APP_SRC"/AboutWindow.swift "$APP_SRC"/Updater.swift

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

echo "==> Embedding Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_CACHE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
chmod -R u+w "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> Code-signing Sparkle inside-out, then the app (ad-hoc)"
SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_V="$(/bin/ls -d "$SPARKLE_FW"/Versions/* | grep -v '/Current$' | head -1)"
for item in "$SPARKLE_V"/XPCServices/*.xpc "$SPARKLE_V/Autoupdate" "$SPARKLE_V/Updater.app"; do
  [ -e "$item" ] && codesign --force --options runtime -s - "$item"
done
codesign --force --options runtime -s - "$SPARKLE_FW"
# Sign the app last. No --deep: nested code (Sparkle) is already signed above.
codesign --force --options runtime --entitlements "$ENTITLEMENTS" -s - "$APP"
codesign -dv "$APP"

echo "==> Done: $APP"
