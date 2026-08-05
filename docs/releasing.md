# Packaging a release

AlTab releases are assembled from an explicit Git tag or full 40-character commit. The packager exports that revision with `git archive`, builds inside the exported tree at a stable commit-derived path, normalizes package ordering and timestamps, and publishes that exact source alongside the binary. Ignored local configuration such as `config/local.xcconfig`, signing identities, and maintainer secrets cannot enter the build.

## Prerequisites

- macOS with Xcode 26 and its command-line tools selected
- Git, `zip`, `gzip`, `shasum`, and the standard macOS developer tools
- A revision that already contains the packaging and validation scripts

From this repository, run one documented command:

```bash
scripts/package_release.sh <tag-or-commit>
```

An optional second argument selects the output directory. A tag must be named exactly; a commit must be its full SHA. Branches, abbreviated SHAs, unsafe artifact names, gitlinks, and an existing destination are rejected.

Tags named `vN`, `vN.N`, or `vN.N.N` set the app bundle version to the numeric portion. Untagged commit previews use bundle version `0`; their exact identity remains the full commit in the manifest.

## Artifacts

The command creates `dist/AlTab-<release>/` containing:

- `AlTab-<release>-macOS-unsigned.zip`: `AlTab.app`, its matching `AlTab.app.dSYM`, GPL and third-party notices, source instructions, release notes, and the build manifest
- `AlTab-<release>-source.tar.gz`: the exact tracked source revision, including all build and packaging scripts
- `AlTab-<release>-BUILD-MANIFEST.md`: commit, tag, toolchain, SDK, architectures, exact build command, bundle metadata, and signing/notarization status
- `AlTab-<release>-RELEASE-NOTES.md`: rendered from the repository template
- `SHA256SUMS`: SHA-256 checksums for every other published artifact

The current packager intentionally produces an **unsigned and not notarized** universal Release build. Signing and notarization require a separately designed fork-owned identity and workflow.

The script verifies arm64 and x86_64 slices, matching app/dSYM UUIDs, absence of a Developer ID authority and Team ID, complete checksums and notices, source-archive identity, and both service-isolation and unrestricted-feature guards after extracting the final ZIP. Xcode may emit a non-identifying ad hoc Mach-O signature even when code signing is disabled; the verifier accepts only that state or a fully unsigned bundle. It rejects known upstream signing identities, update or licensing endpoints, analytics credentials, and release-secret markers.

## Rebuilding

Extract the corresponding source archive, select the Xcode version recorded in the manifest, and run the exact `xcodebuild` command recorded there. The command uses the Release scheme with code signing disabled and `ARCHS='arm64 x86_64'`. The tracked Apple font subset is a build input and is not regenerated during packaging.

Verify downloaded artifacts before using them:

```bash
shasum -a 256 --check SHA256SUMS
```
