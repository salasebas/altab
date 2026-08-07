# AlTab {{VERSION}} (source milestone)

> [!IMPORTANT]
> This is a **source-only** milestone. AlTab does **not** publish an official compiled binary, installer, DMG, PKG, dSYM, Sparkle appcast, update signature, or notarization artifact. Clone the repository (or this tag) and build locally.

## Independence

AlTab is an independent [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html) fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos). It is **not affiliated with or endorsed by** the upstream project. Please report problems with this fork in [AlTab Issues](https://github.com/salasebas/altab/issues).

## Product model

- Every included user-facing feature is available without a license, trial, account, purchase, expiry, network response, or paid-access state.
- Feature behavior remains preference-driven; availability never depends on unlock state.
- There is no Sparkle feed, in-app updater, analytics, crash reporting, or licensing network path.

## Get and run this milestone

```bash
git clone https://github.com/salasebas/altab.git
cd altab
git checkout {{TAG}}
scripts/build_local.sh
open DerivedData/Local/Build/Products/Release/AlTab.app
```

Requirements: full **Xcode 26** selected (not Command Line Tools alone), Git, and a recent macOS that can install that Xcode. No Apple Developer account is required for the default ad-hoc build. See the [README](https://github.com/salasebas/altab#run-altab-from-source) for permissions, optional local self-signing, troubleshooting, and uninstall notes.

## Updates

There is no automatic update channel. To move to a newer milestone or `main`:

```bash
git fetch origin --tags
git checkout {{TAG}}   # or: git pull while on main
scripts/build_local.sh
open DerivedData/Local/Build/Products/Release/AlTab.app
```

## Provenance

| Field | Value |
| --- | --- |
| Git tag | `{{TAG}}` |
| Git commit | `{{COMMIT}}` |
| Repository | https://github.com/salasebas/altab |
| Upstream fork point | AltTab `v11.4.3` (`10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`) |
| Last reviewed upstream revision | See [UPSTREAM.md](https://github.com/salasebas/altab/blob/{{TAG}}/UPSTREAM.md) |
| Versioning policy | [docs/releasing.md](https://github.com/salasebas/altab/blob/{{TAG}}/docs/releasing.md) |

Upstream reliability and security changes are reviewed and selectively ported. Updates are **not** automatic; this fork may lag behind official AltTab. Do not claim parity with upstream.

## Known limitations

- No official binary distribution, Developer ID signing, or notarization from this project.
- Local builds use ad-hoc signing by default; optional per-user self-signing is documented for stable permissions.
- Optional third-party redistribution packaging (unsigned) is a separate maintainer tool and is not part of this milestone's published artifacts.
- System-wide macOS interactions (Accessibility, Screen Recording, login items) still require local QA on each machine.

## Changes

{{CHANGES}}
