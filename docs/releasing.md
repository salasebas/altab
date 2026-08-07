# Source milestones and optional packaging

AlTab is a **source-first**, **source-only** product at the official distribution layer. The supported way to run it is to clone this repository, install the once-per-Mac **Local Self-Signed** identity (`scripts/codesign/setup_local.sh`), and build locally with `scripts/build_local.sh`. Public milestones are Git tags plus GitHub release notes that point at source. The maintainer does **not** publish an official `.app`, installer, Sparkle feed, signing identity, notarization ticket, or update server. `Local Self-Signed` is never a distributable identity; optional redistribution packaging remains explicitly unsigned (see below).

## Source milestone versioning

AlTab public product versions use [Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH`.

| Piece | Form | Example |
| --- | --- | --- |
| Product / bundle version | `MAJOR.MINOR.PATCH` | `1.0.0` |
| Git tag | `altab-vMAJOR.MINOR.PATCH` | `altab-v1.0.0` |
| GitHub release | Same name as the tag; **no** binary assets | `altab-v1.0.0` |

### Why the `altab-v` prefix

This repository retains the full upstream AltTab Git history, including tags such as `v1.0.0` … `v11.4.x`. Those tags remain provenance for the fork point and must never be moved or reused. AlTab milestones therefore use the distinct `altab-v*` namespace.

### Version fields in the tree

Before tagging a milestone, set the product version in:

- `config/base.xcconfig` → `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION`
- `package.json` → `version` (tooling metadata only)
- Test-target overrides in `alt-tab-macos.xcodeproj` when they pin a version

`Info.plist` substitutes `$(CURRENT_PROJECT_VERSION)` into both `CFBundleShortVersionString` and `CFBundleVersion`. Preference-schema migrations use a separate constant (`PreferencesMigrations.currentSchemaVersion`) and are not the public app version.

### How to cut a source milestone

1. Ensure dependency audits and source/build guards pass on the candidate commit (see [FORK.md](../FORK.md) and `scripts/validate_ci.sh`).
2. Bump the version fields above so they match the intended SemVer.
3. Update [changelog.md](../changelog.md), [README.md](../README.md), [FORK.md](../FORK.md), and [UPSTREAM.md](../UPSTREAM.md) so they agree.
4. Merge to `main` and re-run CI / local guards on that revision.
5. Create an annotated tag on the exact audited/merged commit:

   ```bash
   git tag -a altab-vMAJOR.MINOR.PATCH -m "AlTab source milestone MAJOR.MINOR.PATCH"
   git push origin altab-vMAJOR.MINOR.PATCH
   ```

6. Publish a GitHub release from that tag with notes derived from [`.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md`](../.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md). Attach **no** binaries, DMGs, PKGs, dSYMs, appcasts, or signatures.
7. Verify the public tag resolves to the intended commit and that a clean clone of the tag builds after `scripts/codesign/setup_local.sh` (once per Mac) and `scripts/build_local.sh`.

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
- Official compiled binary downloads from this repository
- A Sparkle (or other) hosted update feed
- Analytics, crash reporting, or licensing services

## Optional redistribution packaging

This section is an **optional** downstream tool for people who assemble their own unsigned redistribution artifacts. It is **not** AlTab's normal local build and is **not** how official milestones are published.

Routine local use builds an optimized app with `scripts/build_local.sh` under the tracked **Local Self-Signed** identity (setup once per Mac). Development and QA use `ai/build.sh` with the same identity. Both leave products in `DerivedData` and neither packages or publishes anything. Normal pull-request CI validates source, tests, and Debug/Release compilation with **explicit ad-hoc Debug and unsigned Release** (`scripts/build_app.sh`) and never needs a user Keychain identity; it does not invoke the packager.

Redistribution artifacts are assembled from an explicit Git tag or full 40-character commit. The packager exports that revision with `git archive`, builds inside the exported tree at a stable commit-derived path, normalizes package ordering and timestamps, and places that exact source beside the binary. Ignored local configuration such as `config/local.xcconfig`, Keychain identities, and maintainer secrets cannot enter the build.

### Prerequisites

- macOS with Xcode 26 and its command-line tools selected
- Git, `zip`, `gzip`, `shasum`, and the standard macOS developer tools
- A revision that already contains the packaging and validation scripts

When maintaining the packaging tool, run its focused preflight explicitly:

```bash
scripts/check_release_packaging.sh
```

To assemble artifacts from this repository, run:

```bash
scripts/package_release.sh <tag-or-commit>
```

An optional second argument selects the output directory. A tag must be named exactly; a commit must be its full SHA. Branches, abbreviated SHAs, unsafe artifact names, gitlinks, and an existing destination are rejected.

Tags named `altab-vN.N.N` (preferred) or `vN` / `vN.N` / `vN.N.N` set the app bundle version to the numeric portion. Untagged commit previews use bundle version `0`; their exact identity remains the full commit in the manifest.

### Artifacts

The command creates `dist/AlTab-<release>/` containing:

- `AlTab-<release>-macOS-unsigned.zip`: `AlTab.app`, its matching `AlTab.app.dSYM`, GPL and third-party notices, source instructions, release notes, and the build manifest
- `AlTab-<release>-source.tar.gz`: the exact tracked source revision, including all build and packaging scripts
- `AlTab-<release>-BUILD-MANIFEST.md`: commit, tag, toolchain, SDK, architectures, exact build command, bundle metadata, and signing/notarization status
- `AlTab-<release>-RELEASE-NOTES.md`: rendered from the repository template
- `SHA256SUMS`: SHA-256 checksums for every other published artifact

The current packager intentionally produces an **unsigned and not notarized** universal Release build. Signing and notarization require a separately designed fork-owned identity and workflow. No repository workflow invokes this packager, receives release secrets, or publishes its output. Anyone who redistributes those artifacts must label them **unsigned and not notarized** and must not tell users to disable system-wide security protections.

The script verifies arm64 and x86_64 slices, matching app/dSYM UUIDs, absence of a Developer ID authority and Team ID, complete checksums and notices, source-archive identity, and both service-isolation and unrestricted-feature guards after extracting the final ZIP. Xcode may emit a non-identifying ad hoc Mach-O signature even when code signing is disabled; the verifier accepts only that state or a fully unsigned bundle. It rejects known upstream signing identities, update or licensing endpoints, analytics credentials, and release-secret markers.

### Rebuilding packaged artifacts

Extract the corresponding source archive, select the Xcode version recorded in the manifest, and run the exact `xcodebuild` command recorded there. The command uses the Release scheme with code signing disabled and `ARCHS='arm64 x86_64'`. The audited PDF symbol assets are tracked build inputs and are not regenerated during packaging.

Verify downloaded checksums before using the artifacts:

```bash
shasum -a 256 --check SHA256SUMS
```

The complete verifier checks the exact checksum set, extracts and inspects the supplied source archive, runs the guards from that archived revision, and validates the packaged app without consulting another checkout:

```bash
scripts/verify_release_artifacts.sh <artifact-directory> <full-commit> <label>
```

The verifier executes guard scripts from the supplied source archive. Only run it after obtaining the expected full commit and checksums through a channel you trust; the colocated checksum file establishes consistency, not artifact authenticity.
