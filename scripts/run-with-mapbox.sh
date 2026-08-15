#!/usr/bin/env bash
# Run FirstVue on a device/emulator with Mapbox LIVE map enabled.
# Usage:
#   export MAPBOX_ACCESS_TOKEN=pk....
#   optional: export MAPBOX_STYLE_URI=mapbox://styles/you/your-neon-style
#   ./scripts/run-with-mapbox.sh          # default device
#   ./scripts/run-with-mapbox.sh ios
#   ./scripts/run-with-mapbox.sh android
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${MAPBOX_ACCESS_TOKEN:-}" ]]; then
  echo "MAPBOX_ACCESS_TOKEN is not set."
  echo "Create a public token at https://account.mapbox.com/access-tokens/"
  echo "Then: export MAPBOX_ACCESS_TOKEN=pk...."
  exit 1
fi

DEFINES=(
  "--dart-define=MAPBOX_ACCESS_TOKEN=${MAPBOX_ACCESS_TOKEN}"
)

if [[ -n "${MAPBOX_STYLE_URI:-}" ]]; then
  DEFINES+=("--dart-define=MAPBOX_STYLE_URI=${MAPBOX_STYLE_URI}")
fi

TARGET="${1:-}"
ARGS=()
case "$TARGET" in
  ios) ARGS+=("-d" "iOS") ;;
  android) ARGS+=("-d" "android") ;;
  "") ;;
  *) ARGS+=("-d" "$TARGET") ;;
esac

echo "Running with Mapbox LIVE map (token length: ${#MAPBOX_ACCESS_TOKEN})..."
exec flutter run "${ARGS[@]}" "${DEFINES[@]}"
