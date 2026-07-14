# Build MDFlux as a Windows NSIS installer (Setup.exe).
# Bundles the offline Python runtime so install → run needs no first-launch download.
#
# Output: dist/MDFlux_<version>_x64-setup.exe
#
# Usage:  pwsh -File scripts\make-installer.ps1
#         pwsh -File scripts\make-installer.ps1 -ForceRuntime
#         pwsh -File scripts\make-installer.ps1 -SkipRuntime   # online provision model
#         pwsh -File scripts\make-installer.ps1 -AlsoPortable  # also zip portable build

param(
    [switch]$ForceRuntime,
    [switch]$SkipRuntime,
    [switch]$AlsoPortable
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
$runtime = Join-Path $root "app\src-tauri\resources\runtime"
$bundleNsis = Join-Path $root "app\src-tauri\target\release\bundle\nsis"

if (-not $SkipRuntime) {
    $bundlePs1 = Join-Path $PSScriptRoot "bundle-runtime.ps1"
    $bundleSh  = Join-Path $PSScriptRoot "bundle-runtime.sh"
    $rtArgs = @()
    if ($ForceRuntime) { $rtArgs += "-Force" }
    if (Test-Path $bundlePs1) {
        & $bundlePs1 @rtArgs
    } elseif (Get-Command bash -ErrorAction SilentlyContinue) {
        $shArgs = @()
        if ($ForceRuntime) { $shArgs += "--force" }
        & bash $bundleSh @shArgs
        if ($LASTEXITCODE -ne 0) { throw "bundle-runtime.sh failed" }
    } else {
        throw "Need scripts/bundle-runtime.ps1 or bash + bundle-runtime.sh"
    }
    if (-not (Test-Path (Join-Path $runtime "python\python.exe"))) {
        throw "Offline runtime missing at $runtime"
    }
} else {
    Write-Host "SkipRuntime: installer will rely on first-launch online provision."
}

# Full Tauri build — NSIS only (config also lists dmg for macOS CI).
Push-Location (Join-Path $root "app")
try {
    npx tauri build --bundles nsis
    if ($LASTEXITCODE -ne 0) { throw "tauri build failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

$setup = Get-ChildItem -Path $bundleNsis -Filter "*-setup.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $setup) {
    throw "NSIS setup.exe not found under $bundleNsis. Is bundle.active true and targets includes nsis?"
}

# Verify offline runtime was packaged into the app resources used by the installer.
$relResRuntime = Join-Path $root "app\src-tauri\target\release\resources\resources\runtime\python\python.exe"
$relResRuntime2 = Join-Path $root "app\src-tauri\target\release\resources\runtime\python\python.exe"
if (-not $SkipRuntime) {
    if (-not (Test-Path $relResRuntime) -and -not (Test-Path $relResRuntime2)) {
        Write-Warning "Could not find staged python.exe under target/release/resources — installer may still embed resources; verify after install."
    }
}

$conf = Get-Content (Join-Path $root "app\src-tauri\tauri.conf.json") -Raw | ConvertFrom-Json
$version = $conf.version

New-Item -ItemType Directory -Force -Path $dist | Out-Null
$outName = "MDFlux_${version}_x64-setup.exe"
$outPath = Join-Path $dist $outName
Copy-Item $setup.FullName $outPath -Force
$mb = [math]::Round((Get-Item $outPath).Length / 1MB, 2)
Write-Host "Installer: $outPath ($mb MB)"

if ($AlsoPortable) {
    # Reuse the just-built binary + resources for a portable zip (no second compile).
    & (Join-Path $PSScriptRoot "make-portable.ps1") -NoBuild
}
