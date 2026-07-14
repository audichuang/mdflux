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
builds the offline Windows zip on `windows-latest` and **publishes a public GitHub Release**
(downloadable without logging in):

- **Push to `main`** or **manual “Run workflow”** → updates release tag **`offline-latest`**
  (stable URL under Releases)
- **Push a tag `v*`** → versioned release under that tag

Also uploads an Actions Artifact (login required; secondary). Prefer the Release asset.

### Local (optional)

```bash
# 1) Offline Python + markitdown stack (~300 MB on disk; any OS with curl + uv)
bash scripts/bundle-runtime.sh

# 2) On Windows: compile Tauri + package zip
pwsh -File scripts/make-portable.ps1
# -> dist/MDFlux_<version>_portable_offline.zip
```

| Flag | Effect |
|---|---|
| (default) | Bundle offline runtime + build + zip |
| `-ForceRuntime` | Rebuild the offline runtime even if present |
| `-SkipRuntime` | Classic small zip (first launch downloads Python) |
| `-NoBuild` | Only re-zip an existing `target/release` build |

MDFlux ships as a portable zip, not an installer (`bundle.active: false` in `tauri.conf.json`).

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
