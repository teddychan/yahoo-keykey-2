#!/bin/bash
# Build the McBopomofo language model (data.txt) and copy it to Resources/.
# Requires: git, python3, make. Produces ./Resources/data.txt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.lm-build"
mkdir -p "$WORK" "$ROOT/Resources"
if [ ! -d "$WORK/McBopomofo" ]; then
  git clone --depth 1 https://github.com/openvanilla/McBopomofo "$WORK/McBopomofo"
fi
cd "$WORK/McBopomofo/Source/Data"
make            # runs main_compiler.py -> data.txt
cp data.txt "$ROOT/Resources/data.txt"
echo "Wrote $ROOT/Resources/data.txt ($(wc -l < "$ROOT/Resources/data.txt") lines)"
