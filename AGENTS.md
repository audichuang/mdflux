# MDFlux — agent context

Local-first desktop app: documents → clean Markdown.  
**This clone is the `audichuang` fork** (offline packages + macOS arm64 + Homebrew). Upstream: `ibrahimqureshae/mdflux` (`upstream` remote).

## Architecture (non-negotiable)

| Layer | Role |
|---|---|
| Svelte (`app/src`) | UI only |
| Rust/Tauri (`app/src-tauri/src`) | Window, dialogs, sidecar, provision / bundled runtime |
| Python sidecar (`resources/sidecar`) | **All** conversion (MarkItDown), cleanup, OCR/audio workers |

Shell **never** converts; sidecar **never** owns UI. Coupling = NDJSON IPC only (`main.py` ↔ `converter.rs` / `lib.rs`).

## UI / design (non-negotiable)

**Feel:** Claude-warm charcoal/paper + terracotta accent + shadcn-style segs. Themes: system / light / dark (`theme.svelte.ts`, `ThemeSwitch`). Not cold zinc-blue SaaS.

| Do | Don't |
|---|---|
| Tokens only in `tokens.css`; `btn-primary` = `--accent` (orange) | Scatter hex; black monochrome primary |
| Lists/setup: `.panel` / `.panel-inset` / `.hairline-*` | `border-zinc-800 rounded-lg divide-y` stacks |
| **Reader** (`ResultView` / `DocViewer`): **flat on canvas**, wide column (~72–80rem) | Full-bleed `.panel` around reader; thin ~44rem center strip |
| Markdown: **only** `preview.css` + `.md-preview`; tables = hairline rows | Duplicate preview CSS; grid cages / mini-card tables |
| `tr()` / `locale.svelte.ts`; runes only in `*.svelte` / `*.svelte.ts` | Plain `.ts` `$state` (blank screen); second i18n store |

Canonical: `tokens.css`, `preview.css`, `theme.svelte.ts`, `locale.svelte.ts`, `ResultView.svelte`, `StagingView.svelte`.

## Shipping / packaging (non-negotiable)

| Platform | Artefacts | How users get it |
|---|---|---|
| Windows x64 | `MDFlux_<ver>_x64-setup.exe` + `_portable_offline.zip` | GitHub Release |
| macOS arm64 | `MDFlux_<ver>_aarch64.dmg` | Release **or** `brew install --cask audichuang/tap/mdflux` |

1. **Do not commit** `resources/runtime/python/` — only `runtime/README.md`. Build with `bundle-runtime.sh --platform windows-x64|macos-arm64` (never mix platforms in one tree).
2. **Offline runtime is intentional** (`bootstrap.rs` prefers bundled Python). Basic package has **no** OCR/audio engines.
3. **CI** (`.github/workflows/portable.yml`): Windows + mac jobs → one `publish-release` with **all three** assets. `main` → tag **`offline-latest`**; `vX.Y.Z` → version tag. Prefer CI over local packaging.
4. **Homebrew is macOS cask only** (not Formula, not Windows). Live file: **`audichuang/homebrew-tap` `Casks/mdflux.rb`**. Repo `packaging/homebrew/` is a **draft** — CI `publish-homebrew` rewrites the tap on **stable `v*` tags only** (not `offline-latest`, not `v*-rc`).
5. **Secret:** `HOMEBREW_TAP_TOKEN` (PAT → write `homebrew-tap`). No tokens in this file. Without it, packages still publish; tap job fails on tags.
6. **Release hygiene:** `softprops` **merges** assets onto an existing tag — old filenames can linger; delete stale assets when version bumps.
7. **Version bump** (together): `app/package.json`, `tauri.conf.json`, `Cargo.toml` (+ lock package `app`).

Human detail: `packaging/homebrew/README.md`, `README.md` install section.

## Commands (prefer scoped)

```bash
cd app && npm ci && npm run check
cd app/src-tauri && cargo check --locked
bash scripts/bundle-runtime.sh --platform windows-x64   # or macos-arm64 --force
# Prefer CI "Portable build". Local:
pwsh -File scripts/make-installer.ps1 -AlsoPortable   # Windows
bash scripts/make-macos-dmg.sh                        # macOS arm64
```

## Start here (judgment, not a tree)

| When changing… | Read first |
|---|---|
| UI / theme / reader | `tokens.css`, `preview.css`, `theme.svelte.ts`, `ResultView.svelte` |
| Conversion | `resources/sidecar/main.py`, `worker.py`, `capabilities.py` |
| Provision / runtime path | `src/bootstrap.rs` |
| Batch / IPC | `src/lib.rs`, `src/converter.rs` |
| Release / brew | `portable.yml`, `bundle-runtime.sh`, `make-installer.ps1`, `make-macos-dmg.sh` |

Structure: `tree` / search. Docs: `README.md`, `CONTRIBUTING.md`, `packaging/homebrew/README.md`.

## Permissions / ask first

| AI may do freely | Ask before |
|---|---|
| Edit app code, scripts, docs; `npm run check` / `cargo check` | `git push`, force-push, amend published history |
| Local runtime / packaging experiments | Push to **upstream** `ibrahimqureshae/mdflux` |
| Token/layout tweaks staying Claude-warm + flat reader | Manual push to **homebrew-tap** (use CI `publish-homebrew`) |
| | Overwrite Release tags outside normal CI; broad lock bumps; new brand palette / drop light-dark / re-box reader |

No secrets/PII here. App data lives under OS app-data dir at runtime, not the repo.
