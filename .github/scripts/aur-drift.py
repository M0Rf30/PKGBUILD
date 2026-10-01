#!/usr/bin/env python3
"""Compare every PKGBUILD in this repo with the AUR and print a Markdown report.

Prints nothing when repo and AUR agree. Run from the repo root.
"""
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ME = {u.lower() for u in os.environ.get("AUR_USER", "robertfoster").split(",") if u}


def srcinfo(d):
    r = subprocess.run(["makepkg", "--printsrcinfo"], cwd=d, capture_output=True, text=True)
    if r.returncode:
        return d, None
    info = {"pkgname": []}
    for line in r.stdout.splitlines():
        k, sep, v = line.strip().partition(" = ")
        if not sep:
            continue
        if k == "pkgname":
            info["pkgname"].append(v)
        elif k in ("pkgver", "pkgrel", "epoch"):
            info.setdefault(k, v)
    return d, info


def version(i):
    v = f"{i['pkgver']}-{i['pkgrel']}"
    return f"{i['epoch']}:{v}" if "epoch" in i else v


def vercmp(a, b):
    return int(subprocess.run(["vercmp", a, b], capture_output=True, text=True).stdout)


def main():
    dirs = sorted(d for d in os.listdir(".") if os.path.isfile(f"{d}/PKGBUILD"))
    with ThreadPoolExecutor(8) as ex:
        local = dict(ex.map(srcinfo, dirs))
    broken = [d for d, i in local.items() if i is None]
    names = sorted({n for i in local.values() if i for n in i["pkgname"]})
    aur = {}
    for k in range(0, len(names), 100):
        q = "&".join("arg[]=" + urllib.parse.quote(n) for n in names[k : k + 100])
        with urllib.request.urlopen(f"https://aur.archlinux.org/rpc/v5/info?{q}", timeout=30) as r:
            aur.update({x["Name"]: x for x in json.load(r)["results"]})

    sections = {
        "PKGBUILD fails `makepkg --printsrcinfo`": broken,
        "Not on the AUR": [],
        "Orphaned on the AUR": [],
        "Maintained by someone else": [],
        "Flagged out-of-date": [],
        "Repo newer than AUR (unpublished)": [],
        "AUR newer than repo (repo behind)": [],
    }
    for d, i in local.items():
        if not i:
            continue
        name = i["pkgname"][0]
        a = aur.get(name)
        if not a:
            sections["Not on the AUR"].append(d)
            continue
        m = (a.get("Maintainer") or "").lower()
        co = {c.lower() for c in a.get("CoMaintainers") or []}
        if not m:
            sections["Orphaned on the AUR"].append(d)
        elif m not in ME and not (co & ME):
            sections["Maintained by someone else"].append(f"{d} ({a['Maintainer']})")
        if a.get("OutOfDate"):
            sections["Flagged out-of-date"].append(d)
        lv = version(i)
        # VCS package versions legitimately differ between pushes
        if a["Version"] != lv and not d.endswith(("-git", "-svn", "-hg", "-bzr")):
            key = "Repo newer than AUR (unpublished)" if vercmp(lv, a["Version"]) > 0 else "AUR newer than repo (repo behind)"
            sections[key].append(f"{d}: repo `{lv}`, AUR `{a['Version']}`")

    out = []
    for title, items in sections.items():
        if items:
            out.append(f"### {title} ({len(items)})\n" + "\n".join(f"- {x}" for x in sorted(items)))
    if out:
        print("\n\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
