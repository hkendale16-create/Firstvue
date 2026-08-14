#!/usr/bin/env bash
# Builds FirstVue for web on Linux (Netlify, GitHub Actions, etc.)
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ ! -d "$FLUTTER_DIR/bin" ]; then
  echo "Installing Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web
flutter precache --web
flutter pub get

DART_DEFINE=""
if [ -n "${URL:-}" ]; then
  DART_DEFINE="--dart-define=FIRSTVUE_WEB_URL=${URL}"
elif [ -n "${DEPLOY_PRIME_URL:-}" ]; then
  DART_DEFINE="--dart-define=FIRSTVUE_WEB_URL=${DEPLOY_PRIME_URL}"
fi

# shellcheck disable=SC2086
# Local CanvasKit so the app still boots if the gstatic CDN is blocked by CSP.
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn $DART_DEFINE

echo "Build complete: $ROOT_DIR/build/web"
