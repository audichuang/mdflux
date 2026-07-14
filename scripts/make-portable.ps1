# Build MDFlux and package it as a portable, extract-and-run zip (no installer).
#
# Offline mode (default): ships a full Windows Python runtime + core packages
# inside the zip so first launch needs no internet and no provision download.
# OCR / audio engines are NOT bundled (optional, still installable only after a
# classic online provision — not the portable offline path).
#
# Usage:  pwsh -File scripts\make-portable.ps1
#         pwsh -File scripts\make-portable.ps1 -NoBuild      # zip existing release build
#         pwsh -File scripts\make-portable.ps1 -SkipRuntime  # online-provision model (small zip)
#         pwsh -File scripts\make-portable.ps1 -ForceRuntime # rebuild the offline runtime

param(
    [switch]$NoBuild,
    [switch]$SkipRuntime,
    [switch]$ForceRuntime
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$rel  = Join-Path $root "app\src-tauri\target\release"
$dist = Join-Path $root "dist"
$runtime = Join-Path $root "app\src-tauri\resources\runtime"

if (-not $SkipRuntime) {
    $bundlePs1 = Join-Path $PSScriptRoot "bundle-runtime.ps1"
    $bundleSh  = Join-Path $PSScriptRoot "bundle-runtime.sh"
    $args = @()
    if ($ForceRuntime) { $args += "-Force" }
    if (Test-Path $bundlePs1) {
        & $bundlePs1 @args
    } elseif (Get-Command bash -ErrorAction SilentlyContinue) {
        $shArgs = @()
        if ($ForceRuntime) { $shArgs += "--force" }
        & bash $bundleSh @shArgs
        if ($LASTEXITCODE -ne 0) { throw "bundle-runtime.sh failed" }
    } else {
        throw "Need scripts/bundle-runtime.ps1 or bash + bundle-runtime.sh to build the offline runtime."
    }
    if (-not (Test-Path (Join-Path $runtime "python\python.exe"))) {
        throw "Offline runtime missing at $runtime after bundle step."
    }
} else {
    Write-Host "SkipRuntime: zip will rely on first-launch online provision."
}

if (-not $NoBuild) {
    # --no-bundle: compile app.exe + stage resources, but DO NOT build an installer.
    # MDFlux ships as a portable, extract-and-run zip — no NSIS installer.
    Push-Location (Join-Path $root "app")
    try { npm run tauri build -- --no-bundle } finally { Pop-Location }
}

$exe = Join-Path $rel "app.exe"
$res = Join-Path $rel "resources"
if (-not (Test-Path $exe)) { throw "Release build not found at $exe. Run without -NoBuild first." }

# Read version from tauri.conf.json for the zip name.
$conf = Get-Content (Join-Path $root "app\src-tauri\tauri.conf.json") -Raw | ConvertFrom-Json
$version = $conf.version

New-Item -ItemType Directory -Force -Path $dist | Out-Null
$suffix = if ($SkipRuntime) { "portable" } else { "portable_offline" }
$zip = Join-Path $dist "MDFlux_${version}_${suffix}.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

# Stage the payload so the shipped executable is MDFlux.exe (the build output is app.exe
# because the Rust crate is named "app"; users are told to run MDFlux.exe).
$stage = Join-Path $dist "_portable_stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $exe (Join-Path $stage "MDFlux.exe")
Copy-Item $res -Destination $stage -Recurse

# Safety net: if tauri did not stage the runtime (e.g. resource glob missed),
# copy it next to the other resources so the offline path still works.
$stageRuntimePy = Join-Path $stage "resources\runtime\python\python.exe"
if (-not $SkipRuntime -and -not (Test-Path $stageRuntimePy)) {
    Write-Host "Runtime not in release resources — copying from $runtime"
    $destRt = Join-Path $stage "resources\runtime"
    New-Item -ItemType Directory -Force -Path (Split-Path $destRt) | Out-Null
    Copy-Item $runtime -Destination $destRt -Recurse
}

if (-not $SkipRuntime -and -not (Test-Path $stageRuntimePy) -and -not (Test-Path (Join-Path $stage "resources\runtime\python\python.exe"))) {
    throw "Staged zip is missing the offline Python runtime."
}

Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $stage -Recurse -Force
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 2)
Write-Host "Portable build: $zip ($mb MB)  (executable: MDFlux.exe)"
