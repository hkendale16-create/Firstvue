#!/usr/bin/env bash
# Upload the App Store IPA with Apple's Java iTMSTransporter.
# Xcode 26 altool fails with ITunesConnectionAuthenticationErrorDomain -26000
# even when the same App Store Connect API key can fetch signing files.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

IPA=$(ls -1 "$ROOT_DIR"/build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
if [[ -z "$IPA" ]]; then
  echo "No IPA under build/ios/ipa." >&2
  exit 1
fi
echo "Uploading $IPA"

echo "App Store Connect env names present:"
env | awk -F= 'BEGIN{IGNORECASE=1} $1 ~ /(APP_STORE_CONNECT|ASC_|ITMS)/ {print "  " $1}'

KEY_ID="${APP_STORE_CONNECT_KEY_IDENTIFIER:-${APP_STORE_CONNECT_KEY_ID:-}}"
ISSUER="${APP_STORE_CONNECT_ISSUER_ID:-}"
P8="${APP_STORE_CONNECT_PRIVATE_KEY:-}"

if [[ -z "$KEY_ID" || -z "$ISSUER" || -z "$P8" ]]; then
  echo "The FirstVue Developer Portal integration did not export APP_STORE_CONNECT_* vars." >&2
  echo "In Codemagic: Personal account → Integrations → Developer Portal → key named FirstVue." >&2
  exit 1
fi

KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR"
P8_PATH="$KEY_DIR/AuthKey_${KEY_ID}.p8"
umask 077
# Codemagic may store the .p8 with literal \n sequences.
python3 - "$P8_PATH" <<'PY'
import os, pathlib, sys
raw = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
text = raw.replace("\\n", "\n").strip() + "\n"
path = pathlib.Path(sys.argv[1])
path.write_text(text)
os.chmod(path, 0o600)
if "BEGIN" not in text:
    raise SystemExit("APP_STORE_CONNECT_PRIVATE_KEY is not a PEM .p8")
print(f"Wrote {path}")
PY

find_transporter() {
  local candidate
  for candidate in \
    "$(xcrun --find iTMSTransporter 2>/dev/null || true)" \
    "/usr/local/itms/bin/iTMSTransporter" \
    "/Applications/Xcode-26.4.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/itms/bin/iTMSTransporter" \
    "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/itms/bin/iTMSTransporter"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  # Last resort: search Xcode apps.
  local found
  found=$(find /Applications -name iTMSTransporter -type f 2>/dev/null | head -1 || true)
  if [[ -n "$found" && -x "$found" ]]; then
    echo "$found"
    return 0
  fi
  return 1
}

TRANSPORTER=$(find_transporter || true)
if [[ -z "$TRANSPORTER" ]]; then
  echo "iTMSTransporter not found; falling back to fastlane Java transporter."
  export FASTLANE_ITUNES_TRANSPORTER_USE_SHELL_SCRIPT=true
  API_JSON=/tmp/firstvue-asc-api.json
  python3 - "$API_JSON" <<'PY'
import json, os, pathlib, sys
key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"].replace("\\n", "\n").strip()
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "key_id": os.environ.get("APP_STORE_CONNECT_KEY_IDENTIFIER") or os.environ.get("APP_STORE_CONNECT_KEY_ID"),
    "issuer_id": os.environ["APP_STORE_CONNECT_ISSUER_ID"],
    "key": key,
    "in_house": False,
}))
print(f"Wrote {sys.argv[1]}")
PY
  fastlane run upload_to_testflight \
    api_key_path:"$API_JSON" \
    ipa:"$IPA" \
    skip_waiting_for_build_processing:true \
    skip_submission:true
  echo "Uploaded with fastlane / iTMSTransporter."
  exit 0
fi

echo "Using $TRANSPORTER"
"$TRANSPORTER" -m upload \
  -assetFile "$IPA" \
  -apiKey "$KEY_ID" \
  -apiIssuer "$ISSUER" \
  -v informational

echo "Uploaded with iTMSTransporter."
