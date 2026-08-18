#!/usr/bin/env bash
# Repair Apple/Xcode filenames that were accidentally stored with a trailing .xml.
# Flutter looks for Runner.xcscheme, contents.xcworkspacedata, *.storyboard, etc.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

repair() {
  local src="$1"
  local dest="${src%.xml}"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ -f "$dest" ]]; then
    rm -f "$src"
    echo "Removed duplicate $src"
  else
    mv "$src" "$dest"
    echo "Renamed $src -> $dest"
  fi
}

while IFS= read -r -d '' f; do
  repair "$f"
done < <(find ios macos -type f \( \
  -name '*.xcworkspacedata.xml' -o \
  -name '*.xcsettings.xml' -o \
  -name '*.xcscheme.xml' -o \
  -name '*.storyboard.xml' -o \
  -name '*.entitlements.xml' \
\) -print0 2>/dev/null || true)

SCHEME="ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme"
if [[ ! -f "$SCHEME" ]]; then
  echo "Missing $SCHEME" >&2
  find ios -name '*xcscheme*' -print >&2 || true
  exit 1
fi
echo "Found $SCHEME"
