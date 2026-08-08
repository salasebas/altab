# Source milestones and optional packaging

AlTab is a **source-first**, **source-only** product at the official distribution layer. The supported way to run it is to follow the [building and troubleshooting guide](building-and-troubleshooting.md): clone this repository, install the once-per-Mac **Local Self-Signed** identity, and build locally with `scripts/build_local.sh`. Public milestones are Git tags plus GitHub release notes that point at source. The maintainer does **not** have to publish an official `.app`, installer, Sparkle feed, signing identity, notarization ticket, or update server. `Local Self-Signed` is never a distributable identity.

Optional tools in this repository help **anyone** assemble redistribution artifacts from an exact tag or full commit:

| Path | Command | Signing | Secrets |
| --- | --- | --- | --- |
| Local run | `scripts/build_local.sh` | Local Self-Signed | None (once-per-Mac setup) |
| Unsigned redistribution | `scripts/package_release.sh` | **unsigned** / not notarized | None |
| Notarized redistribution | `scripts/package_notarized_release.sh` | Caller-owned **Developer ID Application** + Apple notarization | Caller-provided only |
| GitHub Actions helper | `.github/workflows/release.yml` | Explicit `unsigned` **or** `notarized` mode | See [secrets checklist](#github-actions-releaseyml) |

The notarized path will **never silently fall back** to unsigned, ad-hoc, or Local Self-Signed output. Choose the mode explicitly. Failures never publish a partial artifact set.

## Source milestone versioning

AlTab public product versions use [Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH`.

| Piece | Form | Example |
| --- | --- | --- |
| Product / bundle version | `MAJOR.MINOR.PATCH` | `1.0.0` |
| Git tag | `altab-vMAJOR.MINOR.PATCH` | `altab-v1.0.0` |
| GitHub release | Same name as the tag; **no** binary assets required | `altab-v1.0.0` |

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

6. Publish a GitHub release from that tag with notes derived from [`.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md`](../.github/SOURCE_MILESTONE_NOTES_TEMPLATE.md). Attach **no** binaries unless you intentionally run the optional packaging path below and review the artifacts.
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
- A Sparkle (or other) hosted update feed
- Analytics, crash reporting, or licensing services
- Use of upstream signing identities, Team IDs, or release infrastructure

## Optional unsigned redistribution packaging

This section is an **optional** downstream tool for people who assemble their own unsigned redistribution artifacts. It is **not** AlTab's normal local build.

Routine local use builds an optimized app with `scripts/build_local.sh` under the tracked **Local Self-Signed** identity (setup once per Mac). Development and QA use `scripts/run_debug.sh`. Neither path packages or publishes anything. Normal pull-request CI validates source, tests, and credential-free Debug/Release compilation; it never needs a user Keychain identity and does not invoke the packager.

Redistribution artifacts are assembled from an explicit Git tag or full 40-character commit. The packager exports that revision with `git archive`, builds inside the exported tree at a stable commit-derived path, normalizes package ordering and timestamps, and places that exact source beside the binary. Ignored local configuration such as `config/local.xcconfig`, Keychain identities, and maintainer secrets cannot enter the build.

### Prerequisites

- macOS with Xcode 26 and its command-line tools selected
- Git, `zip`, `gzip`, `shasum`, and the standard macOS developer tools
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

### Unsigned artifacts

The command creates `dist/AlTab-<release>/` containing:

- `AlTab-<release>-macOS-unsigned.zip`: `AlTab.app`, its matching `AlTab.app.dSYM`, GPL and third-party notices, source instructions, release notes, and the build manifest
- `AlTab-<release>-source.tar.gz`: the exact tracked source revision, including all build and packaging scripts
- `AlTab-<release>-BUILD-MANIFEST.md`: commit, tag, toolchain, SDK, architectures, exact build command, bundle metadata, and signing/notarization status
- `AlTab-<release>-RELEASE-NOTES.md`: rendered from the repository template
- `SHA256SUMS`: SHA-256 checksums for every other published artifact

Anyone who redistributes those artifacts must label them **unsigned and not notarized** and must not tell users to disable system-wide security protections.

The script verifies arm64 and x86_64 slices, matching app/dSYM UUIDs, absence of a Developer ID authority and Team ID, complete checksums and notices, source-archive identity, and both service-isolation and unrestricted-feature guards after extracting the final ZIP. Xcode may emit a non-identifying Mach-O signature even when code signing is disabled; the verifier accepts only that state or a fully unsigned bundle. It rejects known upstream signing identities, update or licensing endpoints, analytics credentials, and release-secret markers.

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

Optional `--output-directory` selects the output root (default `dist/`). Output lands in `dist/AlTab-<release>-notarized/` with:

- `AlTab-<release>-macOS.zip` (signed, notarized, stapled app + dSYM + notices)
- `AlTab-<release>-source.tar.gz`
- `AlTab-<release>-BUILD-MANIFEST.md` (includes public identity metadata, toolchain, and an **unsigned rebuild command**)
- `AlTab-<release>-RELEASE-NOTES.md`
- `SHA256SUMS`

### Failure recovery and notarization diagnostics

| Failure | What happens | What you should do |
| --- | --- | --- |
| Missing/ambiguous identity | Packager exits before build | Fix Keychain / pass the exact identity string |
| Wrong Team ID on the signed app | Packager exits before notarization | Re-export the certificate for the intended team |
| `notarytool` network / auth error | No artifact directory is published | Check API key or profile; re-run |
| Apple status `Invalid` / `Rejected` | Diagnostics are printed only when safe; secrets stay redacted | Run `xcrun notarytool log <submission-id> --keychain-profile AlTabNotary` (or API key flags) locally to fetch the full Apple log |
| Staple / `spctl` failure | Packager exits; no final ZIP | Confirm notarization Accepted, retry staple, do not ship the unstapled app as “notarized” |
| Any mid-flight failure | Work directory under `/tmp` is removed; destination is not created | Re-run after fixing the cause; never hand-edit a partial package and relabel it |

The packager never marks an incomplete build as notarized. Contract tests in `scripts/check_notarized_release.sh` cover success, missing/ambiguous identity, wrong Team ID, rejected Gatekeeper assessment, missing ticket, and secret-redaction behavior with mocked tools (no Apple credentials required).

### Bundle ID and signing stability

After the first public binary release for a given product identity:

- Keep the **same** Developer ID Application certificate lineage and Team ID when possible.
- Keep the **same** bundle identifier.
- Plan and test a migration before any rotation; users will otherwise re-grant Accessibility / Screen Recording and lose login-item continuity.

Do **not** ship with upstream identity values. Do **not** reuse upstream update feeds or licensing endpoints.

### GPL corresponding-source obligations

Every distributed binary ZIP must remain accompanied by the exact corresponding source archive produced beside it, plus GPL and third-party notices. The packager enforces that layout. If you host binaries elsewhere, host the matching source archive and checksums with them.

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
| `ALTAB_BUNDLE_ID` | notarized (optional) | Stable distributor bundle ID; omit only if the tracked Release ID is intentional |
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
