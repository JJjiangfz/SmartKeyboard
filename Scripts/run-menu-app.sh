#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SmartKeyboard"
BUNDLE_PRODUCTS_DIR="$ROOT_DIR/BuildProducts"
BUNDLE_DIR="$BUNDLE_PRODUCTS_DIR/${APP_NAME}.app"
EXECUTABLE="$BUNDLE_DIR/Contents/MacOS/$APP_NAME"
REBUILD=0

if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=1
fi

cd "$ROOT_DIR"

if [[ "$REBUILD" == "1" || ! -x "$EXECUTABLE" ]]; then
  "$ROOT_DIR/Scripts/build-app-bundle.sh" --configuration debug --output "$BUNDLE_DIR"
else
  echo "Reusing existing $BUNDLE_DIR"
  echo "Run '$0 --rebuild' only after code changes; rebuilding may require granting permissions again."
fi

/usr/bin/pkill -x SmartKeyboardApp 2>/dev/null || true
/usr/bin/pkill -x SmartKeyboard 2>/dev/null || true

open "$BUNDLE_DIR"

echo "Started $BUNDLE_DIR"
echo "Look for the keyboard icon in the macOS menu bar."
echo "Open the SmartKeyboard menu to check Accessibility and Input Monitoring status."
echo "Permission picker path: $BUNDLE_DIR"
