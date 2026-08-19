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

ISSUER="${APP_STORE_CONNECT_ISSUER_ID:-}"
P8="${APP_STORE_CONNECT_PRIVATE_KEY:-}"

if [[ -z "$ISSUER" || -z "$P8" ]]; then
  echo "The FirstVue Developer Portal integration did not export APP_STORE_CONNECT_* vars." >&2
  echo "In Codemagic: Personal account → Integrations → Developer Portal → key named FirstVue." >&2
  exit 1
fi

# Codemagic's form is labeled "Key ID from Apple"; the env often is the
# placeholder "from Apple". Recover the real id from AuthKey_<id>.p8.
KEY_ID="$(
  python3 - "$ROOT_DIR/scripts" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
from pathlib import Path
from asc_api_key import resolve_asc_key_id
home = Path.home()
try:
    print(
        resolve_asc_key_id(
            os.environ.get("APP_STORE_CONNECT_KEY_IDENTIFIER")
            or os.environ.get("APP_STORE_CONNECT_KEY_ID"),
            os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY"),
            search_dirs=[
                str(home / ".appstoreconnect" / "private_keys"),
                str(home / "private_keys"),
            ],
        )
    )
except ValueError as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PY
)"
export RESOLVED_ASC_KEY_ID="$KEY_ID"
echo "Using App Store Connect Key ID $KEY_ID"

