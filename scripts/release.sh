#!/usr/bin/env bash
# Cut a public MDFlux release: bump the four manifests → push main → tag → watch
# CI → verify. ONE version, three artifacts (Windows setup.exe + portable zip,
# macOS aarch64 dmg) plus the Homebrew cask, all published from one v* tag.
#
#   bash scripts/release.sh 0.2.0          # interactive confirm
#   bash scripts/release.sh 0.2.0 --yes    # skip the confirm
#
# A tag triggers a REAL public GitHub Release + Homebrew cask bump. The model,
# invariants, and troubleshooting live in
# .claude/skills/releasing-mdflux/SKILL.md — read it before doing anything this
# script does not cover (notably re-releasing a botched tag).
set -euo pipefail

REPO="audichuang/mdflux"
WF="portable.yml"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
YES="${2:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: release.sh X.Y.Z [--yes]   (got '${VERSION:-<empty>}')" >&2
  exit 2
fi
TAG="v$VERSION"

# ── Preconditions — never tag from a dirty tree, wrong branch, or a taken tag ──
[[ "$(git branch --show-current)" == "main" ]] || { echo "not on main" >&2; exit 2; }
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree dirty — commit or stash before releasing" >&2; exit 2
fi
git fetch --tags -q origin
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "tag $TAG already exists — pick a new version, or see 'Re-release a botched tag' in the skill" >&2
  exit 2
fi
CUR="$(python3 -c "import json;print(json.load(open('app/package.json'))['version'])")"
echo "current $CUR  →  new $VERSION  (tag $TAG)"

# ── Bump all four manifests together (this script is the single source) ──
# CI reads tauri.conf.json for the artifact filenames and the tag for the cask
# URL, so the manifest version MUST equal the tag or the cask download 404s.
python3 - "$VERSION" <<'PY'
import re, sys, pathlib
v = sys.argv[1]
def bump(path, pat, repl):
    p = pathlib.Path(path); s = p.read_text()
    s2, n = re.subn(pat, repl, s, count=1)
    if n != 1:
        sys.exit(f"bump failed: no match in {path}")
    p.write_text(s2)
bump("app/package.json",              r'"version":\s*"[^"]*"',      f'"version": "{v}"')
bump("app/src-tauri/tauri.conf.json", r'"version":\s*"[^"]*"',      f'"version": "{v}"')
bump("app/src-tauri/Cargo.toml",      r'(?m)^version\s*=\s*"[^"]*"', f'version = "{v}"')
bump("app/src-tauri/Cargo.lock",      r'(name = "app"\nversion = ")[^"]*"', rf'\g<1>{v}"')
print(f"bumped package.json / tauri.conf.json / Cargo.toml / Cargo.lock → {v}")
PY
git --no-pager diff --stat

if [[ "$YES" != "--yes" ]]; then
  read -r -p "Commit, push main, tag $TAG, and cut a PUBLIC release? [y/N] " a
  if [[ "$a" != "y" && "$a" != "Y" ]]; then
    echo "aborted — reverting bump"
    git checkout -- app/package.json app/src-tauri/tauri.conf.json app/src-tauri/Cargo.toml app/src-tauri/Cargo.lock
    exit 1
  fi
fi

# ── Watch a workflow run for a ref; auto-rerun ONCE on a transient flake ──
# The recurring macOS failure is setup-uv hitting GitHub's anon API rate limit
# (see the skill's troubleshooting table) — a re-run, not a code fix.
run_id_for() { # $1 = head branch or tag name
  gh run list --repo "$REPO" --workflow "$WF" --limit 20 \
    --json databaseId,headBranch,createdAt \
    --jq "[.[] | select(.headBranch==\"$1\")] | sort_by(.createdAt) | last | .databaseId"
}
watch_ref() { # $1 = ref name (main | vX.Y.Z)
  local ref="$1" id tries=0
  for _ in 1 2 3 4 5 6; do
    id="$(run_id_for "$ref")"; [[ -n "$id" && "$id" != "null" ]] && break; sleep 5
  done
  [[ -n "$id" && "$id" != "null" ]] || { echo "no $WF run found for $ref" >&2; return 1; }
  echo "watching $ref → run $id"
  while true; do
    if gh run watch "$id" --repo "$REPO" --exit-status; then
      echo "$ref run $id GREEN"; return 0
    fi
    tries=$((tries + 1))
    if [[ $tries -ge 2 ]]; then
      echo "$ref run $id failed twice — not transient. Inspect: gh run view $id --repo $REPO --log-failed" >&2
      return 1
    fi
    echo "$ref run $id failed once — re-running failed jobs (likely transient setup-uv/sccache)."
    gh run rerun --failed "$id" --repo "$REPO"; sleep 8
  done
}

# ── Push bump to main, gate on a green main build before tagging ──
git add app/package.json app/src-tauri/tauri.conf.json app/src-tauri/Cargo.toml app/src-tauri/Cargo.lock
git commit -q -m "chore: 升版 $VERSION"
git push origin main
watch_ref main || { echo "main build red — NOT tagging" >&2; exit 1; }

# ── Tag + push → the versioned Release + Homebrew cask ──
git tag "$TAG"
git push origin "$TAG"
watch_ref "$TAG" || { echo "release build red — see 'Re-release a botched tag' in the skill" >&2; exit 1; }

# ── Verify ──
echo "── release assets (expect setup.exe + portable zip + aarch64.dmg) ──"
gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name'
echo "── Homebrew cask (version + sha256 must be non-empty) ──"
gh api "repos/audichuang/homebrew-tap/contents/Casks/mdflux.rb" --jq .content 2>/dev/null \
  | base64 -d | grep -E 'version|sha256' \
  || echo "(cask not updated — check HOMEBREW_TAP_TOKEN; the Release itself still published)"
echo "DONE: $TAG → https://github.com/$REPO/releases/tag/$TAG"
echo "users:  brew install --cask audichuang/tap/mdflux   (or download the Release assets)"
