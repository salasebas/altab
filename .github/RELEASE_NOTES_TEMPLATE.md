# AlTab {{RELEASE}}

> [!WARNING]
> This build is **unsigned and not notarized**. macOS Gatekeeper may block it. Do not disable system-wide security protections; build from the corresponding source if you do not want to run an unsigned binary.

Signing status: **unsigned**

Notarization status: **not notarized**

## Download

| Asset | Purpose |
| --- | --- |
| `{{DMG_ARTIFACT}}` | Light install image: `AlTab.app` + Applications shortcut (**unsigned**, casual download) |
| `{{BINARY_ARTIFACT}}` | Full redistribution ZIP: app + dSYM + notices (**unsigned**) |
| `{{SOURCE_ARTIFACT}}` | Exact corresponding source for the binary |
| `{{MANIFEST}}` | Toolchain and build command |
| `SHA256SUMS` | Checksums for every asset above |

Prefer the `.dmg` if you only want to run AlTab. Prefer the full ZIP (or build from source) when you need symbols, notices, or redistribution provenance.

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
