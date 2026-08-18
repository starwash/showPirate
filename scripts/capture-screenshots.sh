#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/showPirate.app/Contents/MacOS/showPirate" 2>/dev/null | head -1)

if [[ -z "$APP" ]]; then
  echo "Debug build not found. Build the app first:"
  echo "  open ShowPirate.xcodeproj"
  exit 1
fi

if [[ "${1:-}" == "--library-light" ]]; then
  "$APP" --export-screenshots="$ROOT/docs/screenshots" --export-library-light
else
  "$APP" --export-screenshots="$ROOT/docs/screenshots"
fi
echo "Screenshots saved to $ROOT/docs/screenshots"
