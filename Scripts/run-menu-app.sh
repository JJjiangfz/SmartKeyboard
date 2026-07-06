#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SmartKeyboard"
BUNDLE_ID="com.jjjiangfz.SmartKeyboard"
BUILD_DIR="$ROOT_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
EXECUTABLE="$MACOS_DIR/$APP_NAME"

cd "$ROOT_DIR"

swift build --product SmartKeyboardApp

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/arm64-apple-macosx/debug/SmartKeyboardApp" "$EXECUTABLE"
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

/usr/bin/pkill -x SmartKeyboardApp 2>/dev/null || true
/usr/bin/pkill -x SmartKeyboard 2>/dev/null || true

open "$BUNDLE_DIR"

echo "Started $BUNDLE_DIR"
echo "Look for 'SmartKeyboard' in the macOS menu bar."
echo "If permissions are needed, grant them to SmartKeyboard in Privacy & Security."

