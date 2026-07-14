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

## UI / design (non-negotiable)

**Target feel:** Claude-like warmth + shadcn-style controls (soft segs, quiet edges, terracotta accent).  
**Themes:** system / light / dark via `ThemeSwitch` + `theme.svelte.ts` (`html[data-theme]`). Default follows OS.  
Light = warm paper (`#FAF9F5` family); dark = warm charcoal — **not** cold zinc-blue SaaS, not pure `#000`.

| Rule | Do | Don't |
|---|---|---|
| Tokens | Palette / radius / spacing only in `tokens.css` | Scatter hex; invent a second theme store |
| Accent | Terracotta / clay **orange**; **`btn-primary` = `--accent`** | Black/white monochrome primary; blue brand |
| Chrome frames | Lists/setup cards: `.panel` / `.panel-inset` / `.hairline-*` | `border border-zinc-800 rounded-lg divide-y` stacks |
| **Result / Doc reading** | **Flat on canvas** (`result-shell` / `doc-shell`) — one surface, hairline chrome only | Nest a full-bleed `.panel` card around the reader (double-card, ugly) |
| **Reading column** | Wide: ~`72rem` (very wide ~`80rem`); use the monitor | Thin ~`40–44rem` strip with huge empty side margins |
| Markdown body | **Only** `preview.css` + class `.md-preview` | Duplicate preview CSS in ResultView/DocViewer |
| Tables in preview | Inline document: top/bottom hairlines, transparent bg | Full grid cages or floating “mini-card” table fills |
| Buttons / segs | Global `btn-*`, `seg` / `seg-btn` | Per-view button recipes; hard-coded blue focus rings |
| Utilities | Tailwind OK; `zinc-*` / `blue-*` are **remapped** to tokens | Treat `bg-zinc-950` as literal zinc |
| Layout (flex column) | `self-center` (+ max-width) for centered blocks | `mx-auto` alone when parent is flex column |
| i18n | `tr()` / `locale.svelte.ts` for user-visible strings | Hardcoded EN/ZH in one view only |

**Canonical files (copy these, don’t invent parallels):**

- Tokens + chrome primitives → `app/src/lib/tokens.css`
- Markdown preview → `app/src/lib/preview.css` (import in `+layout.svelte`)
- Theme → `theme.svelte.ts` + early paint in `app.html` + `ThemeSwitch.svelte`
- Locale → `locale.svelte.ts` (**must** stay `.svelte.ts`)
- Reader layout examples → `ResultView.svelte`, `DocViewer.svelte`
- Staging / batch chrome → `StagingView.svelte` (`panel-inset` lists)

**Gotchas (real failures):**

1. Svelte 5 runes only compile in `.svelte` / `.svelte.ts` — `$state` in plain `.ts` → blank screen.
2. Reader view ≠ elevated card: wrapping Result/Doc in `.panel` recreated the “card on paper” mismatch users rejected.
3. Prefer elevation / hairlines over ink boxes; when borders feel “stiff”, remove a layer, don’t only bump padding.

## Hard constraints

1. **Do not commit** `app/src-tauri/resources/runtime/python/` — build artefact. Only `runtime/README.md` is tracked. Build with `scripts/bundle-runtime.sh` (or `.ps1`).
2. **Offline ship path is intentional**: bundled runtime; `bootstrap.rs` skips first-launch download when present. Don’t remove without discussion.
3. **Basic offline build has no OCR/audio engines** (optional extras). Don’t assume RapidOCR / faster-whisper ship in the package.
4. **Windows is the shipping OS.** CI `portable.yml` → public Release tag **`offline-latest`** (NSIS + optional portable zip).

## Commands (prefer scoped)

```bash
cd app && npm ci && npm run check
cd app/src-tauri && cargo check --locked
bash scripts/bundle-runtime.sh
# Full installer: Windows only
pwsh -File scripts/make-installer.ps1 -AlsoPortable
```

Prefer CI for ship packages over local Windows unless debugging packaging.

## Start here (judgment, not a tree)

| When changing… | Read first |
|---|---|
| Look / theme / chrome | `tokens.css`, `theme.svelte.ts`, `ThemeSwitch.svelte` |
| Markdown preview / tables | `preview.css` (then ResultView / DocViewer shells only) |
| Reader layout / column width | `ResultView.svelte`, `DocViewer.svelte` |
| Copy / language | `locale.svelte.ts` |
| Conversion / formats | `resources/sidecar/main.py`, `worker.py`, `capabilities.py` |
| Offline Python / first-run | `src/bootstrap.rs` |
| Batch / IPC | `src/lib.rs`, `src/converter.rs` |
| Packaging / Release | `scripts/make-installer.ps1`, `.github/workflows/portable.yml` |

Structure: use `tree` / search — don’t paste directory trees here. Human docs: `CONTRIBUTING.md`, `README.md`.

## Permissions / ask first

| AI may do freely | Ask before |
|---|---|
| Edit app code, scripts, docs; `npm run check` / `cargo check` | `git push`, force-push, amend published history |
| Local `bundle-runtime` experiments | Push to **upstream** or open upstream PR |
| Token / layout tweaks that stay Claude-warm + flat reader + wide column | Overwrite Release tags (`offline-latest`, `v*`) outside normal CI |
| | Broad lockfile bumps without a reason |
| | New brand palette, or removing light/dark, or re-boxing the reader in `.panel` |

No secrets in this file. Runtime app data lives under the OS app-data dir, not the repo.
