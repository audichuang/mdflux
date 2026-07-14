# Build an offline Windows Python runtime for MDFlux portable packaging.
# Same job as bundle-runtime.sh; prefer that script on Linux/macOS/WSL.
#
# Usage:  pwsh -File scripts/bundle-runtime.ps1
#         pwsh -File scripts/bundle-runtime.ps1 -Force

param([switch]$Force)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $root "app\src-tauri\resources\runtime"
$lock = Join-Path $root "app\src-tauri\resources\sidecar\requirements.lock"

$pyTag = "20260623"
$pyVer = "3.12.13"
$pyUrl = "https://github.com/astral-sh/python-build-standalone/releases/download/$pyTag/cpython-$pyVer%2B$pyTag-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"

if (-not (Test-Path $lock)) { throw "Missing $lock" }
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is required (https://docs.astral.sh/uv/)"
}

$pyExe = Join-Path $out "python\python.exe"
if ((Test-Path $pyExe) -and -not $Force) {
    Write-Host "Bundled runtime already present at $out (use -Force to rebuild)."
    exit 0
}

Write-Host "==> Cleaning $out"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("mdflux-runtime-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    $tgz = Join-Path $work "py.tgz"
    Write-Host "==> Downloading CPython $pyVer (Windows x64)"
    Invoke-WebRequest -Uri $pyUrl -OutFile $tgz

    # tar is available on Windows 10+
    tar -xzf $tgz -C $work
    $extracted = Join-Path $work "python"
    if (-not (Test-Path (Join-Path $extracted "python.exe"))) {
        throw "Unexpected archive layout (python\python.exe missing)"
    }
    Move-Item $extracted (Join-Path $out "python")

    $target = Join-Path $out "python\Lib\site-packages"
    Write-Host "==> Installing core packages into site-packages"
    & uv pip install `
        --python-version 3.12 `
        --python-platform x86_64-pc-windows-msvc `
        --target $target `
        --require-hashes `
        -r $lock
    if ($LASTEXITCODE -ne 0) { throw "uv pip install failed" }

    $built = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    @"
bundled=1
python=$pyVer
platform=windows-x86_64
lock=requirements.lock
built=$built
"@ | Set-Content -Path (Join-Path $out "BUNDLED.txt") -Encoding utf8

    @'
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
'@ | Set-Content -Path (Join-Path $out "README.md") -Encoding utf8

    $mb = [math]::Round(((Get-ChildItem $out -Recurse | Measure-Object -Property Length -Sum).Sum) / 1MB, 1)
    Write-Host "==> Done. Offline runtime: $out ($mb MB)"
}
finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}
