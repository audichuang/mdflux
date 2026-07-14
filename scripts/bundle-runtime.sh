#!/usr/bin/env bash
# Build an offline Windows Python runtime for MDFlux portable packaging.
#
# Downloads CPython (python-build-standalone, Windows x64) and installs the
# core conversion packages from requirements.lock into its site-packages.
# Can run on Linux or Windows (Git Bash / WSL) as long as curl, tar, and uv
# are available — the Windows wheels are fetched cross-platform via uv.
#
# Output: app/src-tauri/resources/runtime/python/python.exe (+ site-packages)
#
# Usage:
#   bash scripts/bundle-runtime.sh
#   bash scripts/bundle-runtime.sh --force   # wipe and rebuild

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/app/src-tauri/resources/runtime"
LOCK="$ROOT/app/src-tauri/resources/sidecar/requirements.lock"
# Pinned python-build-standalone release (Windows x64, install_only_stripped).
PY_TAG="20260623"
PY_VER="3.12.13"
PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_TAG}/cpython-${PY_VER}%2B${PY_TAG}-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=1 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
  esac
done

if [[ ! -f "$LOCK" ]]; then
  echo "error: missing $LOCK" >&2
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "error: uv is required (https://docs.astral.sh/uv/)" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 1
fi

if [[ -f "$OUT/python/python.exe" && $FORCE -eq 0 ]]; then
  echo "Bundled runtime already present at $OUT (use --force to rebuild)."
  exit 0
fi

echo "==> Cleaning $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/mdflux-runtime.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "==> Downloading CPython ${PY_VER} (Windows x64)"
curl -fsSL -o "$WORKDIR/py.tgz" "$PY_URL"
tar -xzf "$WORKDIR/py.tgz" -C "$WORKDIR"
# Archive extracts a top-level "python/" directory.
if [[ ! -f "$WORKDIR/python/python.exe" ]]; then
  echo "error: unexpected archive layout (python/python.exe missing)" >&2
  find "$WORKDIR" -maxdepth 3 -type f | head -40 >&2
  exit 1
fi
mv "$WORKDIR/python" "$OUT/python"

echo "==> Installing core packages (Windows wheels) into site-packages"
# Cross-platform: fetch win_amd64 wheels without executing the Windows interpreter.
uv pip install \
  --python-version 3.12 \
  --python-platform x86_64-pc-windows-msvc \
  --target "$OUT/python/Lib/site-packages" \
  --require-hashes \
  -r "$LOCK"

# Marker used by humans / CI; the app only needs python.exe to exist.
{
  echo "bundled=1"
  echo "python=${PY_VER}"
  echo "platform=windows-x86_64"
  echo "lock=requirements.lock"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/BUNDLED.txt"

# Restore the tracked README (wiped by the clean step above).
cat > "$OUT/README.md" <<'EOF'
# Offline Python runtime (build artefact)

This folder is filled by `scripts/bundle-runtime.sh` (or `.ps1`) before packaging
an **offline** portable zip.

Expected layout after bundling:

```
runtime/
  BUNDLED.txt
  python/
    python.exe          # Windows x64 CPython
    python312.dll
    Lib/site-packages/  # markitdown + core format deps
    …
```

It is not committed to git (see root `.gitignore`). If this tree is missing, the
app falls back to the classic first-launch online provision into `%APPDATA%`.
EOF

SIZE="$(du -sh "$OUT" | awk '{print $1}')"
echo "==> Done. Offline runtime: $OUT ($SIZE)"
echo "    Next: pwsh -File scripts/make-portable.ps1   # on Windows, builds the zip"
