# Source milestones and optional packaging

AlTab is a **source-first**, **source-only** product at the official distribution layer. The supported way to run it is to follow the [building and troubleshooting guide](building-and-troubleshooting.md): clone this repository, install the once-per-Mac **Local Self-Signed** identity, and build locally with `scripts/build_local.sh`. Public milestones are Git tags plus GitHub release notes that point at source. The maintainer does **not** have to publish an official `.app`, installer, Sparkle feed, signing identity, notarization ticket, or update server. `Local Self-Signed` is never a distributable identity.

The application license is **GPL-3.0-only**. When a binary is redistributed, GPLv3 §6 requires equivalent access to the complete Corresponding Source that matches that binary; attach the packager's matching source archive (not a mutable branch tip) to the same release as the binary.

Optional tools in this repository help **anyone** assemble redistribution artifacts from an exact tag or full commit:

| Path | Command | Signing | Secrets |
| --- | --- | --- | --- |
| Local run | `scripts/build_local.sh` | Local Self-Signed | None (once-per-Mac setup) |
| Unsigned redistribution | `scripts/package_release.sh` | **unsigned** / not notarized | None |
| Notarized redistribution | `scripts/package_notarized_release.sh` | Caller-owned **Developer ID Application** + Apple notarization | Caller-provided only |
| GitHub Actions helper | `.github/workflows/release.yml` | Explicit `unsigned` **or** `notarized` mode | See [secrets checklist](#github-actions-releaseyml) |

The notarized path will **never silently fall back** to unsigned, ad-hoc, or Local Self-Signed output. Choose the mode explicitly. Failures never publish a partial artifact set.

## What “source” means (do not conflate)

| Kind | What it is | Use for |
| --- | --- | --- |
| GitHub automatic “Source code (zip/tar.gz)” | Snapshot GitHub always attaches for a tagged release | Convenience only; **not** the packager’s corresponding-source artifact and **not** what redistributors should treat as the official source attachment |
| `AlTab-<release>-source.tar.gz` | Exact `git archive` from the packager at the packaged revision | **Corresponding Source** that must sit beside any binary ZIP or light `.dmg` |
| GitHub Actions artifact (workflow run) | Temporary upload (default retention ~14 days) from CI packaging | Maintainer inspection; **not** a public distribution channel |
| GitHub Release assets | Files attached to a published or draft Release | The only durable public attachment point; binaries must include matching source + manifest + notes + `SHA256SUMS` |

For a binary Release, the corresponding source is the packager’s `AlTab-…-source.tar.gz` (not GitHub’s automatic Source code archives). We cannot remove those automatic archives; we simply do not treat them as the GPL corresponding-source attachment.

Official source milestones may attach **no** binary assets. When binaries are attached, `scripts/publish_release_artifacts.sh` refuses incomplete sets and audits the remote Release after upload.

## App Sandbox and Mac App Store

`alt_tab_macos.entitlements` keeps:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

This matches the retained upstream policy (App Sandbox has been `false` since the first retained upstream MVP entitlement). AlTab does **not** enable App Sandbox and does **not** support Mac App Store distribution.

Reasons (summary):

- Apple requires App Sandbox for Mac App Store apps, but **not** for direct Developer ID / notarized distribution outside the Store.
- AlTab’s core behavior uses system-wide Accessibility APIs and event taps. Those assistive patterns are incompatible with a naive “turn Sandbox on” change.
- Enabling Sandbox would need a separate feasibility project covering AX, event taps, ScreenCaptureKit, private APIs, login items, entitlements, App Review rules, and functional parity—not a one-line entitlement flip.

Supported binary channels when someone packages a binary:

1. **Unsigned** redistribution (`scripts/package_release.sh`) — must be labeled **unsigned and not notarized**.
2. **Developer ID signed and notarized** redistribution (`scripts/package_notarized_release.sh`) with a distributor-owned identity.

Do **not** claim Mac App Store availability. Do **not** flip `com.apple.security.app-sandbox` to `true` in this tree without that separate feasibility track.

## Source milestone versioning

AlTab public product versions use [Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH`.

| Piece | Form | Example |
| --- | --- | --- |
| Product / bundle version | `MAJOR.MINOR.PATCH` | `1.0.0` |
| Git tag | `altab-vMAJOR.MINOR.PATCH` | `altab-v1.0.0` |
| GitHub release | Same name as the tag; **no** binary assets required | `altab-v1.0.0` |

### Do not match upstream AltTab version numbers

Upstream tags such as `v11.4.3` / `v11.4.4` describe **AltTab**, not AlTab. AlTab starts its own line at **`1.0.0`** for the first public product milestone. Using `11.x` for AlTab would imply parity with that upstream release and confuse users who clone this fork.

Prefer:

- **`1.0.0`** for the first public, usable source milestone (recommended).
- **`0.y.z`** only if you want to advertise “pre-1.0 / may break freely” before any public milestone.
- Never renumber AlTab to track upstream’s major.

### Why the `altab-v` prefix

This repository retains the full upstream AltTab Git history, including tags such as `v1.0.0` … `v11.4.x`. Those tags remain provenance for the fork point and must never be moved or reused. AlTab milestones therefore use the distinct `altab-v*` namespace.

### Version fields in the tree

Before tagging a milestone, set the product version in:

- `config/base.xcconfig` → `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION`
- `package.json` → `version` (tooling metadata only)
- Test-target overrides in `alt-tab-macos.xcodeproj` when they pin a version

`Info.plist` substitutes `$(CURRENT_PROJECT_VERSION)` into both `CFBundleShortVersionString` and `CFBundleVersion`. Preference-schema migrations use a separate constant (`PreferencesMigrations.currentSchemaVersion`) and are not the public app version.

### Changelog and source milestones (git-cliff, intentional cut)

AlTab does **not** ship-on-every-merge like upstream AltTab. Upstream runs continuous semantic-release + binary packaging on `master`; AlTab keeps **source-first, maintainer-cut** milestones.

Tooling (reuse, not a custom bot):

| Piece | Role |
| --- | --- |
| [git-cliff](https://git-cliff.org/) | Parses [Conventional Commits](https://www.conventionalcommits.org/) (commitlint + husky) into changelog sections |
| [cliff.toml](../cliff.toml) | Groups, `altab-v*` tag pattern, templates |
| [scripts/changelog_milestone.sh](../scripts/changelog_milestone.sh) | Thin splice of `## Unreleased` / promote-to-version into [changelog.md](../changelog.md) |
| [`.github/workflows/release-notes.yml`](../.github/workflows/release-notes.yml) | CI entry: Unreleased on push; cut on `workflow_dispatch` |

**Why git-cliff (options considered for issue #93):**

| Option | Fit | Why not / why yes |
| --- | --- | --- |
| Keep semantic-release on every `main` push | Continuous ship | Wrong product model; auto tags/Releases (what #93 removes) |
| semantic-release only on `workflow_dispatch` | Explicit cut | Still release-centric; awkward Unreleased-only path; heavy Node plugin stack |
| [release-please](https://github.com/googleapis/release-please) | release-plz-like PR | Strong, but version is inferred from commits unless overridden; less natural for keep-a-changelog `## Unreleased` |
| **git-cliff + thin script + Actions** | Unreleased on merge, version chosen at cut | **Chosen:** maintained CLI, no greenfield bot, matches desired model with ~one splice script |

#### On merge to `main` (automatic)

On every push to `main` (except commits marked `[skip ci]`), CI:

1. Runs git-cliff for commits since the last `altab-v*` tag
2. Rewrites **only** the `## Unreleased` block in `changelog.md` (markers `<!-- altab-changelog:unreleased-start/end -->`)
3. Commits `chore(changelog): update Unreleased [skip ci]` when the file changed

It deliberately does **not**:

- Bump SemVer / `package.json`
- Create `altab-v*` tags
- Open a GitHub Release
- Rewrite `config/base.xcconfig` marketing version
- Package, sign, notarize, or touch appcast / AppCenter / Sparkle

#### When the maintainer cuts a milestone (explicit)

Version bumps are **chosen by the maintainer**, not inferred from `feat`/`fix` on every merge.

Preferred path: GitHub Actions → **Release notes** → **Run workflow** → enter `MAJOR.MINOR.PATCH` (optional dry-run).

That cut:

1. Promotes `## Unreleased` → `## [X.Y.Z] (date)` and clears Unreleased
2. Aligns `package.json` `version` (tooling metadata only)
3. Commits `chore(release): X.Y.Z [skip ci]`
4. Creates annotated tag `altab-vX.Y.Z` and a **source-only** GitHub Release (notes, no binaries)

Optional **unsigned binary packaging** stays a separate explicit path (`scripts/package_release.sh` / `release.yml` `workflow_dispatch`)—never auto-attached on cut.

Local equivalents (requires [git-cliff](https://git-cliff.org/) on `PATH`, e.g. `brew install git-cliff`):

```bash
# Refresh Unreleased only (no tag / no publish)
scripts/changelog_milestone.sh update

# Dry-run promote in a dirty worktree (inspect diff; do not push)
scripts/changelog_milestone.sh promote 1.0.4
git diff -- changelog.md package.json
# Then either commit/tag/push yourself or discard and use workflow_dispatch
```

The product / Xcode marketing version in `config/base.xcconfig` is still set deliberately when you want the running app’s About box to match a milestone; the cut workflow does not rewrite `.xcconfig`.

### How to cut a source milestone

1. Ensure dependency audits and source/build guards pass on the candidate commit (see [FORK.md](../FORK.md) and `scripts/validate_ci.sh`).
2. Bump `CURRENT_PROJECT_VERSION` / `MARKETING_VERSION` in `config/base.xcconfig` if the app bundle version should match the milestone.
3. Align [README.md](../README.md), [FORK.md](../FORK.md), and [UPSTREAM.md](../UPSTREAM.md) provenance notes as needed (do **not** hand-edit versioned changelog sections the cut owns; Unreleased is fine to tweak before cut).
4. Run **Release notes** → `workflow_dispatch` with the chosen `version` (or promote locally and push tag + `gh release create` with the same contracts).
5. Optionally flesh out the GitHub Release body with wording from [`.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md`](../.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md). Attach **no** binaries unless you intentionally run the optional packaging path below and review the artifacts.
6. Verify the public tag resolves to the intended commit and that a clean clone of the tag builds after `scripts/codesign/setup_local.sh` (once per Mac) and `scripts/build_local.sh`.

Bootstrap (one-time): create and push the first **intentional** public tag so git-cliff has a floor and does not walk the entire upstream history:

```bash
# Point at the commit you actually want as the public 1.0.0 floor.
git tag -a altab-v1.0.0 <full-commit-sha> -m "AlTab source milestone 1.0.0"
git push origin altab-v1.0.0
```

If automation previously created empty accidental tags/releases (no binary assets), delete those GitHub Releases and tags before advertising the next intentional SemVer. Do not leave a higher public SemVer than the latest intentional milestone.

### How users update after a milestone

There is no in-app updater. From an existing clone:

```bash
git fetch origin --tags
git checkout altab-vMAJOR.MINOR.PATCH   # or: git pull on main
scripts/build_local.sh                 # setup_local.sh only if this Mac never installed Local Self-Signed
open DerivedData/Local/Build/Products/Release/AlTab.app
```

Or stay on `main` and rebuild after `git pull`. Preferences for the same bundle ID are preserved by macOS.

### Claims that source milestones must not make

- Affiliation or endorsement by the upstream AltTab project
- Automatic security updates or parity with official AltTab
- A Sparkle (or other) hosted update feed
- Analytics, crash reporting, or licensing services
- Use of upstream signing identities, Team IDs, or release infrastructure

## Optional unsigned redistribution packaging

This section is an **optional** downstream tool for people who assemble their own unsigned redistribution artifacts. It is **not** AlTab's normal local build.

Routine local use builds an optimized app with `scripts/build_local.sh` under the tracked **Local Self-Signed** identity (setup once per Mac). Development and QA use `scripts/run_debug.sh`. Neither path packages or publishes anything. Normal pull-request CI validates source, tests, and credential-free Debug/Release compilation; it never needs a user Keychain identity and does not invoke the packager.

Redistribution artifacts are assembled from an explicit Git tag or full 40-character commit. The packager exports that revision with `git archive`, builds inside the exported tree at a stable commit-derived path, normalizes package ordering and timestamps, and places that exact source beside the binary. Ignored local configuration such as `config/local.xcconfig`, Keychain identities, and maintainer secrets cannot enter the build.

### Prerequisites

- macOS with Xcode 26 and its command-line tools selected
- Git, `zip`, `gzip`, `hdiutil`, `shasum`, and the standard macOS developer tools
- A revision that already contains the packaging and validation scripts

When maintaining the packaging tool, run its focused preflight explicitly:

```bash
scripts/check_release_packaging.sh
scripts/check_notarized_release.sh
```

To assemble **unsigned** artifacts from this repository, run:

```bash
scripts/package_release.sh <tag-or-commit>
```

An optional second argument selects the output directory. A tag must be named exactly; a commit must be its full SHA. Branches, abbreviated SHAs, unsafe artifact names, gitlinks, and an existing destination are rejected.

Tags named `altab-vN.N.N` (preferred) or `vN` / `vN.N` / `vN.N.N` set the app bundle version to the numeric portion. Untagged commit previews use bundle version `0`; their exact identity remains the full commit in the manifest.

### Artifact basename label (`release_artifact_label`)

Published basenames use a short **artifact label**, not the raw Git tag string:

| Git tag / revision | Artifact label | Example basename |
| --- | --- | --- |
| `altab-v1.0.0` | `1.0.0` | `AlTab-1.0.0-macOS-unsigned.dmg` |
| Other tags | full tag string | `AlTab-<tag>-…` |
| Untagged full commit | 12-char short SHA | `AlTab-<shortsha>-…` |

The helper is `release_artifact_label` in `scripts/release_artifact_contracts.sh`. The Git tag namespace stays `altab-v*`; only package basenames drop the doubled `altab-v` prefix. Historical Releases that already shipped `AlTab-altab-v…` names are left alone.

### Unsigned artifacts

The command creates `dist/AlTab-<release>/` containing (human-facing priority order):

1. `AlTab-<release>-macOS-unsigned.dmg`: **light casual download** — only `AlTab.app` plus a drag-to-Applications symlink (no dSYM, no notices). Prefer this for end users who just want to run the app. Example: `AlTab-1.0.0-macOS-unsigned.dmg`.
2. `AlTab-<release>-macOS-unsigned.zip`: full redistribution package — `AlTab.app`, matching `AlTab.app.dSYM`, GPL and third-party notices, source instructions, release notes, and the build manifest
3. `AlTab-<release>-source.tar.gz`: the exact tracked source revision, including all build and packaging scripts (not GitHub’s automatic Source code archives)
4. `SHA256SUMS`: SHA-256 checksums for every other published artifact
5. Secondary / provenance: `AlTab-<release>-BUILD-MANIFEST.md` (toolchain, build command, signing status) and `AlTab-<release>-RELEASE-NOTES.md` (rendered from the repository template; used as the GitHub Release body and copied into the full ZIP — **not** a primary standalone download)

**Decision (issue #91):** keep generating and attaching `RELEASE-NOTES.md` so publish/verify contracts stay coherent and the full ZIP still contains notes, but de-emphasize it in Download tables and README copy.

Anyone who redistributes those artifacts must label them **unsigned and not notarized** and must not tell users to disable system-wide security protections. The light `.dmg` never replaces the GPL corresponding-source set: when a binary is published, the full ZIP, packager source tarball, manifest, notes, and `SHA256SUMS` remain required on the same Release.

The script verifies arm64 and x86_64 slices, matching app/dSYM UUIDs, absence of a Developer ID authority and Team ID, complete checksums and notices, source-archive identity, light-DMG layout (app + Applications link, no dSYM, same app binary as the ZIP), and both service-isolation and unrestricted-feature guards after extracting the final ZIP. Xcode may emit a non-identifying Mach-O signature even when code signing is disabled; the verifier accepts only that state or a fully unsigned bundle. It rejects known upstream signing identities, update or licensing endpoints, analytics credentials, and release-secret markers.

## Bring-your-own Developer ID (notarized) packaging

Use this path when **you** enroll in the Apple Developer Program and want Gatekeeper-friendly redistribution. The repository never ships a Developer ID certificate, private key, Team ID, App Store Connect API key, or notary password. You supply them at packaging time; the scripts only automate build, sign, notarize, staple, verify, and package.

### What you must obtain from Apple

1. Membership in the [Apple Developer Program](https://developer.apple.com/programs/).
2. A **Developer ID Application** certificate (not Apple Development, not Mac App Distribution).
3. Export of that identity as a `.p12` **only on machines you control** (for CI import) **or** installation into your login Keychain (for local packaging).
4. An [App Store Connect API key](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api) with access to Notarization, **or** a local `notarytool` Keychain profile.
5. A **stable** reverse-DNS bundle identifier you own. Changing it later resets macOS permissions, preferences continuity, and login-item identity for end users. After the first public binary, keep Team ID, Developer ID, and bundle ID stable.

### What the repository automates

- Exact-revision export (`git archive`) and universal `arm64` + `x86_64` Release build with Hardened Runtime
- Signing with the **explicit** Developer ID Application identity you pass
- Submission through `xcrun notarytool`, wait for a terminal result, staple, and Gatekeeper validation
- Fork isolation, unrestricted-feature, symbol-asset, architecture, dSYM, and signature checks
- GPL-complete artifact set (binary ZIP, dSYM, exact source archive, manifest, notes, checksums)

### What it deliberately refuses

- Silent fallback to unsigned / Local Self-Signed / a different identity
- Upstream Team ID `QXD7GW8FHY`, upstream bundle IDs (`com.lwouis.*`), or upstream identity names
- Ambiguous or missing codesigning identities
- Passwords as command-line flags (use a Keychain profile or API key file)
- Publishing anything on failure (the output directory is created only after full verification)

### List and select the identity safely

```bash
security find-identity -v -p codesigning
```

Copy the **exact** `Developer ID Application: …` line you intend to use. Pass it as `--identity` or `ALTAB_DEVELOPER_ID_IDENTITY`. If two lines match the same string, the packager aborts (ambiguous identity).

### Create notarization credentials without committing them

**Local (Keychain profile, preferred on a personal Mac):**

```bash
xcrun notarytool store-credentials "AlTabNotary" \
  --apple-id "you@example.com" \
  --team-id "ABCD123456" \
  --password "<app-specific-password>"
```

Then pass `--notary-profile AlTabNotary` (or `ALTAB_NOTARY_KEYCHAIN_PROFILE`). The password is not written into the repository and must not appear in shell history if you can avoid it (prefer interactive prompts).

**CI / headless (App Store Connect API key):**

1. Create an API key in App Store Connect and download `AuthKey_<KEYID>.p8` once.
2. Keep the `.p8`, Key ID, and Issuer ID outside git.
3. Pass `--notary-key /path/to/AuthKey_<KEYID>.p8 --notary-key-id <KEYID> --notary-issuer <ISSUER-UUID>`.

### Local command

```bash
scripts/package_notarized_release.sh altab-vMAJOR.MINOR.PATCH \
  --identity "Developer ID Application: Your Name (ABCD123456)" \
  --team-id ABCD123456 \
  --bundle-id dev.example.AlTab \
  --notary-profile AlTabNotary
```

Equivalent environment variables: `ALTAB_DEVELOPER_ID_IDENTITY`, `ALTAB_TEAM_ID`, `ALTAB_BUNDLE_ID`, `ALTAB_NOTARY_KEYCHAIN_PROFILE`, or the API-key trio `ALTAB_NOTARY_API_KEY_PATH` / `ALTAB_NOTARY_API_KEY_ID` / `ALTAB_NOTARY_API_ISSUER_ID`.

The notarized path requires `--bundle-id` or `ALTAB_BUNDLE_ID` explicitly. It never reads a default from the invoking checkout, so a local configuration change cannot alter an exact-revision package.

Optional `--output-directory` selects the output root (default `dist/`). Output lands in `dist/AlTab-<release>-notarized/` with the same artifact-label rules as the unsigned packager (`altab-v1.0.0` → basenames under `AlTab-1.0.0-…`):

1. `AlTab-<release>-macOS.zip` (signed, notarized, stapled app + dSYM + notices)
2. `AlTab-<release>-source.tar.gz` (packager corresponding source; not GitHub’s automatic Source code archives)
3. `SHA256SUMS`
4. Secondary: `AlTab-<release>-BUILD-MANIFEST.md` (includes public identity metadata, toolchain, and an **unsigned rebuild command**) and `AlTab-<release>-RELEASE-NOTES.md` (Release body + packaged notes; not a primary download)

### Failure recovery and notarization diagnostics

| Failure | What happens | What you should do |
| --- | --- | --- |
| Missing/ambiguous identity | Packager exits before build | Fix Keychain / pass the exact identity string |
| Wrong Team ID on the signed app | Packager exits before notarization | Re-export the certificate for the intended team |
| `notarytool` network / auth error | No artifact directory is published | Check API key or profile; re-run |
| Apple status `Invalid` / `Rejected` | Diagnostics are printed only when safe; secrets stay redacted | Run `xcrun notarytool log <submission-id> --keychain-profile AlTabNotary` (or API key flags) locally to fetch the full Apple log |
| Staple / `spctl` failure | Packager exits; no final ZIP | Confirm notarization Accepted, retry staple, do not ship the unstapled app as “notarized” |
| Any mid-flight failure | Work directory under `/tmp` is removed; destination is not created | Re-run after fixing the cause; never hand-edit a partial package and relabel it |

The packager never marks an incomplete build as notarized. Contract tests in `scripts/check_notarized_release.sh` cover success, missing/ambiguous/partial identity, wrong Team ID, rejected notarization, entitlement and Hardened Runtime mismatches, rejected Gatekeeper assessment, missing ticket, release-target conflicts, and secret-redaction behavior with mocked tools (no Apple credentials required).

### Bundle ID and signing stability

After the first public binary release for a given product identity:

- Keep the **same** Developer ID Application certificate lineage and Team ID when possible.
- Keep the **same** bundle identifier.
- Plan and test a migration before any rotation; users will otherwise re-grant Accessibility / Screen Recording and lose login-item continuity.

Do **not** ship with upstream identity values. Do **not** reuse upstream update feeds or licensing endpoints.

### GPL corresponding-source obligations

Every distributed binary ZIP must remain accompanied by the exact corresponding source archive produced beside it, plus GPL and third-party notices. The packager enforces that layout. If you host binaries elsewhere, host the matching source archive and checksums with them. Do not point users only at mutable `main` for Corresponding Source of a published binary.

### Publishing binaries to a GitHub Release

`scripts/publish_release_artifacts.sh` uploads a verified local artifact directory to a GitHub Release (create or attach). After upload it **audits the remote Release** and fails unless every published binary has the matching source archive, build manifest, release notes, and `SHA256SUMS` (same basenames the packager emitted).

Repeat-publication policy:

- If the Release already has an asset with the same name, publication **fails** by default.
- Replacing existing assets is allowed only with an explicit `ALTAB_RELEASE_REPLACE_ASSETS=1` environment variable (uses `gh release upload --clobber`). Do not leave duplicate-asset behavior implicit.
- Source-only milestones (notes, no binaries) remain valid and do not require the binary set.

## GitHub Actions (`release.yml`)

`.github/workflows/release.yml` is a **manual** (`workflow_dispatch`) packaging helper. It is intentionally **not** triggered by tag push.

### Why manual (not tag-triggered publish)

| Approach | Pros | Cons |
| --- | --- | --- |
| **Manual `workflow_dispatch` (recommended default)** | Human chooses revision + mode after CI is green; failed notarization never opens a public release; draft release stays private until reviewed | One extra click |
| Tag push → auto-publish | Faster | A broken secret, flaky notarization, or bad tag can publish a partial or mislabeled release that is hard to unsend |

Recommendation: cut the `altab-v*` tag after audit → run **Release packaging** with `create_github_release=true` and `release_draft=true` → download/inspect artifacts → publish the draft only when satisfied. Official source milestones can still omit binaries entirely.

### Modes

- `distribution_mode=unsigned` → `scripts/package_release.sh` (no secrets).
- `distribution_mode=notarized` → imports your Developer ID `.p12` into a temporary keychain, materializes the App Store Connect API key, runs `scripts/package_notarized_release.sh`, then deletes the keychain/key material. **Missing secrets fail the job**; the workflow does not fall back to unsigned.

Artifacts always upload to the workflow run. Creating a GitHub Release is optional and defaults to **draft**.

### Secrets checklist

Configure under **Settings → Secrets and variables → Actions**, preferably in a protected Environment named `release` with required reviewers:

| Secret | Required for | Purpose |
| --- | --- | --- |
| `ALTAB_DEVELOPER_ID_CERTIFICATE_P12_BASE64` | notarized | `base64` of the Developer ID Application `.p12` |
| `ALTAB_DEVELOPER_ID_CERTIFICATE_PASSWORD` | notarized | Password of that `.p12` |
| `ALTAB_DEVELOPER_ID_IDENTITY` | notarized | Exact `Developer ID Application: …` string |
| `ALTAB_TEAM_ID` | notarized | 10-character Team ID |
| `ALTAB_BUNDLE_ID` | notarized | Stable distributor-owned bundle ID; required explicitly for every notarized package |
| `ALTAB_NOTARY_API_KEY_P8_BASE64` | notarized | `base64` of `AuthKey_<KEYID>.p8` |
| `ALTAB_NOTARY_API_KEY_ID` | notarized | App Store Connect key ID |
| `ALTAB_NOTARY_API_ISSUER_ID` | notarized | App Store Connect issuer UUID |
| `ALTAB_RELEASE_GITHUB_TOKEN` | optional | Override `GITHUB_TOKEN` only if draft release creation needs broader access |

Encode files on a trusted machine:

```bash
base64 -i DeveloperID.p12 | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Never commit those files, paste them into issues, or log them in CI.

### Inputs

| Input | Meaning |
| --- | --- |
| `revision` | Exact tag or full 40-character commit |
| `distribution_mode` | `unsigned` or `notarized` |
| `create_github_release` | Attach artifacts to a GitHub Release after success |
| `release_draft` | Keep that release as a draft (default `true`) |
| `environment_name` | GitHub Environment that holds secrets (default `release`) |

### Local rebuild of packaged artifacts

Extract the corresponding source archive, select the Xcode version recorded in the manifest, and run the exact `xcodebuild` command recorded there (unsigned rebuild command for notarized packages, or the primary build command for unsigned packages). The audited PDF symbol assets are tracked build inputs and are not regenerated during packaging.

Verify downloaded checksums before using the artifacts:

```bash
shasum -a 256 --check SHA256SUMS
```

The complete verifier checks the exact checksum set, extracts and inspects the supplied source archive, runs the guards from that archived revision, and validates the packaged app without consulting another checkout:

```bash
scripts/verify_release_artifacts.sh <artifact-directory> <full-commit> <label> [unsigned|notarized]
```

The verifier executes guard scripts from the supplied source archive. Only run it after obtaining the expected full commit and checksums through a channel you trust; the colocated checksum file establishes consistency, not artifact authenticity. For notarized packages it also checks Developer ID authority, Team ID, Hardened Runtime, Gatekeeper acceptance, and stapler ticket validation.
