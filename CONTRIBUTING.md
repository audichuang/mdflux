# Contributing to MDFlux

Thanks for your interest — contributions are very welcome.

## Project layout

- `app/` — the Tauri 2 desktop app: a Svelte 5 (SvelteKit) front end (`app/src`) and a Rust
  shell (`app/src-tauri/src`).
- `app/src-tauri/resources/sidecar/` — the Python conversion sidecar (wraps Microsoft's
  MarkItDown, plus cleanup / OCR / audio). Dependencies are hash-pinned in `requirements*.lock`.
- `scripts/make-portable.ps1` — builds the portable, extract-and-run distributable.
- `scripts/bundle-runtime.sh` / `bundle-runtime.ps1` — downloads Windows CPython + core
  packages into `app/src-tauri/resources/runtime/` for offline portable builds.

The shell never contains conversion logic; the sidecar never contains UI. The IPC contract is the
only coupling.

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Rust](https://www.rust-lang.org/tools/install) (stable) + the Tauri prerequisites for your OS
- Windows + WebView2 runtime (present on current Windows 10/11)
- [uv](https://docs.astral.sh/uv/) (only needed when building the offline runtime)

**Dev / classic portable:** the app can still download its own Python 3.12 environment on first
launch (online provision).

**Offline portable (default packaging):** Python + core conversion packages are pre-bundled into
the zip, so first launch needs no internet.

## Run it locally

```bash
cd app
npm install
npm run tauri dev
```

## Build the distributable

### CI (recommended)

GitHub Actions workflow [`.github/workflows/portable.yml`](../.github/workflows/portable.yml)
builds offline Windows packages on `windows-latest` and **publishes a public GitHub Release**:

- **Primary:** NSIS **`MDFlux_<ver>_x64-setup.exe`** (real installer, Start Menu, current-user)
- **Also:** portable zip (optional unzip-and-run)
- **Push to `main`** / **Run workflow** → updates tag **`offline-latest`**
- **Tag `v*`** → versioned release

Prefer the Release **setup.exe** (no login needed to download).

### Local (optional, Windows)

```bash
# Offline Python runtime (any OS with curl + uv)
bash scripts/bundle-runtime.sh

# On Windows: NSIS installer (+ optional portable zip)
pwsh -File scripts/make-installer.ps1 -AlsoPortable
# -> dist/MDFlux_<version>_x64-setup.exe
# -> dist/MDFlux_<version>_portable_offline.zip
```

`bundle.active` is **true** in `tauri.conf.json` (NSIS target).

## Checks before a PR

```bash
cd app && npm run check          # svelte-check (0 errors expected)
cd app/src-tauri && cargo check  # Rust
```

## Pull requests

- Branch from `main`, keep PRs focused, and describe what changed and why.
- Match the surrounding code's style.
- By submitting a PR you certify you wrote the change (or have the right to contribute it) under
  the project's **MIT** license. No CLA — a [DCO](https://developercertificate.org/) sign-off
  (`git commit -s`) is appreciated for provenance.

## Reporting issues

Use the issue templates. For security issues, **do not** open a public issue — see
[`SECURITY.md`](SECURITY.md).
