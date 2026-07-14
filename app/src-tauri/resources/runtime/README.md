# Offline Python runtime (build artefact)

Filled by `scripts/bundle-runtime.sh` (or `.ps1`) before packaging an **offline** build.

```
runtime/
  BUNDLED.txt
  python/
    # Windows x64:  python.exe + Lib/site-packages/
    # macOS arm64:  bin/python + lib/python3.12/site-packages/
```

```bash
# Windows portable / NSIS
bash scripts/bundle-runtime.sh --platform windows-x64

# macOS Apple Silicon DMG / Homebrew cask
bash scripts/bundle-runtime.sh --platform macos-arm64
```

Not committed to git (see root `.gitignore`). Missing tree → first-launch online provision.
