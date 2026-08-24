#!/bin/bash
# Builds ExtraDock.app and packages it into a shareable ExtraDock.dmg with a
# drag-to-Applications shortcut, so recipients can install it the usual way.
#
# Usage: Scripts/make-dmg.sh
#
# Note: the build isn't notarized, so on first launch recipients must
# right-click the app in /Applications > Open (once) to get past Gatekeeper.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ExtraDock"
APP="$ROOT_DIR/build/$APP_NAME.app"
DMG="$ROOT_DIR/build/$APP_NAME.dmg"

# 1. Build the app fresh so the dmg always ships the latest code.
"$ROOT_DIR/Scripts/build-app.sh" release

if [ ! -d "$APP" ]; then
    echo "error: $APP not found after build" >&2
    exit 1
fi

# 2. Stage the app alongside an /Applications shortcut for drag-install.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 3. Build a compressed disk image from the staging folder.
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

echo
echo "Created: $DMG"
echo "Share this file. Tell recipients: drag ExtraDock into Applications, then"
echo "right-click it > Open the first time (unsigned build, Gatekeeper prompt)."
