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
scripts/build_local.sh
```

## Direction

AlTab preserves AltTab's fast AppKit window-switching experience. Every locally implemented user-facing feature is available to everyone: Search, Search on Release, Auto size, App Icons and Titles, additional shortcuts, and per-shortcut options remain controlled by your preferences only.

There is no paid-access state, activation, trial, checkout, account, license Keychain path, or environment variable that unlocks features. Building from source is the supported way to run AlTab. Public binary signing, notarization, and a fork-owned update feed are tracked separately in [FORK.md](FORK.md) and are not required for local use.

## Run AlTab from source

### Requirements

- A Mac running a recent macOS that can install full **Xcode 26** (Command Line Tools alone are not enough).
- [Xcode 26](https://developer.apple.com/xcode/) from the Mac App Store or Apple Developer downloads.
- Git.
- No Apple Developer account is required for the default build.

If `xcodebuild -version` fails or reports that only Command Line Tools are selected, point the active developer directory at full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

For a single command without changing the system selection:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build_local.sh
```

### Clone and build

```bash
git clone https://github.com/salasebas/altab.git
cd altab
scripts/build_local.sh
```

The script builds an optimized Release `AlTab.app` for the current Mac (native architecture), verifies the bundle, and prints the exact path and launch command. It does not launch, upload, notarize, or publish the app.

Default output path:

```text
DerivedData/Local/Build/Products/Release/AlTab.app
```

Open it with the path printed by the script, for example:

```bash
open DerivedData/Local/Build/Products/Release/AlTab.app
```

Pass `--universal` only when you need both `arm64` and `x86_64` in one binary. Contributors who need the Debug/QA build (`AlTab Dev`) should use the separate path in [docs/contributing.md](docs/contributing.md); that is not the normal user workflow.

### Permissions

On first launch, AlTab opens a permissions window when required:

| Permission | Required? | Purpose |
|---|---|---|
| **Accessibility** | Yes | Focus the window you select after releasing the shortcut. |
| **Screen Recording** | Optional | Show live window thumbnails and previews. |

Grant Accessibility in **System Settings → Privacy & Security → Accessibility**. Without it, AlTab cannot switch windows usefully and will ask again until permission is granted.

Screen Recording is optional. If you skip it, AlTab still runs; thumbnails and previews will not show. You can enable Screen Recording later in **System Settings → Privacy & Security → Screen Recording**, or keep using icon/title-only styles that do not need capture.

After ad-hoc rebuilds, macOS may ask for permissions again because the code signature's designated requirement can change when the executable changes. See [Signing](#signing) for the optional stable local identity.

### Login item

AlTab can start at login through its own preference (**Settings → General → Start at login**). That setting only affects this fork's bundle identity (`dev.salasebas.AlTab` by default). It does not enable or disable official AltTab, and first-launch preference import does not copy login-item or permission state from AltTab.

### Signing

Three supported cases:

1. **Default ad hoc (recommended for a first build).**
   `scripts/build_local.sh` uses an ad-hoc signature. No Apple account, Keychain change, or certificate is required.

2. **Optional stable local self-signed identity.**
   To keep Accessibility and Screen Recording grants stable across rebuilds, install a per-user identity and select it:

   ```bash
   scripts/codesign/setup_local.sh
   ```

   Then create ignored `config/local.xcconfig` (gitignored) with:

   ```text
   CODE_SIGN_IDENTITY = Local Self-Signed
   ```

   Rebuild with `scripts/build_local.sh`. Remove the identity later with `scripts/codesign/remove_local.sh` and delete that `CODE_SIGN_IDENTITY` line to return to ad hoc. Details: [docs/contributing.md](docs/contributing.md).

3. **Advanced: your own Apple / Developer ID identity.**
   If an identity is already installed in your Keychain, select it for one build without editing tracked files:

   ```bash
   ALTAB_CODE_SIGN_IDENTITY="Developer ID Application: Example" \
   ALTAB_TEAM_ID="ABCDEFGHIJ" \
   scripts/build_local.sh
   ```

   You may also set `ALTAB_BUNDLE_ID` or put `CODE_SIGN_IDENTITY`, `DEVELOPMENT_TEAM`, and `PRODUCT_BUNDLE_IDENTIFIER` in ignored `config/local.xcconfig`. A custom bundle ID creates a separate preferences and permissions identity. Never pass passwords, `.p12` files, private keys, or notarization credentials to the build scripts.

### Updates

There is no Sparkle feed and no in-app updater. Update from source:

```bash
cd altab
git fetch origin --tags
git pull                  # or: git checkout altab-vMAJOR.MINOR.PATCH
scripts/build_local.sh
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
| Optional self-signed identity | Keychain entry from `scripts/codesign/setup_local.sh` — remove with `scripts/codesign/remove_local.sh` |

Debug builds use `dev.salasebas.AlTabDev` with the same pattern. AlTab never deletes official AltTab preferences (`com.lwouis.alt-tab-macos`), license suites, or Keychain items.

### Troubleshooting

| Problem | What to try |
|---|---|
| `xcodebuild` says only Command Line Tools are selected | Select full Xcode with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, or prefix the build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. |
| Xcode / SDK too old or missing | Install Xcode 26, open it once to finish setup, accept the license, then retry. |
| Signing identity not found / codesign failed | Unset `ALTAB_CODE_SIGN_IDENTITY` / remove the override from `config/local.xcconfig` for default ad hoc, or install the intended identity first (`scripts/codesign/setup_local.sh` for the local self-signed case). |
| Permissions prompts every rebuild | Expected with ad-hoc signing when the binary changes. Use the optional local self-signed identity for stable grants. After changing identity or bundle ID, re-grant Accessibility (and Screen Recording if you use thumbnails). |
| Stale or confusing build products | Delete local build data and rebuild: `rm -rf DerivedData/Local && scripts/build_local.sh`. |
| Want Debug/QA UI or `AlTab Dev` | That is a contributor path only; see [docs/contributing.md](docs/contributing.md). |

Do not disable Gatekeeper or other system-wide security protections to run a local build.

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
