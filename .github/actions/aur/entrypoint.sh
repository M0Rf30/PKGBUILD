#!/usr/bin/env bash
set -euo pipefail

ACTION=${INPUT_ACTION:-${1:-updpkgsums}}
PKGNAMES=${INPUT_PKGNAME:-${2:-}}
BASE=${INPUT_BASE:-${3:-}}

if [[ $ACTION != updpkgsums ]]; then
  echo "::error::Unsupported action '$ACTION'"
  exit 1
fi

echo "::group::Updating system"
sudo pacman -Syu --noconfirm --needed archlinux-keyring
echo "::endgroup::"

git config --global --add safe.directory "$GITHUB_WORKSPACE"

pkgver_of() { sed -n 's/^pkgver=\([^ #]*\).*/\1/p' | head -1; }

rc=0
for pkg in $PKGNAMES; do
  src=$GITHUB_WORKSPACE/$pkg
  work=$(mktemp -d)
  echo "::group::$pkg"
  cp -a "$src"/. "$work"/
  cd "$work"

  # Renovate bumps pkgver but cannot reset pkgrel
  if [[ -n $BASE ]]; then
    old=$(git -C "$GITHUB_WORKSPACE" show "$BASE:$pkg/PKGBUILD" 2>/dev/null | pkgver_of || true)
    new=$(pkgver_of <PKGBUILD)
    if [[ -n $old && $old != "$new" ]]; then
      echo "pkgver $old -> $new: resetting pkgrel to 1"
      sed -i 's/^pkgrel=.*/pkgrel=1/' PKGBUILD
    fi
  fi

  if updpkgsums && makepkg --printsrcinfo >/dev/null; then
    namcap PKGBUILD || true
    sudo cp -f PKGBUILD "$src"/PKGBUILD
    git -C "$GITHUB_WORKSPACE" --no-pager diff -- "$pkg/PKGBUILD" || true
  else
    echo "::error::$pkg: updpkgsums/printsrcinfo failed"
    rc=1
  fi
  cd /
  rm -rf "$work"
  echo "::endgroup::"
done
exit $rc
