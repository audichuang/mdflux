#!/usr/bin/env bash
# Build an offline Python runtime for MDFlux packaging.
#
# Downloads CPython (python-build-standalone) and installs core conversion
# packages from requirements.lock into its site-packages.
#
# Platforms:
#   windows-x64   → python/python.exe  (default; Windows portable / NSIS)
#   macos-arm64   → python/bin/python  (macOS Apple Silicon .dmg / Homebrew cask)
#
# Can run on Linux or the target OS as long as curl, tar, and uv are available.
#
# Output: app/src-tauri/resources/runtime/
#
# Usage:
#   bash scripts/bundle-runtime.sh
#   bash scripts/bundle-runtime.sh --platform macos-arm64
#   bash scripts/bundle-runtime.sh --platform windows-x64 --force

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/app/src-tauri/resources/runtime"
LOCK="$ROOT/app/src-tauri/resources/sidecar/requirements.lock"
# Pinned python-build-standalone release.
PY_TAG="20260623"
PY_VER="3.12.13"

PLATFORM="windows-x64"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --platform=*) PLATFORM="${arg#*=}" ;;
    --platform)
      shift || true
      # allow "--platform macos-arm64" form when invoked as: bundle-runtime.sh --platform macos-arm64
      ;;
    --force|-f) FORCE=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    windows-x64|macos-arm64)
      PLATFORM="$arg"
      ;;
  esac
done

# Second pass for "--platform VALUE"
args=("$@")
for i in "${!args[@]}"; do
  if [[ "${args[$i]}" == "--platform" && -n "${args[$((i+1))]:-}" ]]; then
    PLATFORM="${args[$((i+1))]}"
  fi
done

case "$PLATFORM" in
  windows-x64)
    PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_TAG}/cpython-${PY_VER}%2B${PY_TAG}-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"
    UV_PLATFORM="x86_64-pc-windows-msvc"
    # Marker file the app looks for (bootstrap.rs BUNDLED_PYTHON_BIN).
    PY_MARKER="python/python.exe"
    SITE_PACKAGES="python/Lib/site-packages"
    PLATFORM_LABEL="windows-x86_64"
    ;;
  macos-arm64)
    PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_TAG}/cpython-${PY_VER}%2B${PY_TAG}-aarch64-apple-darwin-install_only_stripped.tar.gz"
    UV_PLATFORM="aarch64-apple-darwin"
    PY_MARKER="python/bin/python3"
    SITE_PACKAGES="python/lib/python3.12/site-packages"
    PLATFORM_LABEL="macos-aarch64"
    ;;
  *)
    echo "error: unknown --platform '$PLATFORM' (want windows-x64 | macos-arm64)" >&2
    exit 1
    ;;
esac

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

if [[ -f "$OUT/$PY_MARKER" && $FORCE -eq 0 ]]; then
  # Also require matching platform marker when present.
  if [[ -f "$OUT/BUNDLED.txt" ]] && grep -q "platform=${PLATFORM_LABEL}" "$OUT/BUNDLED.txt" 2>/dev/null; then
    echo "Bundled runtime already present at $OUT for $PLATFORM (use --force to rebuild)."
    exit 0
  fi
fi

echo "==> Cleaning $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/mdflux-runtime.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "==> Downloading CPython ${PY_VER} ($PLATFORM)"
curl -fsSL -o "$WORKDIR/py.tgz" "$PY_URL"
tar -xzf "$WORKDIR/py.tgz" -C "$WORKDIR"
# Archive extracts a top-level "python/" directory.
if [[ ! -d "$WORKDIR/python" ]]; then
  echo "error: unexpected archive layout (python/ missing)" >&2
  find "$WORKDIR" -maxdepth 3 -type f | head -40 >&2
  exit 1
fi
mv "$WORKDIR/python" "$OUT/python"

# Normalize interpreter name expected by bootstrap on macOS.
if [[ "$PLATFORM" == "macos-arm64" ]]; then
  if [[ -f "$OUT/python/bin/python3" && ! -e "$OUT/python/bin/python" ]]; then
    ln -s python3 "$OUT/python/bin/python"
  fi
  if [[ ! -x "$OUT/python/bin/python" && ! -x "$OUT/python/bin/python3" ]]; then
    echo "error: macOS python binary missing under python/bin/" >&2
    ls -la "$OUT/python/bin" >&2 || true
    exit 1
  fi
fi

if [[ ! -f "$OUT/$PY_MARKER" && ! -e "$OUT/python/bin/python" ]]; then
  echo "error: expected interpreter not found at $OUT/$PY_MARKER" >&2
  find "$OUT" -maxdepth 4 -type f | head -40 >&2
  exit 1
fi

echo "==> Installing core packages ($UV_PLATFORM wheels) into site-packages"
mkdir -p "$OUT/$SITE_PACKAGES"
# Cross-platform: fetch target wheels without executing the target interpreter.
uv pip install \
  --python-version 3.12 \
  --python-platform "$UV_PLATFORM" \
  --target "$OUT/$SITE_PACKAGES" \
  --require-hashes \
  -r "$LOCK"

# Marker used by humans / CI; the app only needs the interpreter path to exist.
{
  echo "bundled=1"
  echo "python=${PY_VER}"
  echo "platform=${PLATFORM_LABEL}"
  echo "lock=requirements.lock"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/BUNDLED.txt"

# Restore the tracked README (wiped by the clean step above).
cat > "$OUT/README.md" <<'EOF'
# Offline Python runtime (build artefact)

Filled by `scripts/bundle-runtime.sh` (or `.ps1`) before packaging an **offline** build.

```
runtime/
  BUNDLED.txt
  python/
    # Windows:  python.exe + Lib/site-packages/
    # macOS:    bin/python + lib/python3.12/site-packages/
```

Not committed to git (see root `.gitignore`). Missing tree → first-launch online provision.
EOF

SIZE="$(du -sh "$OUT" | awk '{print $1}')"
echo "==> Done. Offline runtime: $OUT ($SIZE) [$PLATFORM]"
echo "    Windows: pwsh -File scripts/make-installer.ps1 -AlsoPortable"
echo "    macOS:   bash scripts/make-macos-dmg.sh"
