#!/bin/bash
# Regenerates Resources/AppIcon.icns from generate-icon.swift.
# Usage: Scripts/IconGen/build-icns.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ICONGEN_DIR="$ROOT_DIR/Scripts/IconGen"
ICONSET_DIR="$ICONGEN_DIR/AppIcon.iconset"
MASTER_PNG="$ICONGEN_DIR/icon-1024-master.png"

echo "Rendering master icon..."
swift "$ICONGEN_DIR/generate-icon.swift" "$MASTER_PNG"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

declare -a sizes=(16 32 32 64 128 256 256 512 512 1024)
declare -a names=(
    "icon_16x16.png"
    "icon_16x16@2x.png"
    "icon_32x32.png"
    "icon_32x32@2x.png"
    "icon_128x128.png"
    "icon_128x128@2x.png"
    "icon_256x256.png"
    "icon_256x256@2x.png"
    "icon_512x512.png"
    "icon_512x512@2x.png"
)

echo "Generating iconset sizes..."
for i in "${!sizes[@]}"; do
    sips -z "${sizes[$i]}" "${sizes[$i]}" "$MASTER_PNG" --out "$ICONSET_DIR/${names[$i]}" >/dev/null
done

echo "Building .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/Resources/AppIcon.icns"

echo "Done: $ROOT_DIR/Resources/AppIcon.icns"
