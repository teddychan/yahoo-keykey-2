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

SDK="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macosx12.0"

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
  "$APP_SRC"/main.swift "$APP_SRC"/InputController.swift "$APP_SRC"/SharedResources.swift "$APP_SRC"/InputEngine.swift "$APP_SRC"/InputMethodModule.swift "$APP_SRC"/CandidateWindow.swift "$APP_SRC"/Preferences.swift "$APP_SRC"/AboutWindow.swift

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

echo "==> Copying localized strings (.lproj)"
for lproj in "$APP_SRC"/*.lproj; do
  [ -d "$lproj" ] && cp -R "$lproj" "$APP/Contents/Resources/"
done

echo "==> Ad-hoc code-signing the bundle (hardened runtime + explicit entitlements)"
codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" -s - "$APP"
codesign -dv "$APP"

echo "==> Done: $APP"
