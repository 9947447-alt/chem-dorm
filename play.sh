#!/bin/bash
set -euo pipefail
ROOT="/Users/a0000/Developer/chem-dorm-p0-grid-claim"
cd "$ROOT"

if command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif [ -x /opt/homebrew/bin/godot ]; then
  GODOT="/opt/homebrew/bin/godot"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "找不到 godot。先 brew install --cask godot"
  exit 1
fi

echo "Godot: $GODOT"
echo "项目: $ROOT"
exec "$GODOT" --path "$ROOT"
