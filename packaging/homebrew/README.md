# Homebrew cask — MDFlux

## User install (after a `v*` release updates the tap)

```bash
brew tap audichuang/tap
brew install --cask audichuang/tap/mdflux
```

- **Apple Silicon only** (`arm64`) for the first ship
- Artifact: `MDFlux_<version>_aarch64.dmg` from GitHub Releases
- Windows stays on **setup.exe / portable zip** (not Homebrew)

## Maintainer flow (mirrors aghub)

1. Bump version in `app/package.json`, `app/src-tauri/tauri.conf.json`, `Cargo.toml`
2. Tag `vX.Y.Z` and push
3. CI `Portable build`:
   - Windows → setup.exe + zip
   - macOS → aarch64 dmg
   - Publish release assets
   - `publish-homebrew` rewrites `audichuang/homebrew-tap` `Casks/mdflux.rb` (sha256 + version)

## Repo secret required

| Secret | Purpose |
|--------|---------|
| `HOMEBREW_TAP_TOKEN` | PAT with write access to `audichuang/homebrew-tap` |

Without it, Windows+mac packages still publish; only the tap update job fails on tags.

## Draft cask

`Casks/mdflux.rb` in this folder is a template. CI overwrites the live tap file with real sha256 on each stable tag.
