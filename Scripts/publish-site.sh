#!/bin/bash
# Publish the reviewed static site without modifying the current checkout or force-pushing.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
[ -f site/index.html ] || { echo 'site/index.html is missing.' >&2; exit 1; }
git fetch origin
temporary=$(mktemp -d "${TMPDIR:-/tmp}/plam-pages.XXXXXX")
worktree="$temporary/site"
cleanup() { git worktree remove --force "$worktree" >/dev/null 2>&1 || true; rm -rf "$temporary"; }
trap cleanup EXIT
if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
    git worktree add --detach "$worktree" origin/gh-pages
else
    git worktree add --detach "$worktree" HEAD
    git -C "$worktree" switch --orphan "publish-pages-$(date +%s)"
    git -C "$worktree" rm -rf --ignore-unmatch . >/dev/null
fi
# Remove previous tracked assets; site/ is the complete publishing input.
git -C "$worktree" rm -rf --ignore-unmatch . >/dev/null
cp -R "$root/site/." "$worktree/"
git -C "$worktree" add .
if ! git -C "$worktree" diff --cached --quiet; then
    git -C "$worktree" commit -m "Publish Plam download website"
    git -C "$worktree" push origin HEAD:gh-pages
fi
