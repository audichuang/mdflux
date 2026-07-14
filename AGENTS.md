# MDFlux — agent context

Local-first desktop app: documents → clean Markdown.  
**This clone is the `audichuang` fork** with offline packaging (bundled Python). Upstream: `ibrahimqureshae/mdflux` (`upstream` remote).

## Architecture (non-negotiable)

| Layer | Role |
|---|---|
| Svelte (`app/src`) | UI only |
| Rust/Tauri (`app/src-tauri/src`) | Window, dialogs, sidecar process, provision / bundled runtime |
| Python sidecar (`app/src-tauri/resources/sidecar`) | **All** conversion (MarkItDown), cleanup, OCR/audio workers |

Shell **never** converts; sidecar **never** owns UI. The only coupling is the NDJSON IPC (`main.py` ↔ `converter.rs` / `lib.rs`).

## Hard constraints

1. **Do not commit** `app/src-tauri/resources/runtime/python/` — build artefact (~300MB). Only `runtime/README.md` is tracked. Produce runtime with `scripts/bundle-runtime.sh` (or `.ps1`).
2. **Offline ship path is intentional on this fork**: installer/portable embed that runtime. `bootstrap.rs` prefers `resources/runtime/python/python.exe` and skips first-launch download when present. Do not “simplify” by removing the bundled path without discussion.
3. **Basic offline build does not include OCR/audio engines** (optional extras via separate locks). Don’t assume RapidOCR / faster-whisper are in the package.
4. **Windows is the shipping OS.** NSIS setup + portable zip are produced by CI on `windows-latest` (`.github/workflows/portable.yml`) and published to public Release tag **`offline-latest`**.

## Commands (prefer scoped)

```bash
# Frontend typecheck
cd app && npm ci && npm run check

# Rust compile check (Linux may need the platform stub in bootstrap.rs)
cd app/src-tauri && cargo check --locked

# Offline Windows Python tree (any OS with curl + uv)
bash scripts/bundle-runtime.sh

# Full installer + portable (must run on Windows)
pwsh -File scripts/make-installer.ps1 -AlsoPortable
```

Ship packages via CI (`Portable build` workflow) rather than local Windows unless debugging packaging.

## Start here (judgment, not a tree)

| When changing… | Read first |
|---|---|
| Conversion / formats / cleanup | `resources/sidecar/main.py`, `worker.py`, `capabilities.py` |
| First-run / offline Python path | `src/bootstrap.rs` |
| Batch / IPC surface | `src/lib.rs`, `src/converter.rs` |
| Packaging / Release | `scripts/make-installer.ps1`, `.github/workflows/portable.yml` |

Structure details: use `tree` / search — don’t duplicate directory trees in this file. Human docs: `CONTRIBUTING.md`, `README.md`.

## Permissions / ask first

| AI may do freely | Ask before |
|---|---|
| Edit app code, scripts, docs; run `npm run check` / `cargo check` | `git push`, force-push, amend published history |
| Local `bundle-runtime` experiments | Push to **upstream** `ibrahimqureshae/mdflux` or open upstream PR |
| | Delete/overwrite GitHub Release tags (`offline-latest`, `v*`) outside normal CI |
| | Broad dependency bumps that change lock hashes without a reason |

No secrets belong in this file. App data / provision state lives under the OS app-data dir at runtime, not in the repo.
