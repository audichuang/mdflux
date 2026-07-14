# Homebrew cask — MDFlux

Live cask lives in **[audichuang/homebrew-tap](https://github.com/audichuang/homebrew-tap)** (`Casks/mdflux.rb`).  
This folder is a **draft/template** only; CI rewrites the live file on each stable tag.

## User install

```bash
brew tap audichuang/tap
brew install --cask audichuang/tap/mdflux
```

| | |
|---|---|
| Arch | **Apple Silicon only** (`arm64`) |
| Artifact | `MDFlux_<version>_aarch64.dmg` from GitHub Releases |
| Version source | Stable `v*` tags (not `offline-latest`, not `v*-rc`) |
| Windows | setup.exe / portable zip only (never via Homebrew) |

```bash
brew update && brew upgrade --cask mdflux
brew uninstall --cask mdflux          # or: brew uninstall --cask --zap mdflux
```

If the cask “does not exist” after a release: `brew update` (stale local tap). Details: [tap README](https://github.com/audichuang/homebrew-tap).

Unsigned builds may need:

```bash
xattr -cr /Applications/MDFlux.app
```

## Maintainer flow

1. Bump version in `app/package.json`, `app/src-tauri/tauri.conf.json`, `Cargo.toml` (+ lock)
2. Tag `vX.Y.Z` and push
3. CI **Portable build**:
   - Windows → setup.exe + portable zip
   - macOS → aarch64 dmg
   - Publish release assets
   - **`publish-homebrew`** rewrites `audichuang/homebrew-tap` `Casks/mdflux.rb` (version + sha256 + modern stanzas)

## Repo secret

| Secret | Purpose |
|--------|---------|
| `HOMEBREW_TAP_TOKEN` | PAT with write access to `audichuang/homebrew-tap` |

Without it, Windows + mac packages still publish; only the tap job fails on tags.

## Draft cask

`Casks/mdflux.rb` here is the template shape (livecheck, `depends_on macos: :big_sur`, zap paths).  
CI embeds real `version` / `sha256` into the live tap file — do not commit a real sha into this draft.
