# PKGBUILD

[![publish](https://github.com/M0Rf30/PKGBUILD/actions/workflows/publish.yml/badge.svg)](https://github.com/M0Rf30/PKGBUILD/actions/workflows/publish.yml)
[![renovate](https://github.com/M0Rf30/PKGBUILD/actions/workflows/renovate.yml/badge.svg)](https://github.com/M0Rf30/PKGBUILD/actions/workflows/renovate.yml)

Source of truth for the [AUR](https://aur.archlinux.org/packages?K=robertfoster&SeB=m) packages
maintained by **robertfoster**.

Every top-level directory is one AUR package base. Merging to `main` publishes it to the AUR
automatically. Upstream updates are tracked by Renovate.

## Using a package

Install from the AUR with your helper of choice:

```sh
paru -S <pkgname>
```

or build straight from this repository:

```sh
git clone https://github.com/M0Rf30/PKGBUILD
cd PKGBUILD/<pkgname>
makepkg -si
```

Bugs in the packaging belong in this repo's issues or in the AUR comments. Report bugs in the
software itself upstream.

## Repository layout

| Path | Meaning |
| --- | --- |
| `<pkgbase>/` | One AUR package base: `PKGBUILD` plus local sources (patches, `.desktop`, `.service`, …). The directory name **must** equal the AUR `pkgbase`. |
| `not-mine/` | PKGBUILDs I contribute to but don't maintain on the AUR. Never published. |
| `not-on-aur/` | Local or experimental packages that aren't published. |
| `abandoned/` | Packages whose upstream is dead, archived or unbuildable. Kept for reference, never published; candidates for disowning/deletion on the AUR. |
| `.github/` | CI: publishing, checksums, linting, Renovate, drift report. |

`.SRCINFO` is **not** committed. CI generates it at publish time.

## Automation

```
upstream release ──► Renovate PR ──► updpkgsums (+ pkgrel reset) ──► lint ──► merge ──► publish to AUR
```

| Workflow | Trigger | What it does |
| --- | --- | --- |
| [`renovate`](.github/workflows/renovate.yml) | daily, on PKGBUILD push | Bumps `pkgver` (and annotated helper variables) from upstream releases or tags. |
| [`updpkgsums`](.github/workflows/updpkgsums.yml) | PR | For **every** package changed in the PR: runs `updpkgsums`, resets `pkgrel=1` when `pkgver` changed, validates `.SRCINFO` generation, and commits the result back to the PR. |
| [`lint`](.github/workflows/lint.yml) | PR | `shellcheck`, `namcap` and `makepkg --printsrcinfo` on the changed packages. |
| [`publish`](.github/workflows/publish.yml) | push to `main`, manual | Finds **every** package directory touched by the push (all commits, not only the last) and publishes each to the AUR in parallel. The whole directory is mirrored, so patches and service files are published too. |
| [`aur-drift`](.github/workflows/drift.yml) | daily, manual | Compares the repo with the AUR and keeps one issue updated with the differences: unpublished or outdated versions, orphaned, flagged or foreign-maintained packages. Run it locally with `python .github/scripts/aur-drift.py`. |

### Publishing manually

Use *Actions → publish → Run workflow* and pass a space-separated list of directories to force
a republish, e.g. `kuna-bin ceasta ceasta-git`.

> **Note:** publishing mirrors the directory. Files that exist on the AUR but not here are
> **deleted** from the AUR repository.

## Renovate annotations

Renovate has no native PKGBUILD support. A regex manager picks up a trailing comment on the
`pkgver=` line (or on any `_variable=` line):

```bash
pkgver=1.624 # renovate: datasource=github-releases depName=Noelo-Lab/kuna
_flutter=3.47.0 # renovate: datasource=github-tags depName=flutter/flutter
```

Format: `# renovate: datasource=<ds> depName=<dep> [extractVersion=<regex>] [registryUrl=<url>]`.
The fields must appear in that order on the **same line** as the variable.

- Common datasources: `github-releases`, `github-tags`, `git-tags` (with `depName=<git url>`),
  `forgejo-releases`, `crate`, `pypi`, `npm`, `snapcraft`.
- A leading `v` is stripped by default. Override with
  `extractVersion=^release-(?<version>.*)$`.
- Checksums and `pkgrel` are fixed afterwards by the `updpkgsums` workflow.
- VCS packages (`-git`, `-svn`, …) don't need annotations: their `pkgver()` handles versioning.

## Conventions

- `# Maintainer:` header on every PKGBUILD.
- SPDX identifiers in `license=()`, e.g. `GPL-3.0-or-later`, `MIT`, `LicenseRef-<name>`.
- No `i686`. Use `x86_64`, plus `aarch64`/`armv7h` where upstream supports them.
- `sha256sums` (or stronger) for every non-VCS source; `SKIP` only for VCS sources.
- `https://` sources whenever upstream offers them.
- `-git` packages provide and conflict with their stable counterpart.
- Quote `"$srcdir"` and `"$pkgdir"`. Build Rust with `--locked`, Go with `-trimpath`, and Python
  with `python -m build` + `python -m installer`.
- Reset `pkgrel=1` on every `pkgver` change. Bump `pkgrel` for packaging-only changes.
- One package per commit is **not** required: `<pkgname>: <version>` or a conventional-commit
  subject is enough.

## Checking a package locally

```sh
cd <pkgname>
updpkgsums
makepkg --printsrcinfo >/dev/null
namcap PKGBUILD
shellcheck PKGBUILD        # uses the repo .shellcheckrc
makepkg -sf && namcap *.pkg.tar.zst
```

## Required secrets

| Secret | Used by |
| --- | --- |
| `AUR_USERNAME`, `AUR_EMAIL`, `AUR_SSH_PRIVATE_KEY` | `publish` |
| `RENOVATE_TOKEN` | `renovate`; also `updpkgsums`, so its commits re-trigger required checks |

## License

The packaging files in this repository are licensed under the GNU GPL v3; see [`COPYING`](COPYING).
The packaged software keeps its own upstream licenses.
