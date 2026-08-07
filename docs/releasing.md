# Packaging redistribution artifacts

This is an optional downstream redistribution tool, not AlTab's normal local build. Routine use builds an optimized app with `scripts/build_local.sh`, while development and QA use the Debug command in `ai/build.sh`; both leave products in `DerivedData` and neither packages or publishes anything. Normal pull-request CI validates source, tests, and Debug/Release compilation without invoking this tool or requiring its release prose and templates.

Redistribution artifacts are assembled from an explicit Git tag or full 40-character commit. The packager exports that revision with `git archive`, builds inside the exported tree at a stable commit-derived path, normalizes package ordering and timestamps, and places that exact source beside the binary. Ignored local configuration such as `config/local.xcconfig`, signing identities, and maintainer secrets cannot enter the build.

## Prerequisites

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

Tags named `vN`, `vN.N`, or `vN.N.N` set the app bundle version to the numeric portion. Untagged commit previews use bundle version `0`; their exact identity remains the full commit in the manifest.

## Artifacts

The command creates `dist/AlTab-<release>/` containing:

- `AlTab-<release>-macOS-unsigned.zip`: `AlTab.app`, its matching `AlTab.app.dSYM`, GPL and third-party notices, source instructions, release notes, and the build manifest
- `AlTab-<release>-source.tar.gz`: the exact tracked source revision, including all build and packaging scripts
- `AlTab-<release>-BUILD-MANIFEST.md`: commit, tag, toolchain, SDK, architectures, exact build command, bundle metadata, and signing/notarization status
- `AlTab-<release>-RELEASE-NOTES.md`: rendered from the repository template
- `SHA256SUMS`: SHA-256 checksums for every other published artifact

The current packager intentionally produces an **unsigned and not notarized** universal Release build. Signing and notarization require a separately designed fork-owned identity and workflow. No repository workflow invokes this packager, receives release secrets, or publishes its output.

The script verifies arm64 and x86_64 slices, matching app/dSYM UUIDs, absence of a Developer ID authority and Team ID, complete checksums and notices, source-archive identity, and both service-isolation and unrestricted-feature guards after extracting the final ZIP. Xcode may emit a non-identifying ad hoc Mach-O signature even when code signing is disabled; the verifier accepts only that state or a fully unsigned bundle. It rejects known upstream signing identities, update or licensing endpoints, analytics credentials, and release-secret markers.

## Rebuilding

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
