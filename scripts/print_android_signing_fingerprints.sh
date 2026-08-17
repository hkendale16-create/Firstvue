#!/usr/bin/env bash
# Print SHA-1 / SHA-256 for an Android keystore (Google Cloud OAuth + assetlinks).
# Usage:
#   ./scripts/print_android_signing_fingerprints.sh ~/upload-keystore.jks upload
#   ./scripts/print_android_signing_fingerprints.sh  # debug keystore defaults

set -euo pipefail

KEYSTORE="${1:-$HOME/.android/debug.keystore}"
ALIAS="${2:-androiddebugkey}"

if [[ ! -f "$KEYSTORE" ]]; then
  echo "Keystore not found: $KEYSTORE" >&2
  echo "Generate upload keystore first, or pass an absolute path." >&2
  exit 1
fi

echo "Keystore: $KEYSTORE"
echo "Alias:    $ALIAS"
echo

if [[ "$ALIAS" == "androiddebugkey" && "$KEYSTORE" == *debug.keystore ]]; then
  # Default Android debug store password
  keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass android -keypass android
else
  echo "Enter keystore password when prompted."
  keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS"
fi

echo
echo "Copy SHA1  → Google Cloud → Credentials → Android OAuth client"
echo "Copy SHA256 → web/.well-known/assetlinks.json (Play App Links)"
echo "Package name: com.FirstVue"
