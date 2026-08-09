# AlTab {{RELEASE}}

> [!NOTE]
> This redistribution was signed with a **distributor-owned Developer ID Application** identity and **notarized by Apple**. It is not an automatic update channel and is not affiliated with the upstream AltTab project.

Signing status: **Developer ID Application**

Notarization status: **notarized and stapled**

- Bundle identifier: `{{BUNDLE_ID}}`
- Team ID: `{{TEAM_ID}}`
- Signing identity: `{{IDENTITY}}`

## Changes

- Describe the user-visible changes in this release.

## Download

| Priority | Asset | Purpose |
| --- | --- | --- |
| 1 | `{{BINARY_ARTIFACT}}` | Notarized redistribution ZIP: app + dSYM + notices |
| 2 | `{{SOURCE_ARTIFACT}}` + `SHA256SUMS` | Exact corresponding source for this binary, plus checksums |
| 3 | `{{MANIFEST}}` | Toolchain / provenance (secondary) |

For this binary, the corresponding source is `{{SOURCE_ARTIFACT}}` (not GitHub’s automatic Source code zip/tar.gz archives attached to the tag).

`RELEASE-NOTES.md` is generated for the GitHub Release body and shipped inside the full ZIP; it is not a primary standalone download.

## Source and provenance

- Git tag: `{{TAG}}`
- Git commit: `{{COMMIT}}`
- Repository and retained Git history: https://github.com/salasebas/altab
- Binary package: `{{BINARY_ARTIFACT}}`
- Corresponding source: `{{SOURCE_ARTIFACT}}`
- Build manifest: `{{MANIFEST}}`
- Checksums: `SHA256SUMS`

Verify every attached artifact from the directory containing the downloads:

```bash
shasum -a 256 --check SHA256SUMS
```

## GPL corresponding source

The colocated `{{SOURCE_ARTIFACT}}` is the complete corresponding source for this binary package, including packaging and verification scripts. See `SOURCE.md` and `LICENSE-GPL-3.0.md` inside the binary ZIP.
