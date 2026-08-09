<div align="center">

<img src="docs/brand/altab-icon.png" alt="AlTab icon" width="160">

# AlTab

An independent, community-maintained fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos).

Fast window switching for macOS — built from source, fully unrestricted, no license or account.

</div>

> [!IMPORTANT]
> This repository is not affiliated with or endorsed by the AltTab maintainers. Report problems with this fork in [AlTab Issues](https://github.com/salasebas/altab/issues), not upstream. There is **no** in-app updater. Prefer building from source; optional GitHub binaries (when attached) are **unsigned and not notarized**.

## Quick start

You need a Mac with full [Xcode 26](https://developer.apple.com/xcode/) selected and Git. Command Line Tools alone are not enough. No Apple Account, Team ID, or Developer ID is required.

```bash
git clone https://github.com/salasebas/altab.git
cd altab
scripts/codesign/setup_local.sh   # once per Mac (shared by every clone/worktree)
scripts/install_local.sh          # build + install /Applications/AlTab.app + open
```

That is the recommended everyday path. Grant **Accessibility** when prompted (required). **Screen Recording** is optional (live thumbnails).

### Setup once, then choose how to run

| Step | Command | What it does |
| --- | --- | --- |
| **1. Local signing (required once)** | `scripts/codesign/setup_local.sh` | Installs **Local Self-Signed** in your Keychain so permissions survive rebuilds. |
| **2a. Install to Applications (recommended)** | `scripts/install_local.sh` | Builds Release, quits a running AlTab, safely replaces `/Applications/AlTab.app`, and opens it. |
| **2b. Build only** | `scripts/build_local.sh` | Builds optimized `DerivedData/Local/Build/Products/Release/AlTab.app` without installing. |
| **2c. Debug / QA (contributors)** | `scripts/run_debug.sh` | Builds and installs `/Applications/AlTab Dev.app` (separate bundle ID). |

`setup_local.sh` is user-level Keychain state, outside the repository. Run it once per Mac; every clone and worktree reuses it.

### What `install_local.sh` does

- Builds with `scripts/build_local.sh` (skip with `--no-build` if you already built).
- Quits a running AlTab (`dev.salasebas.AlTab`) if needed.
- Stages a verified copy under `/Applications`, then replaces the previous `AlTab.app` (rolls back if final signature checks fail).
- Strips quarantine attributes from the staged copy when present.
- Opens `/Applications/AlTab.app` (skip with `--no-open`).

Do **not** run `ditto` (or drag-replace) directly over an existing `/Applications/AlTab.app` from a quarantined download or an unverified folder. Prefer `scripts/install_local.sh`, which validates the bundle and signing requirement before commit.

Useful flags: `--no-build`, `--no-open`, `--universal` (arm64 + x86_64 in one Release build).

### Update later

```bash
cd altab
git fetch origin --tags
git pull                  # or: git checkout altab-vMAJOR.MINOR.PATCH
scripts/install_local.sh  # setup_local.sh only if this Mac never installed Local Self-Signed
```

Preferences for the same bundle ID are preserved. A different signing identity or bundle ID can require re-granting permissions. Full walkthrough: [docs/building-and-troubleshooting.md](docs/building-and-troubleshooting.md).

### Permissions

| Permission | Required? | Purpose |
| --- | --- | --- |
| **Accessibility** | Yes | Focus the window you select after releasing the shortcut. |
| **Screen Recording** | Optional | Show live window thumbnails and previews. |

### Login item

**Settings → General → Start at login** only affects this fork’s bundle identity (`dev.salasebas.AlTab` by default). It does not enable or disable official AltTab.

## Direction

AlTab preserves AltTab’s fast AppKit window-switching experience. Every locally implemented user-facing feature is available to everyone: Search, Search on Release, Auto size, App Icons and Titles, additional shortcuts, and per-shortcut options remain controlled by your preferences only.

There is no paid-access state, activation, trial, checkout, account, license Keychain path, or environment variable that unlocks features. Building from source is the supported way to run AlTab. Public binary signing, notarization, and a fork-owned update feed are tracked separately in [FORK.md](FORK.md).

## Current milestone

Product version **1.0.1** · tag **`altab-v1.0.1`** · independent of upstream AltTab `v11.x` (tree around **v11.4.x**, no automatic parity).

- **Notes:** [GitHub Release altab-v1.0.1](https://github.com/salasebas/altab/releases/tag/altab-v1.0.1)
- **Supported path:** clone the tag (or `main`) and use Quick start above.
- **Optional binaries:** when attached, packages such as `AlTab-1.0.0-macOS-unsigned.dmg` / `AlTab-1.0.1-macOS-unsigned.dmg` are **unsigned and not notarized** (Gatekeeper will warn). Prefer source builds.

Pin a milestone:

```bash
git checkout altab-v1.0.1
scripts/codesign/setup_local.sh   # once per Mac
scripts/install_local.sh
```

Versioning and redistribution: [docs/releasing.md](docs/releasing.md). Changelog: [changelog.md](changelog.md).

## Uninstall

Removing `AlTab.app` does not erase local state. Residuals for the default Release identity may include:

| Residual | Location |
| --- | --- |
| Preferences | `~/Library/Preferences/dev.salasebas.AlTab.plist` (and related CFPreferences) |
| Local usage counters (About UI only) | UserDefaults suite `dev.salasebas.AlTab.usage` |
| Login item | `~/Library/LaunchAgents/dev.salasebas.AlTab.plist` if **Start at login** was enabled |
| Permissions | Accessibility / Screen Recording grants for this code signature in System Settings |
| Local Self-Signed identity | Keychain entry from `scripts/codesign/setup_local.sh` — remove with `scripts/codesign/remove_local.sh` |

Debug builds use `dev.salasebas.AlTabDev` with the same pattern. AlTab never deletes official AltTab preferences (`com.lwouis.alt-tab-macos`), license suites, or Keychain items.

## Troubleshooting

Use the guide’s [three visual examples](docs/building-and-troubleshooting.md#example-1-prepare-a-mac-and-run-the-right-app) and [decision table](docs/building-and-troubleshooting.md#troubleshooting-table).

Do not disable Gatekeeper or other system-wide security protections, and never use upstream credentials or release infrastructure to make a local build run.

## Privacy

AlTab does not bundle or initialize Sparkle, AppCenter, crash reporting, analytics, or telemetry. It has no licensing, trial, checkout, or account network path and does not contact upstream services for feature access.

On first launch, AlTab may locally import compatible settings from the official AltTab defaults domain into missing AlTab keys. Existing AlTab choices win; unsupported and identity-specific state is skipped. AltTab’s preferences, license data, and Keychain items are left untouched. Login-item and permission state are not transferred.

## Optional redistribution packaging

Official milestones ship **source only** (Git tag + release notes) unless a distributor intentionally attaches reviewed artifacts. Optional packaging tools (separate from the normal local build):

```bash
# Unsigned universal ZIP + exact source + checksums (no Apple credentials)
scripts/package_release.sh <tag-or-commit>

# Bring-your-own Developer ID + notarization (never silently falls back to unsigned)
scripts/package_notarized_release.sh <tag-or-commit> \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --team-id TEAMID \
  --bundle-id your.stable.bundle.id \
  --notary-profile YourNotaryProfile
```

GitHub Actions: manual workflow [Release packaging](.github/workflows/release.yml) with explicit `unsigned` or `notarized` mode. Secrets and contracts: [docs/releasing.md](docs/releasing.md).

## Relationship with upstream

This fork began at AltTab `v11.4.3` (`10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`). The original Git history is retained so authorship and provenance remain visible.

Last reviewed upstream revision: AltTab `v11.4.4` (`081f3ee4014e03557c2ab39e9e168dac308fa49b`). Applicable reliability, capture, gesture, shortcut, Space, and tracked-window changes from that range are selectively integrated on `main`; AlTab is not automatically synchronized and may still lag behind future upstream work. See [UPSTREAM.md](UPSTREAM.md) for the commit matrix, deferred/skipped decisions, and integration policy.

## License and attribution

The application is licensed **GPL-3.0-only** ([GNU General Public License v3](LICENCE.md)). Distributions of modified binaries must satisfy the GPL’s source and notice requirements. Copyright and provenance are summarized in [NOTICE.md](NOTICE.md), and third-party acknowledgments and license locations are in [docs/acknowledgments.md](docs/acknowledgments.md).

App Sandbox is disabled in this project (same retained entitlement as upstream). The supported binary channel—if you package one yourself—is direct distribution (unsigned with a warning, or Developer ID signed/notarized with your identity). Mac App Store distribution is not supported.

The AlTab icon used on this page comes from the maintainer’s [earlier AlTab codebase](https://github.com/salasebas/altab-archived) and is separate from the upstream AltTab branding. Its provenance and license are recorded in [docs/brand/README.md](docs/brand/README.md).
