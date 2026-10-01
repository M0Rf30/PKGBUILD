#!/usr/bin/env bash
# usage: aur-publish.sh [--push] dir...
set -euo pipefail
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
PUSH=0; [[ ${1:-} == --push ]] && { PUSH=1; shift; }
export GIT_SSH_COMMAND="ssh -o AddressFamily=inet"
for d in "$@"; do
  base=$(cd "$REPO/$d" && makepkg --printsrcinfo | sed -n 's/^pkgbase = //p')
  w=/tmp/aur/$base; rm -rf "$w"
  git clone -q "ssh://aur@aur.archlinux.org/$base.git" "$w"
  find "$w" -maxdepth 1 -type f ! -name .SRCINFO -delete
  (cd "$REPO" && git ls-files "$d" | grep -v '/.*/' ) | while read -r f; do cp "$REPO/$f" "$w/"; done
  (cd "$w" && makepkg --printsrcinfo > .SRCINFO && git add -A)
  echo "== $d ($base)"; git -C "$w" status --short
  if ((PUSH)) && ! git -C "$w" diff --cached --quiet; then
    git -C "$w" commit -qm "Update from M0Rf30/PKGBUILD@$(git -C "$REPO" rev-parse --short HEAD)"
    git -C "$w" push -q origin HEAD:master && echo "pushed $base"
  fi
done
