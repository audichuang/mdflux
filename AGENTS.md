# MDFlux — agent context

Local-first desktop app: documents → clean Markdown.  
**This clone is the `audichuang` fork** (offline packages + macOS arm64 + Homebrew). Upstream: `ibrahimqureshae/mdflux` (`upstream` remote).

## Architecture (non-negotiable)

| Layer | Role |
|---|---|
| Svelte (`app/src`) | UI only |
| Rust/Tauri (`app/src-tauri/src`) | Window, dialogs, sidecar, provision / bundled runtime |
| Python sidecar (`app/src-tauri/resources/sidecar`) | **All** conversion (MarkItDown), cleanup, optional LLM cleanup pass, OCR/audio workers |

Shell **never** converts; sidecar **never** owns UI. Coupling = NDJSON IPC only (`main.py` ↔ `converter.rs` / `lib.rs`).

## UI / design (non-negotiable)

**Feel:** Claude-warm charcoal/paper + terracotta accent + shadcn-*style* segs (aesthetic only — **never add `shadcn-svelte`/`bits-ui`**; native components + tokens). Reach for the native equivalent instead: tooltip = `title=""`, overlay = the `popover` attribute, segmented control = the existing `.seg` pattern. Themes: system / light / dark (`theme.svelte.ts`, `ThemeSwitch`). Not cold zinc-blue SaaS.

| Do | Don't |
|---|---|
| Tokens only in `tokens.css`; `btn-primary` = `--accent` (orange) | Scatter hex; black monochrome primary |
| Lists/setup: `.panel` / `.panel-inset` / `.hairline-*` | `border-zinc-800 rounded-lg divide-y` stacks |
| **Reader** (`ResultView` / `DocViewer`): **flat on canvas**, wide column (~72–80rem) | Full-bleed `.panel` around reader; thin ~44rem center strip |
| Markdown: **only** `preview.css` + `.md-preview`; tables = hairline rows | Duplicate preview CSS; grid cages / mini-card tables |
| `tr()` / `locale.svelte.ts`; runes only in `*.svelte` / `*.svelte.ts` | Plain `.ts` `$state` (blank screen); second i18n store |
| Override a `.btn-*` / `.hairline-*` via `.btn-icon` or scoped `<style>` (both unlayered) | Tailwind utilities (`p-0`, `rounded-full`, `hover:*`, `last:border-b-0`) on them — `.btn-*` are unlayered, so `@layer utilities` **silently loses** |
| `tokens.css` is **entirely unlayered** — keep every selector class-scoped | A `*` or bare-element reset in it. Tailwind preflight already resets margin/padding/box-sizing in `@layer base`; an unlayered copy **silently kills every `p-*` / `m-*` in the app** (bit us in 0.2.3 — modal text clipped by its own border-radius) |

Canonical: `tokens.css`, `preview.css`, `theme.svelte.ts`, `locale.svelte.ts`, `ResultView.svelte`, `StagingView.svelte`.

## Shipping / packaging (non-negotiable)

**Scope:** Windows x64 (GitHub Release only — **never** via brew) + macOS **arm64 only**, delivered by Homebrew **cask** (never a Formula). Prefer CI packaging over local.

**Offline runtime intentional** (`bootstrap.rs` prefers bundled Python); the basic package has **no** OCR/audio engines. **Never mix platforms** in one runtime tree.

Release model, artefact names, CI gates, four-manifest versioning, brew/tap troubleshooting → **`docs/RELEASING.md`** (canonical runbook; `packaging/homebrew/` is a draft only). Cutting one is `scripts/release.sh` — a `v*` tag is public, see Permissions below.

## Commands (prefer scoped)

```bash
cd app && npm ci && npm run test && npm run check
cd app/src-tauri && cargo check --locked
bash scripts/bundle-runtime.sh --platform windows-x64   # or macos-arm64 --force
# Prefer CI "Portable build". Local:
pwsh -File scripts/make-installer.ps1 -AlsoPortable   # Windows host
bash scripts/make-macos-dmg.sh                        # macOS arm64 host
bash scripts/release.sh X.Y.Z          # public Release + brew — ask first (--yes skips confirm)
```

**Tests:** `npm run test` = Vitest (`src/lib/*.test.ts`) + Python `unittest` (sidecar `test_*.py`). CI (`ci.yml`) runs **only** `npm run check` + `cargo check` — **a green CI does not mean tests passed**; run them locally.

## Start here (judgment, not a tree)

| When changing… | Read first |
|---|---|
| UI / theme / reader | `tokens.css`, `preview.css`, `theme.svelte.ts`, `ResultView.svelte` |
| Conversion | `app/src-tauri/resources/sidecar/main.py`, `worker.py`, `capabilities.py` |
| LLM cleanup / diagnostics | `sidecar/cleanup.py`, `provider.py`, `DiagLlm.svelte` |
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
| | Cut a release (`scripts/release.sh` / push `v*` tag → public Release + Homebrew); overwrite Release tags outside normal CI; **any new npm/cargo dependency**; broad lock bumps; new brand palette / drop light-dark / re-box reader |

No secrets/PII here. App data — including the optional LLM API key — lives under the OS app-data dir at runtime, not the repo. **Never log or return that key** (`provider.py`).
