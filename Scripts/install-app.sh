#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SmartKeyboard"
SOURCE_APP="$ROOT_DIR/BuildProducts/${APP_NAME}.app"
INSTALL_DIR="/Applications"
OPEN_AFTER_INSTALL=1

usage() {
  cat <<USAGE
Usage: Scripts/install-app.sh [--install-dir path] [--no-open]

Builds a release SmartKeyboard.app, installs it into /Applications, and opens it.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="${2:-}"
      shift 2
      ;;
    --no-open)
      OPEN_AFTER_INSTALL=0
      shift
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

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "Install directory does not exist: $INSTALL_DIR" >&2
  exit 1
fi

if [[ "${SMARTKEYBOARD_DISABLE_LOCAL_SIGNING:-0}" != "1" ]]; then
  "$ROOT_DIR/Scripts/ensure-local-signing-identity.sh"
fi

"$ROOT_DIR/Scripts/build-app-bundle.sh" --configuration release --output "$SOURCE_APP"

DEST_APP="$INSTALL_DIR/${APP_NAME}.app"

/usr/bin/pkill -x SmartKeyboardApp 2>/dev/null || true
/usr/bin/pkill -x SmartKeyboard 2>/dev/null || true

rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"

if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
  open "$DEST_APP"
fi

echo "Installed $DEST_APP"
echo "You can now launch SmartKeyboard from Applications."
echo "Grant permissions to $DEST_APP in both Accessibility and Input Monitoring."
