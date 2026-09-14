#!/bin/bash
# Cuts a Sparkle release: builds ExtraDock.app, zips it, and (re)generates a
# signed appcast.xml. See SPARKLE.md for the one-time key setup and for what to
# do with the output (upload zip to a GitHub Release, publish appcast.xml).
#
# Usage: Scripts/release.sh
#   Version comes from Resources/Info.plist (CFBundleShortVersionString /
#   CFBundleVersion) — bump those there before running, that's the single
#   source of truth Sparkle compares against.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ExtraDock"
APP="$ROOT_DIR/build/$APP_NAME.app"
RELEASES="$ROOT_DIR/build/releases"      # keep past zips here so the appcast can list them
GH_REPO="divyjain05/ExtraDock"

# Sparkle's CLI tools ship inside the SPM artifact once the package is resolved.
find_tool() { find "$ROOT_DIR/.build/artifacts" -name "$1" -type f 2>/dev/null | head -1; }
GENERATE_APPCAST="$(find_tool generate_appcast)"
if [ -z "$GENERATE_APPCAST" ]; then
    echo "error: generate_appcast not found. Run 'swift build' first so SPM fetches Sparkle's tools." >&2
    exit 1
fi

# 1. Build the app (embeds + signs Sparkle.framework).
"$ROOT_DIR/Scripts/build-app.sh" release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "Releasing version $VERSION"

# 2. Archive with ditto (preserves symlinks/permissions — Sparkle requires this,
#    a plain `zip` corrupts the embedded framework's version symlinks).
mkdir -p "$RELEASES"
ZIP="$RELEASES/$APP_NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# 3. Sign every archive in the folder and write appcast.xml. The private EdDSA
#    key is read from the keychain (put there by generate_keys). The download
#    URL is where each zip must actually live — a GitHub Release asset for its tag.
"$GENERATE_APPCAST" \
    --download-url-prefix "https://github.com/$GH_REPO/releases/download/v$VERSION/" \
    "$RELEASES"

echo
echo "Done. Now publish:"
echo "  1. Create GitHub Release tag 'v$VERSION' and upload: $ZIP"
echo "  2. Copy $RELEASES/appcast.xml to the repo root, commit, and push to main"
echo "     (that's the SUFeedURL installed apps poll)."
