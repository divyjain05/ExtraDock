#!/bin/bash
# One-time setup: creates a stable, self-signed code-signing identity so that
# ExtraDock's Accessibility grant survives rebuilds.
#
# Why this exists: ad-hoc signing (codesign --sign -) produces a new code hash
# on every build, and macOS TCC keys the Accessibility grant off that hash — so
# every rebuild silently revoked the grant, and the app fell back to its
# right-edge hover zone instead of anchoring to its Dock icon. A fixed cert
# gives a fixed "designated requirement", which TCC recognizes as the same app
# across rebuilds. Grant Accessibility once, and it stays granted.
#
# The identity is self-signed and NOT trusted by Gatekeeper — that's fine, it's
# only used locally to keep a stable identity for TCC. It has no bearing on the
# notarized Developer ID path if that's ever set up for real distribution.
#
# Usage: Scripts/setup-signing.sh
# Undo:  security delete-keychain ~/Library/Keychains/extradock-signing.keychain-db
#        (then remove it from the search list: security list-keychains -d user -s login.keychain-db)

set -euo pipefail

IDENTITY_CN="ExtraDock Self Signed"
KEYCHAIN="$HOME/Library/Keychains/extradock-signing.keychain-db"
# Non-secret: this password only guards a local, untrusted self-signed dev cert.
# It is intentionally checked in so build-app.sh can unlock the keychain
# unattended. It grants nothing on any machine other than this one.
KEYCHAIN_PASSWORD="extradock-dev"

if [ -f "$KEYCHAIN" ] && security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY_CN"; then
    echo "Signing identity '$IDENTITY_CN' already set up. Nothing to do."
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Generating self-signed code-signing certificate..."
openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMP_DIR/key.pem" -out "$TMP_DIR/cert.pem" \
    -days 3650 -nodes \
    -subj "/CN=$IDENTITY_CN" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "keyUsage=critical,digitalSignature" >/dev/null 2>&1

# -legacy: Apple's importer can't verify OpenSSL 3's default PKCS12 MAC.
openssl pkcs12 -export -legacy \
    -inkey "$TMP_DIR/key.pem" -in "$TMP_DIR/cert.pem" \
    -out "$TMP_DIR/identity.p12" \
    -passout "pass:$KEYCHAIN_PASSWORD" -name "$IDENTITY_CN" >/dev/null 2>&1

echo "Creating dedicated signing keychain at $KEYCHAIN..."
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"          # disable auto-lock timeout
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

echo "Importing identity..."
security import "$TMP_DIR/identity.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PASSWORD" -T /usr/bin/codesign -A >/dev/null 2>&1
# Let codesign use the private key without a GUI prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1

# Add to the user's keychain search list (append, don't clobber existing entries).
EXISTING="$(security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"$//')"
if ! grep -qF "$KEYCHAIN" <<< "$EXISTING"; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s $EXISTING "$KEYCHAIN"
fi

echo
echo "Done. '$IDENTITY_CN' is ready."
echo "Next:"
echo "  1. Scripts/build-app.sh release   (now signs with this stable identity)"
echo "  2. Launch build/ExtraDock.app and grant Accessibility ONCE."
echo "     From then on the grant survives every rebuild."
