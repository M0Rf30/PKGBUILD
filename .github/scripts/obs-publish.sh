#!/usr/bin/env bash
# usage: obs-publish.sh [--push] dir...
# Mirror a package directory's git-tracked files into the same-named OBS package
# (pkgbase) of $OBS_PROJECT, then commit so OBS rebuilds. Packages that do not
# exist on OBS are skipped. OBS-only files (_service, _constraints, ...) are
# kept. Without --push, only report what would change.
set -euo pipefail
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
PRJ=${OBS_PROJECT:-home:M0Rf30}
PUSH=0; [[ ${1:-} == --push ]] && { PUSH=1; shift; }

for d in "$@"; do
  base=$(sed -n 's/^pkgbase=\(["'\'']\?\)\([^"'\'' #$]*\)\1.*/\2/p' "$REPO/$d/PKGBUILD" | head -1)
  base=${base:-$d}
  if ! remote=$(osc api "/source/$PRJ/$base" 2>/dev/null); then
    echo "== $d: no OBS package $PRJ/$base, skipping"
    continue
  fi
  echo "== $d ($PRJ/$base)"

  declare -A want=() have=()
  while read -r f; do
    want[$f]=$(md5sum "$REPO/$d/$f" | cut -d' ' -f1)
  done < <(git -C "$REPO" ls-files "$d" | grep -v "^$d/.*/" | sed "s|^$d/||" | grep -vx '.SRCINFO')
  while read -r name md5; do
    [[ $name == _* ]] || have[$name]=$md5
  done < <(sed -n 's/.*<entry name="\([^"]*\)" md5="\([^"]*\)".*/\1 \2/p' <<<"$remote")

  changed=0
  for f in "${!want[@]}"; do
    [[ ${have[$f]:-} == "${want[$f]}" ]] && continue
    echo "  upload $f"; changed=1
    ((PUSH)) && osc api -X PUT -f "$REPO/$d/$f" "/source/$PRJ/$base/$f?rev=upload" >/dev/null
  done
  for f in "${!have[@]}"; do
    [[ -v want[$f] ]] && continue
    echo "  delete $f"; changed=1
    ((PUSH)) && osc api -X DELETE "/source/$PRJ/$base/$f?rev=upload" >/dev/null
  done
  unset want have

  if ((!changed)); then
    echo "  up to date"
  elif ((PUSH)); then
    msg="Update from M0Rf30/PKGBUILD@$(git -C "$REPO" rev-parse --short HEAD)"
    osc api -X POST "/source/$PRJ/$base?cmd=commit&comment=$(jq -rn --arg m "$msg" '$m|@uri')" >/dev/null
    echo "  committed"
  fi
done
