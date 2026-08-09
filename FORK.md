# Fork identity and release readiness

This file distinguishes current facts from the intended AlTab product. Do not make public claims based on the intended state until the corresponding release blockers are complete.

## Lineage

- Upstream project: [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos)
- Fork repository: [salasebas/altab](https://github.com/salasebas/altab)
- Fork point: `v11.4.3`
- Fork commit: `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`
- Last reviewed upstream: `v11.4.4` / `081f3ee4014e03557c2ab39e9e168dac308fa49b` (selective product integration complete; see [UPSTREAM.md](UPSTREAM.md))
- License: GPL-3.0-only
- Relationship: independent fork; no affiliation or endorsement
- First source milestone tag: `altab-v1.0.0` (product version `1.0.0`); latest published source-only GitHub Release follows `altab-v*` tags (see [docs/releasing.md](docs/releasing.md))
- App Sandbox: disabled (`com.apple.security.app-sandbox` = `false`), same retained policy as upstream; Mac App Store distribution is not supported

## Product model

AlTab provides the locally implemented functionality in this codebase to every user. Feature behavior remains preference-driven, but availability never depends on a license, trial, account, purchase, elapsed time, network response, or environment variable. There is no activation flow, paid-access state, upgrade prompt, checkout integration, or upstream licensing dependency.

The supported way to run AlTab is to clone the repository and build locally with `scripts/build_local.sh`. Official milestones are source-only Git tags (`altab-v*`) plus release notes—no compiled application is published. There is no Sparkle updater; updates are `git fetch`/`git pull` (or checkout a milestone tag), rebuild, and relaunch. The concise product overview lives in [README.md](README.md); requirements, permissions, local signing, and troubleshooting live in the illustrated [building guide](docs/building-and-troubleshooting.md); optional redistribution packaging lives in [docs/releasing.md](docs/releasing.md).

## Relationship with the earlier MIT AlTab codebase

MIT-licensed AlTab code and artwork may be incorporated into this GPL fork when its copyright and license notice are preserved. The combined application remains GPL-3.0-only. Do not copy GPL-covered implementation from this fork back into the MIT project and present the result as MIT-only.

Upstream AltTab has a historical metadata discrepancy: its root `LICENCE.md` / `Info.plist` say GPLv3 while upstream `package.json` has said MIT. That upstream `package.json` line is **provenance only** and is **not an MIT grant** for this application. AlTab keeps its own canonical declaration at **GPL-3.0-only**.

## Upstream integration policy

Keep the upstream repository as a read-only remote named `upstream`. Fetch it explicitly, review the range since the revision recorded in [UPSTREAM.md](UPSTREAM.md), and integrate only understood changes.

- Cherry-pick clean, self-contained fixes when preserving the original commit is useful.
- Port changes manually when an upstream commit mixes product, licensing, branding, and technical behavior.
- Do not merge `upstream/master` wholesale by default.
- Preserve original authorship and license notices.
- Run relevant tests and the build after every integration batch.
- Update `UPSTREAM.md` even when reviewed changes are intentionally skipped.

Security-related upstream work receives priority, but there is no promise of immediate parity. Never describe the fork as receiving upstream security updates automatically.

## Public release blockers

### Repository and identity

- [x] Use [salasebas/altab](https://github.com/salasebas/altab) as the canonical fork and retain the earlier implementation as [salasebas/altab-archived](https://github.com/salasebas/altab-archived).
- [x] Keep the fork as `origin`, the official project as read-only `upstream`, and the local branch tracking `origin/main`.
- [x] Establish stable Release and Debug app names and bundle IDs, remove the activation URL scheme, and keep Team ID and signing credentials fork-configurable before the first public release.
- [x] Replace in-app repository, support, funding, About, feedback, and website links.
- [x] Replace the application and menu bar artwork with AlTab-owned assets and retain their provenance.

### Updates and external services

- [x] Remove Sparkle until a fork-owned feed, signing key, and tested update path exist; a fork build cannot install an upstream AltTab release.
- [x] Remove the appcast-only license cookie, upstream release notes, and upstream download URLs.
- [x] Remove the remaining `alt-tab.app` licensing, checkout, and account endpoints without adding a replacement service.
- [x] Remove upstream Developer ID and Team ID values from release configuration and CI.
- [x] Remove AppCenter/crash-reporting configuration and document that the fork sends no crash reports or analytics to AppCenter.
- [x] Remove the inherited publish workflow and its upstream signing, appcast, AppCenter, and deployment dependencies.
- [x] Design fork-owned validation and release workflows.

### Free feature surface

- [x] Inventory every formerly paid feature path and pin its unrestricted behavior in specs and tests.
- [x] Remove activation, license Keychain state, remote license calls, trials, conversion scheduling, upgrade prompts, and paid-tier copy without regressing feature implementations.
- [x] Preserve existing AlTab user settings while removing the paid-access state machine and its forced fallback behavior.
- [x] Import compatible AltTab preferences once into missing AlTab keys while preserving existing AlTab choices and leaving AltTab defaults, license data, and Keychain items untouched.
- [x] Guard source and packaged builds against upstream licensing/payment services, paid-access decisions, and upsell UI.

### Distribution and compliance

- [x] Correct all root metadata so it consistently declares **GPL-3.0-only** (not ambiguous bare GPL-3.0, not the SPDX “or later” form, not MIT for the app).
- [x] Keep corresponding source, build scripts, copyright notices, Git history, and third-party licenses available with every binary distribution.
- [x] Document the source-first clone, local Release build, permissions, signing choices, and `git pull` update path in the README and canonical building guide (no official binary distribution required for local use).
- [x] Test a clean install, upgrade, uninstall, Accessibility permissions, Screen Recording permissions, login item behavior, and side-by-side behavior with official AltTab.
- [x] Either sign and notarize releases with the fork maintainer's stable Developer ID or label every unsigned preview prominently in the README and release notes. **Source-only path remains valid for official milestones.** Local interactive builds use once-per-Mac **Local Self-Signed** (not a distributable identity); validation CI remains credential-free. Optional redistribution packaging supports explicit **unsigned** (`scripts/package_release.sh`) and bring-your-own **Developer ID + notarization** (`scripts/package_notarized_release.sh`, manual `.github/workflows/release.yml`) paths. The notarized path never silently falls back to unsigned. Any unsigned binary redistribution must be labeled **unsigned and not notarized**.
- [x] Publish checksums and describe exactly how each release artifact was built. Both packagers emit `SHA256SUMS` when used; official milestones may still attach no binaries.
- [x] Document App Sandbox as disabled (upstream-retained) and state that Mac App Store distribution is not supported; do not flip `com.apple.security.app-sandbox` to `true` without a separate feasibility project.
- [x] Distinguish GitHub auto source snapshots, packager source tarballs, Actions artifacts, and GitHub Release assets; require a post-upload audit when binaries are published.

## Suggested public wording

Use wording with this level of precision for source milestones:

> AlTab is an independent GPL-3.0-only fork of AltTab for macOS. It is not affiliated with or endorsed by the upstream project. Upstream reliability and security changes are reviewed and selectively ported, but updates are not automatic and this fork may lag behind upstream. Official milestones are source-only: clone the tagged revision and build locally with Local Self-Signed. There is no official compiled binary, Sparkle feed, automatic security update channel, or Mac App Store listing.
