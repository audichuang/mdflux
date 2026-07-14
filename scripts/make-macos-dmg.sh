#!/usr/bin/env bash
# Build MDFlux as a macOS .dmg (Apple Silicon) with offline Python runtime.
#
# Output: dist/MDFlux_<version>_aarch64.dmg
#
# Usage (on macOS arm64, or CI macos-latest):
#   bash scripts/make-macos-dmg.sh
#   bash scripts/make-macos-dmg.sh --force-runtime
#   bash scripts/make-macos-dmg.sh --skip-runtime   # online provision model

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
RUNTIME="$ROOT/app/src-tauri/resources/runtime"
APP_DIR="$ROOT/app"

FORCE_RUNTIME=0
SKIP_RUNTIME=0
for arg in "$@"; do
  case "$arg" in
    --force-runtime|-f) FORCE_RUNTIME=1 ;;
    --skip-runtime) SKIP_RUNTIME=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: make-macos-dmg.sh must run on macOS (got $(uname -s))" >&2
  exit 1
fi

if [[ "$SKIP_RUNTIME" -eq 0 ]]; then
  RT_ARGS=(--platform macos-arm64)
  if [[ "$FORCE_RUNTIME" -eq 1 ]]; then
    RT_ARGS+=(--force)
  fi
  bash "$ROOT/scripts/bundle-runtime.sh" "${RT_ARGS[@]}"
  if [[ ! -e "$RUNTIME/python/bin/python" && ! -e "$RUNTIME/python/bin/python3" ]]; then
    echo "error: offline runtime missing under $RUNTIME" >&2
    exit 1
  fi
else
  echo "SkipRuntime: dmg will rely on first-launch online provision."
fi

echo "==> npm ci + tauri build (dmg, aarch64)"
cd "$APP_DIR"
npm ci
# Host arm64 macos-latest builds native aarch64; only request dmg (not nsis).
npx tauri build --bundles dmg

# Locate produced dmg (bash 3.2-safe — macOS default bash)
DMG="$(find "$ROOT/app/src-tauri/target" -type f -name "*.dmg" 2>/dev/null | sort -r | head -1 || true)"
if [[ -z "$DMG" || ! -f "$DMG" ]]; then
  echo "error: no .dmg found under app/src-tauri/target" >&2
  exit 1
fi
echo "Found dmg: $DMG"

VERSION="$(python3 -c "import json; print(json.load(open('$ROOT/app/src-tauri/tauri.conf.json'))['version'])")"
mkdir -p "$DIST"
OUT="$DIST/MDFlux_${VERSION}_aarch64.dmg"
cp -f "$DMG" "$OUT"
MB="$(du -m "$OUT" | awk '{print $1}')"
echo "==> DMG: $OUT (${MB} MB)"
echo "    Homebrew cask URL pattern: …/releases/download/v${VERSION}/MDFlux_${VERSION}_aarch64.dmg"
