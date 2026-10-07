#!/usr/bin/env bash
# Check upstream `url=` and remote `source=` entries of every PKGBUILD with lychee.
# Variables are expanded via `makepkg --printsrcinfo`, one URL list per package,
# so the lychee report is grouped by package name.
#
# Usage: check-urls.sh [pkgdir...]   (default: every dir with a PKGBUILD)
# Env:   LYCHEE (binary, default: lychee), GITHUB_TOKEN (recommended),
#        OUT (markdown report path, default: lychee-report.md)
set -uo pipefail

root=$(git rev-parse --show-toplevel)
lychee=${LYCHEE:-lychee}
out=$(realpath -m "${OUT:-lychee-report.md}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ $# -gt 0 ]; then dirs=("$@"); else
  mapfile -t dirs < <(cd "$root" && printf '%s\n' */PKGBUILD | xargs -n1 dirname | sort)
fi

for d in "${dirs[@]}"; do
  pkg=$(basename "$d")
  if ! srcinfo=$(cd "$root/$d" && makepkg --printsrcinfo 2>/dev/null); then
    echo "warn: $pkg: makepkg --printsrcinfo failed" >&2
    continue
  fi
  awk -F' = ' '
    $1 ~ /^\t(url|source(_[a-z0-9_]+)?)$/ {
      u = $2
      sub(/^[^:\/]*::/, "", u)            # drop "name::" rename prefix
      sub(/^[a-z]+\+/, "", u)             # git+https:// -> https://
      sub(/#.*$/, "", u)                  # drop VCS fragment (#tag=, #branch=)
      sub(/\?signed$/, "", u)
      if (u ~ /^https?:\/\//) print u
    }' <<<"$srcinfo" | sort -u >"$work/$pkg"
  [ -s "$work/$pkg" ] || rm -f "$work/$pkg"
done

cd "$work" || exit 1
# GET on release assets is cheap enough: lychee only reads response headers.
# 403/429 come from bot protection (SourceForge, Cloudflare), not dead links.
"$lychee" \
  --no-progress \
  --format markdown \
  --output "$out" \
  --max-concurrency 16 \
  --max-retries 2 \
  --timeout 30 \
  --accept '100..=103,200..=299,403,429' \
  --exclude-all-private \
  -- *
