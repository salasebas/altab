# Changelog

AlTab product milestones use Git tags `altab-vMAJOR.MINOR.PATCH` and optional GitHub Releases. Versions are **independent** of upstream AltTab (`v11.x` and earlier). Upstream release notes are **not** copied here; see [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos) for that history.

Conventional commits merged to `main` accumulate under **Unreleased**. A maintainer promotes them to a versioned section only when cutting an intentional milestone (see [docs/releasing.md](docs/releasing.md)).

<!-- altab-changelog:unreleased-start -->
## Unreleased

<!-- altab-changelog:unreleased-end -->

## [1.0.0](https://github.com/salasebas/altab/releases/tag/altab-v1.0.0) — first public milestone (2026-08-09)

First public AlTab source milestone. Tag: `altab-v1.0.0`. Product version **1.0.0**.

Independent [GPL-3.0-only](https://www.gnu.org/licenses/gpl-3.0.html) fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos), based on the upstream tree around **v11.4.x**. No automatic feature parity is claimed. Selective ports, deferrals, and hard skips are tracked in [UPSTREAM.md](UPSTREAM.md) and [FORK.md](FORK.md).

### Product

* Fast AppKit window switcher with AlTab branding, bundle IDs, and repository links
* Every included user-facing feature available without license, trial, account, purchase, or paid-access state
* Preference-driven behavior only (Search, shortcuts, layout, and related options)
* One-time local import of compatible AltTab preferences into missing AlTab keys
* App Sandbox remains disabled; Mac App Store distribution is not supported
* No Sparkle updater, AppCenter/crash reporting, analytics, or upstream licensing endpoints

### Distribution

* Source-first: clone the tag and build with **Local Self-Signed** + `scripts/build_local.sh`
* Optional **unsigned and not notarized** redistribution packages may be attached later on the same Release (never auto-shipped on cut)
* GitHub Release for this milestone is **source notes** by default; prefer building from source when you can
