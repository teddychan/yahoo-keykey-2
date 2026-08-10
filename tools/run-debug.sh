#!/usr/bin/env bash
# Build + install + launch a LOCAL DEBUG build of Yahoo KeyKey 2.
#
# It registers as a SEPARATE input method — "Yahoo KeyKey 2 Debug", bundle id
# com.dragonapp.inputmethod.yahoo-keykey.debug — so it never collides with or shadows the installed
# RELEASE IME (com.dragonapp.inputmethod.yahoo-keykey). Two bundles sharing the release id register as
# duplicates in Launch Services and hide the real input source from the Input Sources picker.
#
# Safe to run alongside the GitHub release install. Any extra args are forwarded
# to build-app.sh (e.g. --build-lm to regenerate data.txt first).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEBUG_NAME="Yahoo KeyKey 2 Debug"
SRC="$ROOT/build/${DEBUG_NAME}.app"
DST="$HOME/Library/Input Methods/${DEBUG_NAME}.app"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "==> Building debug-id app"
KEYKEY_DEBUG_ID=1 "$ROOT/tools/build-app.sh" "$@"

echo "==> Installing to ~/Library/Input Methods"
pkill -f "${DEBUG_NAME}.app/Contents/MacOS" 2>/dev/null || true
sleep 1
rm -rf "$DST"
mkdir -p "$HOME/Library/Input Methods"
cp -R "$SRC" "$DST"

echo "==> Registering + launching"
"$LSREG" -f "$DST" 2>/dev/null || true
# -n launches the bundle at THIS exact path. A plain `open` resolves through Launch Services,
# which is free to activate some other registered copy of the same id — and this repo carries
# several worktrees, each able to leave a `build/Yahoo KeyKey 2 Debug.app` registered, so
# "debugging a binary you did not just compile" is a live hazard here rather than a theoretical
# one. The release IME is a different id and was never reachable either way.
open -n "$DST"

cat <<EOF

Debug IME installed: $DST
Add it in System Settings -> Keyboard -> Input Sources -> + -> Chinese, Traditional ->
"Yahoo KeyKey 2 Debug". If it doesn't appear, log out/in once (it registers separately
from the release IME).
EOF
