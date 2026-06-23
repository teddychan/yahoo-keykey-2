#!/bin/bash
# Build App/AppIcon.icns from the source artwork App/AppIcon.png.
#
# App/AppIcon.png (the traditional Yahoo! KeyKey logo, 512×512) is the source of truth.
# This script downsamples it to every standard iconset size with `sips` and assembles the
# icns with `iconutil`. Self-contained and reproducible: edit App/AppIcon.png and re-run.
#
# Requires: sips, iconutil (both ship with macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/App/AppIcon.png"
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$SRC" ]; then
  echo "ERROR: source artwork missing: $SRC" >&2
  exit 1
fi

echo "==> Rendering iconset PNGs from $SRC"
# Standard macOS iconset sizes. The source master is 512×512, so we downsample only
# (no upscaling) — matching the size set of the original Yahoo icon.
for base in 16 32 128 256 512; do
  sips -z "$base" "$base" "$SRC" --out "$ICONSET/icon_${base}x${base}.png" >/dev/null
done

echo "==> Assembling AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ROOT/App/AppIcon.icns"
echo "==> Done: $ROOT/App/AppIcon.icns"
