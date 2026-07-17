# Releasing MDFlux (audichuang fork)

Canonical release runbook. The model, invariants, and troubleshooting for cutting
a public MDFlux desktop release.

## TL;DR — one command, then watch it in the background

```bash
bash scripts/release.sh 0.2.0            # add --yes to skip the confirm
```

`release.sh` does the whole mechanical flow so it can't be fumbled: validates the
version, **bumps all four manifests together**, commits `chore: 升版 X.Y.Z`,
pushes `main`, waits for that build **green** (auto-reruns failed jobs **once** on
the transient macOS `setup-uv` flake), tags `vX.Y.Z`, watches the release build
(same auto-rerun), then verifies the Release assets and the Homebrew cask. You
still pick the version and confirm go/no-go — **a tag cuts a real public release.**

Run it in the background and let the notification tell you when it lands. The rest
of this file is the reference behind the script.

## The model (tag-driven, but manifest-driven filenames)

Pushing to `.github/workflows/portable.yml`:

| Trigger | Result |
|---|---|
| push to `main` | build both platforms to **validate** — publishes nothing (no floating release) |
| push `vX.Y.Z` tag | build → **one clean per-version** GitHub Release, then `publish-homebrew` |
| `vX.Y.Z-rc` / `-offline` (any `-`) | Release publishes; **Homebrew cask is skipped** |

Jobs: `windows-offline` (setup.exe + `_portable_offline.zip`) and
`macos-arm64-offline` (`_aarch64.dmg`) run in parallel → `publish-release` (needs
both) → `publish-homebrew` (needs publish-release, **stable `v*` only**).

**The one gotcha that breaks releases** — unlike some pipelines, mdflux CI does
**NOT** sed the tag into the manifests. Artifact filenames come from
`tauri.conf.json`'s `version`; the cask download URL is built from the **tag**.
So if the manifest version ≠ the tag, the DMG is named `MDFlux_<old>_…` while the
cask points at `…/download/v<tag>/MDFlux_<tag>_aarch64.dmg` → **404, broken cask.**
The manifest version and the tag must match. `release.sh` guarantees this; a manual
release must bump first.

## Versioning — four manifests, one version

Bump **together**, always equal to the tag (minus `v`):

- `app/package.json`
- `app/src-tauri/tauri.conf.json`  ← drives the artifact filenames
- `app/src-tauri/Cargo.toml`
- `app/src-tauri/Cargo.lock`  ← the `name = "app"` package block only

This fork ships its own independent version line — start ≥ the highest existing
`v*` tag (`git tag --sort=-v:refname | head`).

## Cut a release manually (if not using the script)

```bash
# 0. tree clean, on main, tag not taken
git tag --sort=-v:refname | head          # pick next version ≥ highest
# 1. bump the FOUR manifests to X.Y.Z (see list above) — must match the tag
# 2. commit + push main, let the main build go green
git add app/package.json app/src-tauri/{tauri.conf.json,Cargo.toml,Cargo.lock}
git commit -m "chore: 升版 X.Y.Z" && git push origin main
gh run watch <main-run-id> --repo audichuang/mdflux --exit-status
# 3. tag + push → versioned Release + Homebrew cask
git tag vX.Y.Z && git push origin vX.Y.Z
gh run watch <tag-run-id> --repo audichuang/mdflux --exit-status
```

Pushing `main` first is not required by CI (the tag build is independent) but
catches a red build before you tag.

## Verify after green

```bash
gh release view vX.Y.Z --repo audichuang/mdflux --json assets --jq '.assets[].name'
gh api repos/audichuang/homebrew-tap/contents/Casks/mdflux.rb --jq .content | base64 -d | grep -E 'version|sha256'
```

- Expect exactly three assets: `MDFlux_<v>_x64-setup.exe`, `MDFlux_<v>_portable_offline.zip`, `MDFlux_<v>_aarch64.dmg`.
- Cask `version` = the tag, `sha256` non-empty.
- Users install via `brew install --cask audichuang/tap/mdflux`, or download the Release assets.

## Invariants (don't break these)

- **App version = tag = cask version.** All artifact filenames and the cask URL
  are keyed on it; a mismatch 404s the cask.
- **`HOMEBREW_TAP_TOKEN`** (PAT with Contents:write on `audichuang/homebrew-tap`)
  gates `publish-homebrew`. Without it the tap job fails on a tag — **but the
  GitHub Release still publishes**; only the brew update is missed.
- **Bundle id `com.projektvisyo.mdflux`** is baked into the cask `zap` paths —
  changing it orphans users' app-data cleanup.
- **Never commit `app/src-tauri/resources/runtime/python/`** (offline runtime is
  built in CI, not tracked). Only `runtime/README.md`.
- **`softprops` merges assets onto an existing tag** — old-version filenames can
  linger. Delete stale assets when a run leaves them behind.
- macOS/Windows builds are **unsigned** (SmartScreen / Gatekeeper may warn); this
  is expected until Apple/codesign secrets exist.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `macos-arm64-offline` fails fast (~30s) at **Install uv**; annotation "API rate limit exceeded for <runner-ip>" | `astral-sh/setup-uv` hit GitHub's **anonymous** API rate limit fetching uv — transient infra, **not code** (the Windows job proves the frontend builds) | Re-run failed jobs: `gh run rerun --failed <run-id> --repo audichuang/mdflux`. `release.sh` does this automatically once. |
| `Cargo Fetch` / sccache DNS error | Transient GitHub cache/DNS flake | Same — re-run the failed job. |
| `publish-homebrew` fails: token empty | Missing/expired `HOMEBREW_TAP_TOKEN` | Reset the PAT secret and re-run just that job; the Release is already published. |
| Cask points at a DMG that 404s | Manifest version ≠ tag (see gotcha above) | Re-release the tag with matching manifests (below). |
| `brew` won't upgrade to the new version | Stale local tap | `brew update` or re-tap `audichuang/tap`; the remote cask is fine (see AGENTS.md ops note). |

## Re-release a botched tag

Safe only while no users have pulled the build; for an already-public version, ship
a new patch instead.

```bash
gh run cancel <run-id> --repo audichuang/mdflux
gh release delete vX.Y.Z --repo audichuang/mdflux --yes --cleanup-tag   # Release + remote tag
git tag -d vX.Y.Z
# fix the manifests/code, then re-run:
bash scripts/release.sh X.Y.Z
```

Detail: `.github/workflows/portable.yml`, AGENTS.md "Shipping / packaging".
