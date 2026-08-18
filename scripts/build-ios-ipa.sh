#!/usr/bin/env bash
# Build a signed App Store IPA for FirstVue 1.0.8 (build 9).
# Must run on macOS with Xcode, CocoaPods, and an Apple Developer team.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on a Mac. Linux cannot produce an App Store .ipa." >&2
  echo "From Windows, start Codemagic workflow \"iOS App Store 1.0.8\" instead." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not on PATH. Install it, then retry." >&2
  exit 1
fi

flutter pub get
(cd ios && pod install)

flutter build ipa --release \
  --build-name=1.0.8 \
  --build-number=9 \
  --dart-define=FIRSTVUE_OAUTH_GOOGLE=true \
  --dart-define=FIRSTVUE_GOOGLE_WEB_CLIENT_ID=232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com

IPA=$(ls -1 "$ROOT_DIR"/build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
if [[ -z "$IPA" ]]; then
  echo "No .ipa found under build/ios/ipa. Open ios/Runner.xcworkspace in Xcode, pick a Team, then rerun." >&2
  exit 1
fi

DEST="$ROOT_DIR/build/ios/ipa/FirstVue-1.0.8+9.ipa"
if [[ "$IPA" != "$DEST" ]]; then
  cp "$IPA" "$DEST"
fi

echo "App Store upload file:"
echo "  $DEST"
echo "Open Transporter and deliver that file."
