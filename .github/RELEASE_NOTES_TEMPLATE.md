# AlTab {{RELEASE}}

> [!WARNING]
> This build is **unsigned and not notarized**. macOS Gatekeeper may block it. Do not disable system-wide security protections; build from the corresponding source if you do not want to run an unsigned binary.

Signing status: **unsigned**

Notarization status: **not notarized**

## Download

| Priority | Asset | Purpose |
| --- | --- | --- |
| 1 | `{{DMG_ARTIFACT}}` | **Just run AlTab** — light install image (`AlTab.app` + Applications shortcut). **Unsigned and not notarized.** |
| 2 | `{{BINARY_ARTIFACT}}` | Full redistribution ZIP: app + dSYM + notices (**unsigned**) |
| 3 | `{{SOURCE_ARTIFACT}}` + `SHA256SUMS` | Exact corresponding source for this binary, plus checksums |
| 4 | `{{MANIFEST}}` | Toolchain / provenance (secondary) |

Prefer the `.dmg` if you only want to run AlTab. Prefer the full ZIP (or build from source) when you need symbols, notices, or redistribution provenance.

For this binary, the corresponding source is `{{SOURCE_ARTIFACT}}` (not GitHub’s automatic Source code zip/tar.gz archives attached to the tag).

`RELEASE-NOTES.md` is generated for the GitHub Release body and shipped inside the full ZIP; it is not a primary standalone download.

## Changes

- Describe the user-visible changes in this release.

## Source and provenance

- Git tag: `{{TAG}}`
- Git commit: `{{COMMIT}}`
- Repository and retained Git history: https://github.com/salasebas/altab
- Light download: `{{DMG_ARTIFACT}}`
- Full binary package: `{{BINARY_ARTIFACT}}`
- Corresponding source: `{{SOURCE_ARTIFACT}}`
- Build manifest: `{{MANIFEST}}`
- Checksums: `SHA256SUMS`

Verify every attached artifact from the directory containing the downloads:

```bash
shasum -a 256 --check SHA256SUMS
```
