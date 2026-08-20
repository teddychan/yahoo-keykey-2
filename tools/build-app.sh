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
# Pinned DragonKit checkout. Cloned under vendor/ (see the adoption notes) at the tag in
# DRAGONKIT_TAG below — that assignment is the pin, so it is not repeated here. Its SwiftPM
# build produces the DragonKit / DragonKitUpdates modules and the DragonKit resource bundle.
# Never copied into App/ sources.
KIT_DIR="$ROOT/vendor/dragon-kit"

SDK="$(xcrun --show-sdk-path)"
# Apple Silicon only: pin the target to arm64 regardless of the build host's
# architecture. Yahoo KeyKey 2 does not ship an Intel (x86_64) slice. macOS 26 minimum.
TARGET="arm64-apple-macosx26.0"

# Optimization. swiftc defaults to -Onone, so until now every build — including the notarized
# release, which comes through this same script — shipped the engine and the app UNOPTIMIZED,
# inside a process attached to every app that takes keyboard input. Measured on the bundled 五代
# table (arm64, Xcode 26.6), -Onone vs -O: Cangjie table parse 73 -> 34 ms, 速成 table derive
# 78 -> 8 ms, 2000 速成 compositions 21 -> 2 ms. A local debug build stays at -Onone so the
# debugger is usable (and so assert/precondition survive into the build being tested).
if [[ "${KEYKEY_DEBUG_ID:-}" == "1" ]]; then OPT="-Onone"; else OPT="-O"; fi

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
  -swift-version 5 "$OPT" \
  "$ENGINE_SRC"/*.swift

echo "==> Building DragonKit (SwiftPM, release) in pinned checkout"
# swift build produces the module .swiftmodules, the DragonKit resource bundle
# (DragonKit_DragonKit.bundle), and resolves Sparkle. It emits per-module object files (not a
# .a), so archive them into static libraries the app's swiftc link can consume. Uses the
# package's own tools version (6.1) — a separate compilation from the app's -swift-version 5.
# Clone the pinned tag on first use (e.g. a fresh CI checkout); vendor/ is gitignored, never
# committed. An existing checkout is reused only once it has been identified — the states and the
# reasoning live in tools/resolve-dragon-kit.sh, which is split out so
# tools/test-resolve-dragon-kit.sh can drive every one of them without a swiftc build.
# DRAGONKIT_TAG stays HERE: the propagation SOP and .github/workflows/tests.yml both read the pin
# out of this file.
DRAGONKIT_TAG="v4.1.1"
DRAGONKIT_URL="https://github.com/teddychan/dragon-kit"
"$ROOT/tools/resolve-dragon-kit.sh" "$KIT_DIR" "$DRAGONKIT_TAG" "$DRAGONKIT_URL"
( cd "$KIT_DIR" && swift build -c release )
KIT_REL="$(cd "$KIT_DIR" && swift build -c release --show-bin-path)"
KIT_MODULES="$KIT_REL/Modules"
KIT_BUNDLE="$KIT_REL/DragonKit_DragonKit.bundle"

echo "==> Archiving DragonKit object files into static libs"
libtool -static -o "$MODULE_DIR/libDragonKit.a" $(find -L "$KIT_REL/DragonKit.build" -name '*.o')
libtool -static -o "$MODULE_DIR/libDragonKitUpdates.a" $(find -L "$KIT_REL/DragonKitUpdates.build" -name '*.o')

echo "==> Compiling App against KeyKeyEngine + DragonKit"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# DragonKitUpdates imports Sparkle; the app already vendors Sparkle.framework (2.9.0) via
# fetch-sparkle.sh, so both the app and DragonKitUpdates link that ONE framework — no second
# Sparkle copy. -I picks up the DragonKit/DragonKitUpdates .swiftmodules; SwiftUI/AppKit come
# from the SDK.
swiftc \
  -o "$APP/Contents/MacOS/$EXECUTABLE_NAME" \
  -sdk "$SDK" -target "$TARGET" \
  -swift-version 5 "$OPT" \
  -I "$MODULE_DIR" -L "$MODULE_DIR" -lKeyKeyEngine \
  -I "$KIT_MODULES" \
  -lDragonKit -lDragonKitUpdates \
  -framework InputMethodKit -framework Cocoa \
  -F "$SPARKLE_CACHE" -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "$APP_SRC"/main.swift "$APP_SRC"/InputController.swift "$APP_SRC"/KeyEventPolicy.swift "$APP_SRC"/SharedResources.swift "$APP_SRC"/InputEngine.swift "$APP_SRC"/InputMethodModule.swift "$APP_SRC"/CandidateWindow.swift "$APP_SRC"/Preferences.swift "$APP_SRC"/SettingsModel.swift "$APP_SRC"/GeneralPane.swift "$APP_SRC"/AboutConfig.swift "$APP_SRC"/WhatsNewConfig.swift "$APP_SRC"/AppMenuController.swift

echo "==> Assembling Info.plist (resolving \${EXECUTABLE_NAME})"
sed "s/\${EXECUTABLE_NAME}/$EXECUTABLE_NAME/g" "$APP_SRC/Info.plist" > "$APP/Contents/Info.plist"
# Stamp the build number from the git commit count (shared Dragon-App convention). The committed
# CFBundleVersion is an inert placeholder; the real, monotonically-increasing number is set here so
# About shows "<short> (<build>)" and each build differs. Falls back to 1 outside a git checkout.
BUILD_NUM="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" "$APP/Contents/Info.plist"
# Stamp the commit's own datetime beside the count, so both halves of About's
# "v2.11.0 (812) · 2026-Aug-08 09:14:07 UTC" describe the same commit. DragonAbout reads this key;
# without it the line silently drops the timestamp. Committer date (%cI), not author date, so a
# rebase cannot leave it pointing at an earlier moment. Set-then-Add because the key is absent
# from the committed template but present on a rebuild into an existing bundle.
COMMIT_DATE="$(git -C "$ROOT" log -1 --format=%cI 2>/dev/null || true)"
if [ -n "$COMMIT_DATE" ]; then
  /usr/libexec/PlistBuddy -c "Set :DragonCommitDate $COMMIT_DATE" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DragonCommitDate string $COMMIT_DATE" "$APP/Contents/Info.plist"
fi
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

echo "==> Copying bundled Pinyin map (pinyin-zhuyin.txt)"
if [ ! -f "$ROOT/Resources/pinyin-zhuyin.txt" ]; then
  echo "ERROR: Resources/pinyin-zhuyin.txt missing; run tools/build-pinyin-map.py first" >&2
  exit 1
fi
cp "$ROOT/Resources/pinyin-zhuyin.txt" "$APP/Contents/Resources/pinyin-zhuyin.txt"

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

echo "==> Copying DragonKit resource bundle (DragonKit_DragonKit.bundle)"
# DragonKit resolves its own localized strings from Contents/Resources/DragonKit_DragonKit.bundle
# at runtime (see DragonKitResources). swift build produced it in the pinned checkout's bin dir.
if [ ! -d "$KIT_BUNDLE" ]; then
  echo "ERROR: DragonKit_DragonKit.bundle missing at $KIT_BUNDLE" >&2
  exit 1
fi
rm -rf "$APP/Contents/Resources/DragonKit_DragonKit.bundle"
cp -R "$KIT_BUNDLE" "$APP/Contents/Resources/DragonKit_DragonKit.bundle"

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
  # The version field stays the numeric candidate for the NEXT public release — never
  # "2.11.1 (Debug)". MAC-APP-RELEASE-LIFECYCLE.md makes CFBundleShortVersionString the sole
  # source of truth the release tag is asserted against, and the shared release workflow
  # compares the tag to exactly this key, so a channel label inside it breaks the tag gate.
  # This app never grew that mutation — clipmenu-2, ice-2 and spectacle-2 each did — so assert
  # it rather than trust it: the day someone adds one, the debug build fails here, not the tag.
  SHORT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
  if [[ ! "$SHORT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: CFBundleShortVersionString must be a numeric X.Y.Z candidate, got '$SHORT_VERSION'" >&2
    exit 1
  fi
  # The word "Debug" lives HERE instead, as build-channel metadata. DragonAbout (v3.3.0+) reads
  # this key and renders "v2.11.1 Debug (<build>) · <commit date> UTC", so a screenshot in a bug
  # report identifies the build without the version field ever carrying a non-numeric value.
  # Set-then-Add because the key is absent from the committed template but present on a rebuild
  # into an existing bundle — the same shape as the DragonCommitDate stamp above.
  /usr/libexec/PlistBuddy -c "Set :DragonBuildChannel Debug" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DragonBuildChannel string Debug" "$PLIST"
  # Belt and braces with InputController's DragonAbout.isDebugBuild() guard: the app hands the
  # IMK input menu no route into Sparkle in a Debug build, and this makes the plist say so too,
  # so a scheduled check is impossible even if that guard is ever removed.
  plutil -replace SUEnableAutomaticChecks -bool false "$PLIST"
  # And take the production feed URL out of the Debug bundle altogether, which closes the one
  # route the menu guard does not: 設定… ▸ 更新 keeps its pane (the canon sidebar order must be
  # identical in both channels), and opening it is enough to make DragonUpdater build Sparkle.
  # Without SUFeedURL, SPUUpdater.start() throws, DragonUpdater catches that and returns nil, so
  # canCheckForUpdates is false and the pane's button renders disabled — an honest "updates are
  # off in a local build" rather than a live button pointed at the release appcast. Absence is
  # fine: this runs again on a rebuild into an existing bundle, where the key is already gone.
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$PLIST" 2>/dev/null || true
  # Re-key the localized input-mode display names (倉頡 / 速成) to the .debug mode ids, and
  # re-label the localized app name so the picker/menu show "Yahoo KeyKey 2 Debug" (the
  # localized CFBundleDisplayName here would otherwise override the Info.plist value above).
  for sf in "$APP/Contents/Resources"/*.lproj/InfoPlist.strings; do
    [ -f "$sf" ] || continue
    sed -i '' "s|${RELEASE_BUNDLE_ID}|${DEBUG_BUNDLE_ID}|g" "$sf"
    sed -i '' 's|"Yahoo KeyKey 2"|"Yahoo KeyKey 2 Debug"|g' "$sf"
    # And mark the mode names themselves. Re-keying moved the KEYS to the .debug mode ids but left
    # their VALUES reading exactly "倉頡" / "速成" / "拼音" — character for character the release
    # IME's. These are the strings System Settings ▸ Keyboard ▸ Input Sources actually lists, so the
    # picker showed two identical entries per mode with no way to tell which build you were adding,
    # and the ⌃Space switcher and the menu-bar item were equally ambiguous once both were enabled.
    #
    # That defeated the point of the whole .debug identity: MAC-APP-RELEASE-LIFECYCLE.md requires
    # every hands-on build to say "Debug" visibly, and for an IME the mode name is the only place a
    # user ever sees it — the bundle name suffixed above never appears in the picker's list rows.
    # Reported from a screenshot of two indistinguishable 倉頡 entries.
    #
    # Runs after the re-key so it matches the .debug ids, and only rewrites lines whose key is a
    # .debug mode id, so CFBundleName/CFBundleDisplayName above are untouched. `rm -rf "$APP"` at
    # the top of this script recreates the bundle every build, so this always starts from the
    # pristine source file — the substitution is never applied twice.
    sed -i '' -E "s|^(\"${DEBUG_BUNDLE_ID}\.[A-Za-z]+\" = \"[^\"]*)(\";)$|\1 (Debug)\2|" "$sf"
    # These files are now regex-edited rather than merely re-keyed, so prove each one still parses.
    # A malformed .strings does not fail the build or the launch: macOS silently falls back to
    # showing the raw KEY as the mode name, which would read as a much stranger bug than this one.
    plutil -lint "$sf" >/dev/null
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
