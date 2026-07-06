#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SmartKeyboard"
BUNDLE_ID="com.jjjiangfz.SmartKeyboard"
SWIFT_BUILD_DIR="$ROOT_DIR/.build"
BUNDLE_PRODUCTS_DIR="$ROOT_DIR/BuildProducts"
BUNDLE_DIR="$BUNDLE_PRODUCTS_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
EXECUTABLE="$MACOS_DIR/$APP_NAME"
REBUILD=0

if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=1
fi

cd "$ROOT_DIR"

if [[ "$REBUILD" == "1" || ! -x "$EXECUTABLE" ]]; then
  swift build --product SmartKeyboardApp

  rm -rf "$BUNDLE_DIR"
  mkdir -p "$MACOS_DIR"
  cp "$SWIFT_BUILD_DIR/arm64-apple-macosx/debug/SmartKeyboardApp" "$EXECUTABLE"
  chmod +x "$EXECUTABLE"

  cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSInputMonitoringUsageDescription</key>
  <string>SmartKeyboard observes key events locally to switch between selected Chinese and English input sources.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>SmartKeyboard may open System Settings when permissions are missing.</string>
</dict>
</plist>
PLIST

  if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$BUNDLE_DIR" >/dev/null 2>&1 || true
  fi
else
  echo "Reusing existing $BUNDLE_DIR"
  echo "Run '$0 --rebuild' only after code changes; rebuilding may require granting permissions again."
fi

/usr/bin/pkill -x SmartKeyboardApp 2>/dev/null || true
/usr/bin/pkill -x SmartKeyboard 2>/dev/null || true

open "$BUNDLE_DIR"

echo "Started $BUNDLE_DIR"
echo "Look for 'SmartKeyboard' in the macOS menu bar."
echo "Open the SmartKeyboard menu to check Accessibility and Input Monitoring status."
echo "Permission picker path: $BUNDLE_DIR"
