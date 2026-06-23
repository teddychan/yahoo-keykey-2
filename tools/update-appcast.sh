#!/bin/bash
# EdDSA-sign a release .zip and (re)generate appcast.xml for KeyKey.
#
# Usage: tools/update-appcast.sh <path-to-zip> <version> <out-appcast.xml>
# Stages the zip into a clean temp dir, runs Sparkle's generate_appcast (which
# reads the EdDSA private key from the Keychain and fills in sparkle:edSignature
# + length), and points enclosure URLs at the GitHub release download.
set -euo pipefail

ZIP="${1:?usage: update-appcast.sh <zip> <version> <out.xml>}"
VERSION="${2:?missing version}"
OUT="${3:?missing output appcast path}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GENERATE_APPCAST="$ROOT/build/sparkle/bin/generate_appcast"
REPO="teddychan/yahoo-keykey-2"
DL_BASE="https://github.com/$REPO/releases/download"

test -x "$GENERATE_APPCAST" || { echo "ERROR: run tools/fetch-sparkle.sh first" >&2; exit 1; }
test -f "$ZIP" || { echo "ERROR: zip not found: $ZIP" >&2; exit 1; }

# Stage only this zip so generate_appcast cannot pick up other archives in build/.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$ZIP" "$WORK/"

"$GENERATE_APPCAST" \
  --download-url-prefix "$DL_BASE/v$VERSION/" \
  --maximum-deltas 0 \
  -o "$OUT" \
  "$WORK"

# KeyKey declares no minimumSystemVersion / hardwareRequirements in the app
# Info.plist (they live only in the appcast), so inject them into each <item>
# if generate_appcast did not.
if ! grep -q "sparkle:minimumSystemVersion" "$OUT"; then
  /usr/bin/sed -i '' 's#</item>#    <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>\
    <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>\
</item>#' "$OUT"
fi

echo "==> Wrote appcast: $OUT"
echo "    Copy it to the website repo at docs/keykey/appcast.xml and commit."
