#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.jjjiangfz.SmartKeyboard"

tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Reset macOS privacy permissions for $BUNDLE_ID."
echo "Now run: Scripts/run-menu-app.sh --rebuild"
echo "Then add BuildProducts/SmartKeyboard.app or /Applications/SmartKeyboard.app in both Accessibility and Input Monitoring."
