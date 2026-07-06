#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SmartKeyboard"
BUNDLE_ID="com.jjjiangfz.SmartKeyboard"
CONFIGURATION="release"
BUNDLE_DIR="$ROOT_DIR/BuildProducts/${APP_NAME}.app"
APP_ICON="$ROOT_DIR/Assets/AppIcon/SmartKeyboard.icns"

usage() {
  cat <<USAGE
Usage: Scripts/build-app-bundle.sh [--configuration debug|release] [--output path]

Builds SmartKeyboardApp and wraps it in a clickable macOS .app bundle.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    -o|--output)
      BUNDLE_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$CONFIGURATION" in
  debug|release)
    ;;
  *)
    echo "Configuration must be 'debug' or 'release'." >&2
    exit 1
    ;;
esac

if [[ "$BUNDLE_DIR" != /* ]]; then
  BUNDLE_DIR="$ROOT_DIR/$BUNDLE_DIR"
fi

if [[ ! -f "$APP_ICON" ]]; then
  echo "Missing app icon: $APP_ICON" >&2
  echo "Regenerate it with: swift Scripts/generate-app-icon.swift" >&2
  exit 1
fi

CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/$APP_NAME"

cd "$ROOT_DIR"

swift build --configuration "$CONFIGURATION" --product SmartKeyboardApp
SWIFT_BUILD_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
BUILT_EXECUTABLE="$SWIFT_BUILD_DIR/SmartKeyboardApp"

if [[ ! -x "$BUILT_EXECUTABLE" ]]; then
  echo "Built executable not found: $BUILT_EXECUTABLE" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILT_EXECUTABLE" "$EXECUTABLE"
cp "$APP_ICON" "$RESOURCES_DIR/SmartKeyboard.icns"
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
  <key>CFBundleIconFile</key>
  <string>SmartKeyboard</string>
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

echo "Built $BUNDLE_DIR"
