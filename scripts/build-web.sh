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

DART_DEFINE="--dart-define=FIRSTVUE_OAUTH_GOOGLE=true"
DART_DEFINE="$DART_DEFINE --dart-define=FIRSTVUE_GOOGLE_WEB_CLIENT_ID=232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com"
if [ -n "${URL:-}" ]; then
  DART_DEFINE="$DART_DEFINE --dart-define=FIRSTVUE_WEB_URL=${URL}"
elif [ -n "${DEPLOY_PRIME_URL:-}" ]; then
  DART_DEFINE="$DART_DEFINE --dart-define=FIRSTVUE_WEB_URL=${DEPLOY_PRIME_URL}"
fi
if [ -n "${FIRSTVUE_GOOGLE_PLACES_API_KEY:-}" ]; then
  DART_DEFINE="$DART_DEFINE --dart-define=FIRSTVUE_GOOGLE_PLACES_API_KEY=${FIRSTVUE_GOOGLE_PLACES_API_KEY}"
fi

# shellcheck disable=SC2086
# Local CanvasKit so the app still boots if the gstatic CDN is blocked by CSP.
# Skip the PWA service worker so phones do not wait to precache ~5MB before paint.
# Tree-shake icons to keep main.dart.js smaller (default, made explicit).
flutter build web --release \
  --no-wasm-dry-run \
  --no-web-resources-cdn \
  --pwa-strategy=none \
  --tree-shake-icons \
  $DART_DEFINE

# This dart2js build only uses the CanvasKit renderer. Flutter still copies
# skwasm/wimp/webparagraph + *.symbols into build/web/canvaskit — strip them so
# deploys stay lean and nothing can accidentally fetch multi-MB unused WASM.
if [ -d "$ROOT_DIR/build/web/canvaskit" ]; then
  find "$ROOT_DIR/build/web/canvaskit" -type f \( \
      -name 'skwasm*' -o -name 'wimp*' -o -name '*.symbols' \
    \) -delete
  rm -rf "$ROOT_DIR/build/web/canvaskit/webparagraph"
fi

# Latin-subset the Material Roboto fallback Flutter injects (~168KB → much smaller).
ROBOTO="$ROOT_DIR/build/web/assets/fonts/fallback/Roboto-Regular.ttf"
if [ -f "$ROBOTO" ] && command -v pyftsubset >/dev/null 2>&1; then
  pyftsubset "$ROBOTO" \
    --output-file="$ROBOTO" \
    --unicodes='U+0000-00FF,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD' \
    --layout-features='*' \
    --glyph-names --symbol-cmap --legacy-cmap --notdef-glyph --notdef-outline \
    --recommended-glyphs --name-IDs='*' --name-legacy --name-languages='*' \
    --recalc-bounds --recalc-timestamp || true
fi

echo "Build complete: $ROOT_DIR/build/web"
# Tip: do not preload canvaskit/canvaskit.wasm in index.html — Chromium uses
# canvaskit/chromium/canvaskit.wasm and a wrong preload downloads both.
