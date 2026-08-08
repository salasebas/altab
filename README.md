<div align="center">

<img src="docs/brand/altab-icon.png" alt="AlTab icon" width="160">

# AlTab

An independent, community-maintained fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos).

</div>

> [!IMPORTANT]
> This repository is not affiliated with or endorsed by the AltTab maintainers. Please report problems with this fork in [AlTab Issues](https://github.com/salasebas/altab/issues), not to the upstream project. This repository does **not** publish official binaries and has **no** in-app updater.

## Current source milestone

The first audited **source-only** milestone is **[AlTab 1.0.0](https://github.com/salasebas/altab/releases/tag/altab-v1.0.0)** (`altab-v1.0.0`). It is a Git tag and release notes only—no `.app`, DMG, PKG, or update feed is attached. Product versioning, future milestones, and update/rebuild steps are documented in [docs/releasing.md](docs/releasing.md).

Pin a clean checkout to that milestone when you want a frozen, reviewed revision:

```bash
git clone https://github.com/salasebas/altab.git
cd altab
git checkout altab-v1.0.0
scripts/codesign/setup_local.sh   # once per Mac
scripts/build_local.sh
```

## Direction

AlTab preserves AltTab's fast AppKit window-switching experience. Every locally implemented user-facing feature is available to everyone: Search, Search on Release, Auto size, App Icons and Titles, additional shortcuts, and per-shortcut options remain controlled by your preferences only.

There is no paid-access state, activation, trial, checkout, account, license Keychain path, or environment variable that unlocks features. Building from source is the supported way to run AlTab. Public binary signing, notarization, and a fork-owned update feed are tracked separately in [FORK.md](FORK.md) and are not required for local use.

## Run AlTab from source

You need a Mac with full [Xcode 26](https://developer.apple.com/xcode/) selected and Git. Command Line Tools alone are not enough. No Apple Account, provisioning profile, Team ID, Apple Development identity, or Developer ID identity is required for routine local builds.

The illustrated [building and troubleshooting guide](docs/building-and-troubleshooting.md) is the canonical walkthrough for selecting Xcode, understanding local signing, running Debug/Release builds, repairing Keychain state, and fixing macOS permissions.

### Quick start

```bash
git clone https://github.com/salasebas/altab.git
cd altab
scripts/codesign/setup_local.sh   # once per Mac (shared by every clone/worktree)
scripts/build_local.sh
```

`setup_local.sh` installs the canonical **Local Self-Signed** identity in the user Keychain, outside the repository. It is shared by every clone and worktree for that macOS user. `scripts/build_local.sh` builds and verifies an optimized native-architecture Release app, then prints its exact path and launch command:

```bash
open "DerivedData/Local/Build/Products/Release/AlTab.app"
```

Contributors should use `scripts/run_debug.sh` to build, install, and open the canonical `/Applications/AlTab Dev.app`. Pass `--universal` to `scripts/build_local.sh` only when one Release bundle must contain both `arm64` and `x86_64`.

### Permissions

| Permission | Required? | Purpose |
|---|---|---|
| **Accessibility** | Yes | Focus the window you select after releasing the shortcut. |
| **Screen Recording** | Optional | Show live window thumbnails and previews. |

The default `Local Self-Signed` identity lets these grants survive ordinary rebuilds. Screen Recording may be skipped with **Use the app without this permission. Thumbnails won’t show.** The visual recovery steps for stale or duplicate permission rows are in the [building and troubleshooting guide](docs/building-and-troubleshooting.md#example-3-repair-accessibility-and-screen-recording).

### Login item

AlTab can start at login through its own preference (**Settings → General → Start at login**). That setting only affects this fork's bundle identity (`dev.salasebas.AlTab` by default). It does not enable or disable official AltTab, and first-launch preference import does not copy login-item or permission state from AltTab.

### Signing

Interactive Debug and routine local Release use `Local Self-Signed`, installed once with `scripts/codesign/setup_local.sh`. It is not a distributable identity. The [canonical guide](docs/building-and-troubleshooting.md) covers the supported local workflow; [releasing.md](docs/releasing.md) covers redistribution artifacts and the current signing limitation.

### Updates

There is no Sparkle feed and no in-app updater. Update from source:

```bash
cd altab
git fetch origin --tags
git pull                  # or: git checkout altab-vMAJOR.MINOR.PATCH
scripts/build_local.sh    # setup_local.sh only if this Mac has never installed Local Self-Signed
open DerivedData/Local/Build/Products/Release/AlTab.app
```

If you copied `AlTab.app` elsewhere, replace that copy with the newly built app and relaunch. Preferences for the same bundle ID are preserved by macOS; a different signing identity or bundle ID can require re-granting permissions. Milestone tags and the versioning policy live in [docs/releasing.md](docs/releasing.md).

### Uninstall

Removing `AlTab.app` does not erase local state. Residuals for the default Release identity may include:

| Residual | Location |
|---|---|
| Preferences | `~/Library/Preferences/dev.salasebas.AlTab.plist` (and related CFPreferences) |
| Local usage counters (About UI only) | UserDefaults suite `dev.salasebas.AlTab.usage` |
| Login item | `~/Library/LaunchAgents/dev.salasebas.AlTab.plist` if **Start at login** was enabled |
| Permissions | Accessibility / Screen Recording grants for this code signature in System Settings |
| Local Self-Signed identity | Keychain entry from `scripts/codesign/setup_local.sh` — remove with `scripts/codesign/remove_local.sh` |

Debug builds use `dev.salasebas.AlTabDev` with the same pattern. AlTab never deletes official AltTab preferences (`com.lwouis.alt-tab-macos`), license suites, or Keychain items.

### Troubleshooting

Use the guide's [three visual examples](docs/building-and-troubleshooting.md#example-1-prepare-a-mac-and-run-the-right-app) and [decision table](docs/building-and-troubleshooting.md#troubleshooting-table). They cover Xcode selection, `Local Self-Signed`, Keychain errors, stale app copies, Accessibility, Screen Recording, and validation failures.

Do not disable Gatekeeper or other system-wide security protections, and never use upstream credentials or release infrastructure to make a local build run.

## Privacy

AlTab does not bundle or initialize Sparkle, AppCenter, crash reporting, analytics, or telemetry. It has no licensing, trial, checkout, or account network path and does not contact upstream services for feature access.

On first launch, AlTab may locally import compatible settings from the official AltTab defaults domain into missing AlTab keys. Existing AlTab choices win; unsupported and identity-specific state is skipped. AltTab's preferences, license data, and Keychain items are left untouched. Login-item and permission state are not transferred.

## Optional redistribution packaging

Official milestones ship **source only** (Git tag + release notes). Maintainers who still need to assemble optional unsigned redistribution artifacts (app ZIP, matching dSYM, exact source archive, manifest, notes, checksums) from an explicit tag or full commit can use:

```bash
scripts/package_release.sh <tag-or-commit>
```

That tool is separate from the normal local build and is not used for official milestone publication. See [docs/releasing.md](docs/releasing.md). If anyone publishes preview binaries before Developer ID signing and notarization exist, each build must be labeled **unsigned and not notarized**. Users must never be told to disable system-wide security protections.

## Relationship with upstream

This fork began at AltTab `v11.4.3` (`10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`). The original Git history is retained so authorship and provenance remain visible.

Upstream changes are reviewed periodically, with security, crash, compatibility, and performance fixes prioritized. Changes are integrated selectively; AlTab is not automatically synchronized and may lag behind upstream. See [UPSTREAM.md](UPSTREAM.md) for the last reviewed revision and the integration policy.

## License and attribution

The application remains available under the [GNU General Public License v3](LICENCE.md). Distributions of modified binaries must satisfy the GPL's source and notice requirements. Copyright and provenance are summarized in [NOTICE.md](NOTICE.md), and third-party acknowledgments and license locations are in [docs/acknowledgments.md](docs/acknowledgments.md).

The AlTab icon used on this page comes from the maintainer's [earlier AlTab codebase](https://github.com/salasebas/altab-archived) and is separate from the upstream AltTab branding. Its provenance and license are recorded in [docs/brand/README.md](docs/brand/README.md).
