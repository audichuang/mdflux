# MDFlux — agent context

Local-first desktop app: documents → clean Markdown.  
**This clone is the `audichuang` fork** (offline packages + macOS arm64 + Homebrew). Upstream: `ibrahimqureshae/mdflux` (`upstream` remote).

## Architecture (non-negotiable)

| Layer | Role |
|---|---|
| Svelte (`app/src`) | UI only |
| Rust/Tauri (`app/src-tauri/src`) | Window, dialogs, sidecar, provision / bundled runtime |
| Python sidecar (`app/src-tauri/resources/sidecar`) | **All** conversion (MarkItDown), cleanup, OCR/audio workers |

Shell **never** converts; sidecar **never** owns UI. Coupling = NDJSON IPC only (`main.py` ↔ `converter.rs` / `lib.rs`).

## UI / design (non-negotiable)

**Feel:** Claude-warm charcoal/paper + terracotta accent + shadcn-*style* segs (aesthetic only — **never add `shadcn-svelte`/`bits-ui`**; native components + tokens). Themes: system / light / dark (`theme.svelte.ts`, `ThemeSwitch`). Not cold zinc-blue SaaS.

| Do | Don't |
|---|---|
| Tokens only in `tokens.css`; `btn-primary` = `--accent` (orange) | Scatter hex; black monochrome primary |
| Lists/setup: `.panel` / `.panel-inset` / `.hairline-*` | `border-zinc-800 rounded-lg divide-y` stacks |
| **Reader** (`ResultView` / `DocViewer`): **flat on canvas**, wide column (~72–80rem) | Full-bleed `.panel` around reader; thin ~44rem center strip |
| Markdown: **only** `preview.css` + `.md-preview`; tables = hairline rows | Duplicate preview CSS; grid cages / mini-card tables |
| `tr()` / `locale.svelte.ts`; runes only in `*.svelte` / `*.svelte.ts` | Plain `.ts` `$state` (blank screen); second i18n store |
| Override a `.btn-*` / `.hairline-*` via `.btn-icon` or scoped `<style>` (both unlayered) | Tailwind utilities (`p-0`, `rounded-full`, `hover:*`, `last:border-b-0`) on them — `.btn-*` are unlayered, so `@layer utilities` **silently loses** |

Canonical: `tokens.css`, `preview.css`, `theme.svelte.ts`, `locale.svelte.ts`, `ResultView.svelte`, `StagingView.svelte`.

## Shipping / packaging (non-negotiable)

| Platform | Artefacts | How users get it |
|---|---|---|
| Windows x64 | `MDFlux_<ver>_x64-setup.exe` + `_portable_offline.zip` | GitHub Release |
| macOS arm64 only | `MDFlux_<ver>_aarch64.dmg` | Release **or** Homebrew **cask** (not Formula) |

1. **Do not commit** `app/src-tauri/resources/runtime/python/` — only `runtime/README.md`. Build: `bundle-runtime.sh --platform windows-x64|macos-arm64` (**never mix** platforms in one tree).
2. **Offline runtime intentional** (`bootstrap.rs` prefers bundled Python). Basic package has **no** OCR/audio engines.
3. **CI** `portable.yml`: Windows + mac build both platforms. `publish-release` (needs **all three** files) runs on **`v*` tags only** → one clean per-version release; **`main` pushes build to validate but publish nothing** (no floating `offline-latest`). Prefer CI over local packaging. Local: `make-installer.ps1` uses `--bundles nsis`; `make-macos-dmg.sh` uses `--bundles dmg`.
4. **Homebrew:** live cask is **`audichuang/homebrew-tap` `Casks/mdflux.rb`**. Repo `packaging/homebrew/` is a **draft only**. CI `publish-homebrew` runs on **stable `v*` tags only** (not `v*-rc` / `-offline`). Windows is never via brew.
5. **Secret name only:** `HOMEBREW_TAP_TOKEN` (write access to `homebrew-tap`). No token values in git. Without it, packages still publish; tap job fails on tags.
6. **Release hygiene:** each `v*` tag = its own fresh release, so assets don't accumulate. (`softprops` **merges** onto an existing tag, so if you ever re-release the same tag, delete stale assets first.)
7. **Version bump together:** `app/package.json`, `tauri.conf.json`, `Cargo.toml` (+ `Cargo.lock` package name `app`).

**Ops gotcha:** After a new cask lands on the remote tap, local Homebrew may still miss it until `brew update` (or re-tap). “Cask unavailable / path does not exist” is usually a **stale local tap**, not a missing remote file.

Detail: `docs/RELEASING.md` (full release runbook), `packaging/homebrew/README.md`, `README.md` install section.

## Commands (prefer scoped)

```bash
cd app && npm ci && npm run test && npm run check
cd app/src-tauri && cargo check --locked
bash scripts/bundle-runtime.sh --platform windows-x64   # or macos-arm64 --force
# Prefer CI "Portable build". Local:
pwsh -File scripts/make-installer.ps1 -AlsoPortable   # Windows host
bash scripts/make-macos-dmg.sh                        # macOS arm64 host
# Cut a release: bump 4 manifests → tag → watch CI → verify. v* tag = public Release + brew — ask first.
bash scripts/release.sh X.Y.Z          # e.g. 0.2.0 (--yes skips confirm)
```

**Tests:** `npm run test` = Vitest (`src/lib/*.test.ts`) + Python `unittest` for sidecar `cleanup.py`.

## Start here (judgment, not a tree)

| When changing… | Read first |
|---|---|
| UI / theme / reader | `tokens.css`, `preview.css`, `theme.svelte.ts`, `ResultView.svelte` |
| Conversion | `app/src-tauri/resources/sidecar/main.py`, `worker.py`, `capabilities.py` |
| Provision / runtime path | `app/src-tauri/src/bootstrap.rs` |
| Batch / IPC | `app/src-tauri/src/lib.rs`, `converter.rs` |
| Release / brew | `scripts/release.sh` (one-command cut), `.github/workflows/portable.yml`, `bundle-runtime.sh`, `make-installer.ps1`, `make-macos-dmg.sh` |

Structure: `tree` / search — no directory trees here. Docs: `README.md`, `CONTRIBUTING.md`, `packaging/homebrew/README.md`.

## Permissions / ask first

| AI may do freely | Ask before |
|---|---|
| Edit app code, scripts, docs; `npm run check` / `cargo check` | `git push`, force-push, amend published history |
| Local runtime / packaging experiments | Push to **upstream** `ibrahimqureshae/mdflux` |
| Token/layout tweaks staying Claude-warm + flat reader | Manual push to **homebrew-tap** (use CI `publish-homebrew`) |
| | Cut a release (`scripts/release.sh` / push `v*` tag → public Release + Homebrew); overwrite Release tags outside normal CI; broad lock bumps; new brand palette / drop light-dark / re-box reader |

No secrets/PII here. App data lives under the OS app-data dir at runtime, not the repo.
