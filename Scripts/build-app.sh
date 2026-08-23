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
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -d "$ROOT_DIR/Resources/Assets.xcassets" ]; then
    cp -R "$ROOT_DIR/Resources/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"
fi

# Prefer a stable, self-signed identity (Scripts/setup-signing.sh) so the code
# hash — and therefore the Accessibility (TCC) grant — stays constant across
# rebuilds. Ad-hoc signing changes the hash every build and silently revokes
# the grant, which drops the app back to its right-edge hover fallback. Fall
# back to ad-hoc when the identity isn't set up so the repo still builds.
SIGN_IDENTITY="ExtraDock Self Signed"
SIGN_KEYCHAIN="$HOME/Library/Keychains/extradock-signing.keychain-db"
SIGN_KEYCHAIN_PASSWORD="extradock-dev"

if [ -f "$SIGN_KEYCHAIN" ] && security find-identity -p codesigning "$SIGN_KEYCHAIN" 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    echo "Signing with stable identity '$SIGN_IDENTITY'..."
    security unlock-keychain -p "$SIGN_KEYCHAIN_PASSWORD" "$SIGN_KEYCHAIN"
    codesign --force --deep --sign "$SIGN_IDENTITY" --keychain "$SIGN_KEYCHAIN" "$APP_BUNDLE"
else
    echo "Ad-hoc signing (run Scripts/setup-signing.sh to keep the Accessibility grant across rebuilds)..."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "Done: $APP_BUNDLE"
echo "First launch on another Mac needs a right-click > Open (Gatekeeper, unsigned build)."