if [[ ! "$ISSUER" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "APP_STORE_CONNECT_ISSUER_ID is '$ISSUER' — it must be the UUID above the keys table." >&2
  exit 1
fi

KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR" "$HOME/private_keys" "$ROOT_DIR/private_keys"
P8_PATH="$KEY_DIR/AuthKey_${KEY_ID}.p8"
umask 077

python3 - "$P8_PATH" <<'PY'
import base64
import binascii
import os
import pathlib
import re
import sys

raw = os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY") or ""
raw = raw.strip().strip('"').strip("'")
raw = raw.replace("\r\n", "\n").replace("\\n", "\n").replace("\\r", "")

def is_pem(text: str) -> bool:
    t = text.lstrip()
    return t.startswith("-----BEGIN") and "PRIVATE KEY" in t

def b64decode(s: str):
    compact = re.sub(r"\s+", "", s)
    if not compact:
        return None
    pad = (-len(compact)) % 4
    compact += "=" * pad
    try:
        return base64.b64decode(compact, validate=False)
    except (binascii.Error, ValueError):
        return None

kind = "unknown"
text = None
raw_for_der = None

if raw.startswith("@file:"):
    path = pathlib.Path(raw[len("@file:"):])
    blob = path.read_bytes()
    kind = "file"
    try:
        decoded = blob.decode("utf-8")
    except UnicodeDecodeError:
        decoded = ""
    if is_pem(decoded):
        text = decoded
        kind = "file-pem"
    elif blob[:1] == b"\x30":
        raw_for_der = blob
    else:
        raw = decoded or raw
else:
    raw_for_der = None

if text is None and os.path.isfile(raw) and len(raw) < 512:
    blob = pathlib.Path(raw).read_bytes()
    kind = "path"
    try:
        decoded = blob.decode("utf-8")
    except UnicodeDecodeError:
        decoded = ""
    if is_pem(decoded):
        text = decoded
        kind = "path-pem"
    elif blob[:1] == b"\x30":
        raw_for_der = blob

if text is None and is_pem(raw):
    text = raw
    kind = "pem"

if text is None and raw_for_der is not None:
    der_path = pathlib.Path("/tmp/firstvue-asc.der")
    der_path.write_bytes(raw_for_der)
    import subprocess
    text = subprocess.check_output(
        ["openssl", "pkey", "-inform", "DER", "-in", str(der_path)],
        stderr=subprocess.STDOUT,
        text=True,
    )
    kind = "der"

if text is None:
    # Codemagic's Developer Portal integration injects base64 of the .p8.
    blob = b64decode(raw)
    if blob:
        try:
            decoded = blob.decode("utf-8")
        except UnicodeDecodeError:
            decoded = ""
        if is_pem(decoded):
            text = decoded
            kind = "b64-pem"
        elif decoded.startswith("-----"):
            text = decoded
            kind = "b64-text"
        else:
            # Nested base64, or DER PKCS#8.
            nested = b64decode(decoded) if decoded else None
            if nested:
                try:
                    nested_text = nested.decode("utf-8")
                except UnicodeDecodeError:
                    nested_text = ""
                if is_pem(nested_text):
                    text = nested_text
                    kind = "b64-b64-pem"
            if text is None and blob[:1] == b"\x30":
                der_path = pathlib.Path("/tmp/firstvue-asc.der")
                der_path.write_bytes(blob)
                import subprocess
                pem = subprocess.check_output(
                    ["openssl", "pkey", "-inform", "DER", "-in", str(der_path)],
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                text = pem
                kind = "b64-der"
            if text is None:
                body = re.sub(r"\s+", "", raw)
                wrapped = "\n".join(body[i : i + 64] for i in range(0, len(body), 64))
                text = (
                    "-----BEGIN PRIVATE KEY-----\n"
                    f"{wrapped}\n"
                    "-----END PRIVATE KEY-----\n"
                )
                kind = "wrapped-b64"

if text is None:
    raise SystemExit("Could not parse APP_STORE_CONNECT_PRIVATE_KEY")

text = text.replace("\r\n", "\n").strip() + "\n"
if not is_pem(text):
    raise SystemExit(f"Normalized key is still not PEM (kind={kind}, len={len(raw)})")

path = pathlib.Path(sys.argv[1])
path.write_text(text)
os.chmod(path, 0o600)
print(f"Wrote {path} kind={kind} src_len={len(raw)} pem_len={len(text)}")
PY

cp "$P8_PATH" "$HOME/private_keys/AuthKey_${KEY_ID}.p8"
cp "$P8_PATH" "$ROOT_DIR/private_keys/AuthKey_${KEY_ID}.p8"
chmod 600 "$HOME/private_keys/AuthKey_${KEY_ID}.p8" "$ROOT_DIR/private_keys/AuthKey_${KEY_ID}.p8"

if ! openssl pkey -in "$P8_PATH" -noout >/dev/null 2>&1; then
  echo "Normalized .p8 is not a readable private key (openssl pkey failed)." >&2
  exit 1
fi
echo "API key PEM validates with openssl."

is_stub_transporter() {
  local p="$1"
  case "$p" in
    */Developer/usr/bin/iTMSTransporter) return 0 ;;
  esac
  if grep -q "part of Transporter" "$p" 2>/dev/null; then
    return 0
  fi
  return 1
}

find_transporter() {
  local candidate
  for candidate in \
    "/usr/local/itms/bin/iTMSTransporter" \
    "/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter" \
    "/Applications/Xcode-26.4.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/itms/bin/iTMSTransporter" \
    "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/itms/bin/iTMSTransporter"
  do
    if [[ -n "$candidate" && -x "$candidate" ]] && ! is_stub_transporter "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  local found
  while IFS= read -r found; do
    if [[ -x "$found" ]] && ! is_stub_transporter "$found"; then
      echo "$found"
      return 0
    fi
  done < <(find /usr/local/itms /Applications/Transporter.app /Applications/Xcode*.app -name iTMSTransporter -type f 2>/dev/null || true)
  return 1
}

install_transporter() {
  if [[ -x /usr/local/itms/bin/iTMSTransporter ]]; then
    return 0
  fi
  echo "Installing Apple iTMSTransporter into /usr/local/itms"
  local url="https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa/ra/resources/download/public/Transporter__OSX/bin/"
  curl -fL --retry 4 --retry-delay 3 "$url" -o /tmp/itmstransporter.pkg
  sudo installer -pkg /tmp/itmstransporter.pkg -target /
}

TRANSPORTER=$(find_transporter || true)
if [[ -z "$TRANSPORTER" ]]; then
  install_transporter || true
  TRANSPORTER=$(find_transporter || true)
fi
if [[ -z "$TRANSPORTER" ]]; then
  echo "iTMSTransporter not found; falling back to fastlane Java transporter."
  export FASTLANE_ITUNES_TRANSPORTER_USE_SHELL_SCRIPT=true
  API_JSON=/tmp/firstvue-asc-api.json
  python3 - "$API_JSON" "$P8_PATH" <<'PY'
import json, pathlib, sys
pem = pathlib.Path(sys.argv[2]).read_text()
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "key_id": __import__("os").environ["RESOLVED_ASC_KEY_ID"],
    "issuer_id": __import__("os").environ["APP_STORE_CONNECT_ISSUER_ID"],
    "key": pem,
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
