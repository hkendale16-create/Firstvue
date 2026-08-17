#!/usr/bin/env bash
# mapbox_maps_flutter 2.28.x assumes AGP 9 has built-in Kotlin, but FirstVue sets
# android.builtInKotlin=false. Re-apply kotlin-android so release builds succeed.
set -euo pipefail
shopt -s nullglob
for f in "$HOME"/.pub-cache/hosted/pub.dev/mapbox_maps_flutter-*/android/build.gradle; do
  python3 - "$f" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text()
changed = False
old = """apply plugin: 'com.android.library'

// Kotlin is built into AGP 9+. For older AGP (Flutter < 3.44) the
// 'kotlin-android' plugin must still be applied explicitly.
def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
if (agpMajor < 9) {
    apply plugin: 'kotlin-android'
}
"""
new = """apply plugin: 'com.android.library'
// FirstVue/AGP9: android.builtInKotlin=false, so always apply Kotlin for the kotlin {} block.
apply plugin: 'kotlin-android'
"""
if old in text:
    text = text.replace(old, new)
    changed = True
text2 = text.replace(
    'password = System.getenv("SDK_REGISTRY_TOKEN") ?: project.findProperty("SDK_REGISTRY_TOKEN") as String',
    'password = System.getenv("SDK_REGISTRY_TOKEN") ?: (project.findProperty("SDK_REGISTRY_TOKEN") ?: "")'
)
if text2 != text:
    text = text2
    changed = True
if changed:
    p.write_text(text)
    print(f"patched {p}")
else:
    print(f"skip (already patched or unexpected): {p}")
PY
done
