# Fork identity and release readiness

This file distinguishes current facts from the intended Altab product. Do not make public claims based on the intended state until the corresponding release blockers are complete.

## Lineage

- Upstream project: [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos)
- Fork repository: [salasebas/altab](https://github.com/salasebas/altab)
- Fork point: `v11.4.3`
- Fork commit: `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f`
- License: GPL-3.0
- Relationship: independent fork; no affiliation or endorsement

## Product intention

Altab is intended to provide the functionality present in this codebase without paid feature gates, licensing activation, upgrade prompts, or dependence on the upstream licensing service. This is a roadmap statement, not a description of the current build.

## Relationship with the earlier MIT Altab codebase

MIT-licensed Altab code and artwork may be incorporated into this GPL fork when its copyright and license notice are preserved. The combined application remains GPL-covered. Do not copy GPL-covered implementation from this fork back into the MIT project and present the result as MIT-only.

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
- [x] Keep the fork as `origin`, the official project as read-only `upstream`, and the local branch tracking `origin/master`.
- [x] Establish stable Release and Debug app names and bundle IDs, remove the activation URL scheme, and keep Team ID and signing credentials fork-configurable before the first public release.
- [x] Replace in-app repository, support, funding, About, feedback, and website links.
- [x] Replace the application and menu bar artwork with Altab-owned assets and retain their provenance.

### Updates and external services

- [x] Remove Sparkle until a fork-owned feed, signing key, and tested update path exist; a fork build cannot install an upstream AltTab release.
- [x] Remove the appcast-only license cookie, upstream release notes, and upstream download URLs.
- [ ] Remove or replace the remaining `alt-tab.app` licensing, checkout, and account endpoints.
- [x] Remove upstream Developer ID and Team ID values from release configuration and CI.
- [x] Remove AppCenter/crash-reporting configuration and document that the fork sends no crash reports or analytics to AppCenter.
- [x] Remove the inherited publish workflow and its upstream signing, appcast, AppCenter, and deployment dependencies.
- [ ] Design fork-owned validation and release workflows.

### Free feature surface

- [ ] Inventory every Pro gate and write tests for the intended always-available behavior.
- [ ] Remove activation, keychain license state, remote license calls, trials, conversion scheduling, upgrade prompts, and paid-tier copy without regressing preferences.
- [ ] Preserve user settings when removing the paid-tier state machine.
- [ ] Confirm that no packaged build contacts an upstream licensing or payment service.

### Distribution and compliance

- [ ] Correct all root metadata so it consistently declares the GPL license.
- [ ] Keep corresponding source, build scripts, copyright notices, Git history, and third-party licenses available with every binary distribution.
- [ ] Test a clean install, upgrade, uninstall, Accessibility permissions, Screen Recording permissions, login item behavior, and side-by-side behavior with official AltTab.
- [ ] Either sign and notarize releases with the fork maintainer's stable Developer ID or label every unsigned preview prominently in the README and release notes.
- [ ] Publish checksums and describe exactly how each release artifact was built.

## Suggested public wording

Use wording with this level of precision once public releases exist:

> Altab is an independent GPL-3.0 fork of AltTab for macOS. It is not affiliated with or endorsed by the upstream project. Upstream reliability and security changes are reviewed and selectively ported, but updates are not automatic and this fork may lag behind upstream. The signing and notarization status of each binary is stated in its release notes.
