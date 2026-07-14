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

**Target feel:** Claude-like warmth with **shadcn-style** controls — soft rounded segments, quiet borders, high readability.  
**Two themes** (user can switch **系統 / 淺色 / 深色**, default follows OS):

| Mode | Feel | Anchor colors (intent, not copy-paste source of truth) |
|---|---|---|
| Dark | Warm charcoal + terracotta | canvas ~`#1e1e1c`, accent ~`#cc7d5e` |
| Light | Claude paper + terracotta | canvas ~`#FAF9F5`, fg ~`#141413`, accent ~`#D97757` |

Not cold zinc-blue SaaS; not neon; not pure black `#000`; light mode is **warm paper**, not stark pure white UI chrome only.

| Rule | Do | Don't |
|---|---|---|
| Tokens | Palette / radius / spacing only in `app/src/lib/tokens.css` (`:root` shared + `[data-theme='light'|'dark']`) | Scatter hex colors or one-off radii in components |
| Markdown preview | Shared `app/src/lib/preview.css` (`.md-preview`) — soft tables (row dividers only), borderless `pre` | Duplicate `.preview` CSS in ResultView/DocViewer; full grid table cages |
| Frames | Prefer `.panel` / `.panel-inset` / `.hairline-*` over ink boxes | `border border-zinc-800 rounded-lg divide-y` stacks |
| Theme state | Preference + resolve via `app/src/lib/theme.svelte.ts`; paint with `document.documentElement.dataset.theme` | Invent a second theme store or hardcode dark-only backgrounds (`#09090b`, cold slate) |
| Theme UI | Use `ThemeSwitch.svelte` (system / light / dark) | Drop light mode or ship dark-only without discussion |
| Accent | Warm terracotta / clay **orange** in both themes; **primary buttons use `--accent`** (`btn-primary`) | Monochrome black primary; blue-500 / indigo brand |
| Surfaces | Token stack `--canvas` → `--surface-1/2/3` (values flip per theme) | Cold slate-only or pure-black panels |
| Buttons / segs | Global classes: `btn-primary`, `btn-secondary`, `btn-tertiary`, `btn-danger`, `btn-accent-soft`, `btn-sm`, `seg` / `seg-btn`; seg track via `--seg-track` | Redefine the same button recipe per view |
| Utilities | Tailwind v4 OK; `zinc-*` / `blue-*` are **semantically remapped** to tokens in `@theme` | Assume `bg-zinc-950` is literal Tailwind zinc; hardcode theme-specific grays |
| Layout | In flex-column parents, center with `self-center` (+ max-width) | Rely on `mx-auto` alone for horizontal centering |
| Radius | Soft premium scale already in tokens | Flatten to 4–6px “sharp SaaS” without discussion |
| i18n | User-visible strings via `tr()` / `locale` in `locale.svelte.ts` | Hardcode EN/ZH in one view; second i18n store |

**Canonical pattern files (copy from these, don’t invent parallel systems):**

- Design system + light/dark palettes → `app/src/lib/tokens.css` (from `+layout.svelte`)
- Theme preference (system/light/dark) → `app/src/lib/theme.svelte.ts` + early paint in `app.html`
- Theme control UI → `app/src/lib/ThemeSwitch.svelte`
- Locale runes store → `app/src/lib/locale.svelte.ts` (must stay **`.svelte.ts`**)
- Composition examples → `StagingView.svelte`, `ResultView.svelte`, `+page.svelte`

**Gotcha:** Svelte 5 runes (`$state`, `$derived`, …) only compile in `.svelte` / `.svelte.ts`. Putting `$state` in a normal `.ts` module caused a blank startup screen (`ReferenceError`). Keep locale **and theme** stores as `*.svelte.ts`.

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
| Look / theme / controls | `app/src/lib/tokens.css` + `theme.svelte.ts` / `ThemeSwitch.svelte`; match `btn-*` / `seg` |
| Copy / language switch | `app/src/lib/locale.svelte.ts` + views already calling `tr()` |
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
| Token / theme tweaks in `tokens.css` that stay Claude-warm (light **and** dark) + shadcn-pattern | Delete/overwrite GitHub Release tags (`offline-latest`, `v*`) outside normal CI |
| | Broad dependency bumps that change lock hashes without a reason |
| | Replacing the brand palette / removing light or dark mode without discussion |

No secrets belong in this file. App data / provision state lives under the OS app-data dir at runtime, not in the repo.
