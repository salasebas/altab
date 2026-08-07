<div align="center">

<img src="docs/brand/altab-icon.png" alt="AlTab icon" width="160">

# AlTab

An independent, community-maintained fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos).

</div>

> [!IMPORTANT]
> This repository is in the fork-bootstrap stage. It is not affiliated with or endorsed by the AltTab maintainers. Please report problems with this fork in [AlTab Issues](https://github.com/salasebas/altab/issues), not to the upstream project.

## Direction

AlTab preserves AltTab's fast AppKit window-switching experience and includes every locally implemented user-facing feature. Search, Search on Release, Auto size, App Icons and Titles, additional shortcuts, and per-shortcut options are available to everyone while remaining controlled by each user's preferences.

AlTab has no paid-access state, activation, trial, checkout, or account integration. The repository is still in the fork-bootstrap stage because signing, notarization, release validation, and a fork-owned update path remain incomplete. Until the remaining items in [FORK.md](FORK.md) are resolved, builds are for development and evaluation only and must not be presented as public AlTab releases.

## Privacy and updates

AlTab does not bundle or initialize Sparkle, has no in-app updater, and cannot download or install an upstream AltTab release. Updates must be obtained and installed manually until a fork-owned update path is designed and validated.

This build does not bundle or initialize AppCenter and does not send crash reports or analytics to AppCenter. No replacement crash-reporting, analytics, or telemetry service has been added. It has no licensing, trial, checkout, or account network path and does not contact upstream services for feature access.

On its first launch, AlTab locally imports compatible user configuration from the official AltTab defaults domain. This is a one-time copy, including after Reset Settings or restoring an AlTab settings backup: existing explicit AlTab choices win, unsupported and identity-specific state is excluded, and AltTab's preferences, license data, and Keychain items remain untouched. Login-item and permission/onboarding state are not transferred because those behaviors belong to the new bundle identity.

## Relationship with upstream

This fork began at AltTab `v11.4.3` (`10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`). The original Git history is retained so authorship and provenance remain visible.

Upstream changes are reviewed periodically, with security, crash, compatibility, and performance fixes prioritized. Changes are integrated selectively; AlTab is not automatically synchronized and may lag behind upstream. See [UPSTREAM.md](UPSTREAM.md) for the last reviewed revision and the integration policy.

## Build from source

Build an optimized app for the current Mac with the supported local command:

```bash
scripts/build_local.sh
```

The command produces a native-architecture `AlTab.app` with an ad-hoc signature, so it needs no Apple Developer account. It validates the bundle and prints its exact path and `open` command without launching, uploading, notarizing, or publishing it. Pass `--universal` to build both `arm64` and `x86_64`. An identity already installed in Keychain, Team ID, or custom bundle ID can be selected with `ALTAB_CODE_SIGN_IDENTITY`, `ALTAB_TEAM_ID`, and `ALTAB_BUNDLE_ID`; ignored `config/local.xcconfig` settings are also supported. See [the contributor build guide](docs/contributing.md) for stable-permission signing and Debug/QA builds.

The routine local build stops with the app in `DerivedData`; it does not create redistribution artifacts. Maintainers can separately invoke the optional packager to create an unsigned Release binary, matching dSYM, exact corresponding source archive, build manifest, release notes, and SHA-256 checksums from an explicit tag or full commit with:

```bash
scripts/package_release.sh <tag-or-commit>
```

The packager builds from a clean `git archive` of that revision, not from ignored or modified local files. See [the release packaging guide](docs/releasing.md) for prerequisites, artifact contents, validation, and rebuilding instructions.

No public binary is currently offered by this fork. If preview binaries are published before Developer ID signing and notarization are available, each release must be labeled clearly as **unsigned and not notarized**. macOS Gatekeeper may block such builds, and users should not be instructed to disable system-wide security protections.

## License and attribution

The application remains available under the [GNU General Public License v3](LICENCE.md). Distributions of modified binaries must satisfy the GPL's source and notice requirements. Copyright and provenance are summarized in [NOTICE.md](NOTICE.md), and third-party acknowledgments and license locations are in [docs/acknowledgments.md](docs/acknowledgments.md).

The AlTab icon used on this page comes from the maintainer's [earlier AlTab codebase](https://github.com/salasebas/altab-archived) and is separate from the upstream AltTab branding. Its provenance and license are recorded in [docs/brand/README.md](docs/brand/README.md).
