# Offline Python runtime (build artefact)

This folder is filled by `scripts/bundle-runtime.sh` (or `.ps1`) before packaging
an **offline** portable zip.

Expected layout after bundling:

```
runtime/
  BUNDLED.txt
  python/
    python.exe          # Windows x64 CPython
    python312.dll
    Lib/site-packages/  # markitdown + core format deps
    …
```

It is not committed to git (see root `.gitignore`). If this tree is missing, the
app falls back to the classic first-launch online provision into `%APPDATA%`.
