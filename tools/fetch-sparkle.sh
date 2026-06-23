#!/bin/bash
# Download a pinned Sparkle 2 release, verify its checksum, and extract
# Sparkle.framework + Sparkle's bin/ tools into a gitignored cache.
# Idempotent: re-running with the cache present is a no-op.
#
# Requires: curl, shasum, tar (with xz support). Produces:
#   build/sparkle/Sparkle.framework
#   build/sparkle/bin/{sign_update,generate_keys,generate_appcast}
set -euo pipefail

SPARKLE_VERSION="2.9.0"
SPARKLE_SHA256="01e0f0ebf6614061ea816d414de50f937d64ffa6822ad572243031ca3676fe19"   # pinned in Step 2 below

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/build/sparkle"
TARBALL="$CACHE/Sparkle-$SPARKLE_VERSION.tar.xz"
URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"

if [ -d "$CACHE/Sparkle.framework" ] && [ -x "$CACHE/bin/sign_update" ]; then
  echo "==> Sparkle $SPARKLE_VERSION already cached at $CACHE"
  exit 0
fi

mkdir -p "$CACHE"
echo "==> Downloading Sparkle $SPARKLE_VERSION"
curl -fSL "$URL" -o "$TARBALL"

echo "==> Verifying checksum"
ACTUAL="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
if [ "$SPARKLE_SHA256" = "PASTE_AFTER_STEP_2" ]; then
  echo "ERROR: SPARKLE_SHA256 is unset. Computed checksum is:"
  echo "  $ACTUAL"
  echo "Paste it into SPARKLE_SHA256 at the top of this script, then re-run." >&2
  exit 1
fi
if [ "$ACTUAL" != "$SPARKLE_SHA256" ]; then
  echo "ERROR: checksum mismatch: expected $SPARKLE_SHA256, got $ACTUAL" >&2
  exit 1
fi

echo "==> Extracting Sparkle.framework + bin/"
tar -xJf "$TARBALL" -C "$CACHE"
# The tarball lays out Sparkle.framework and bin/ at its root.
test -d "$CACHE/Sparkle.framework" || { echo "ERROR: Sparkle.framework not found after extract" >&2; exit 1; }
test -x "$CACHE/bin/sign_update"  || { echo "ERROR: bin/sign_update not found after extract" >&2; exit 1; }
echo "==> Done: $CACHE"
