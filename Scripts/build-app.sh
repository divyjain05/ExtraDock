#!/bin/bash
# Builds the SPM executable and assembles it into ExtraDock.app.
# Usage: Scripts/build-app.sh [debug|release]

set -euo pipefail

CONFIG="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ExtraDock"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"

echo "Building ($CONFIG)..."
swift build --package-path "$ROOT_DIR" -c "$CONFIG"

BIN_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "error: built executable not found at $BIN_PATH" >&2
    exit 1
fi

echo "Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -d "$ROOT_DIR/Resources/Assets.xcassets" ]; then
    cp -R "$ROOT_DIR/Resources/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"
fi

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo "First launch on another Mac needs a right-click > Open (Gatekeeper, unsigned build)."
