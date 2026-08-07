# Symbol catalog specification

AlTab identifies icons by semantic names rather than private-use font codepoints.

- On macOS 11 and newer, the renderer first asks AppKit for the matching system symbol.
- If the API or individual symbol is unavailable, it loads a vector PDF from the bundled `symbols` directory.
- Bundled PDFs come from Tabler Icons 3.41.0 under the MIT license; the exact provenance is recorded in `docs/acknowledgments.md`.
- Circled stars and Space numbers are drawn locally with AppKit primitives, so they need no third-party asset.
- Space numbers 0 through 19 are supported. An out-of-range number renders an explicit question-mark fallback.
- A missing PDF also renders the explicit fallback instead of returning `nil` or force-unwrapping.
- Every catalog case declares a non-optional fallback kind. The compiler therefore rejects new symbols that omit their licensed asset or local drawing path.
- Every catalog case and bundled fallback is covered by `SymbolCatalogTests.swift`.

Automated verification covers 11, 13, 18, and 28 point rendering, high-density rasterization, asset presence, and the fallback path independently of the host macOS version. Release verification must additionally inspect light/dark tinting, status icons, and left-to-right/right-to-left layout on the oldest and newest supported macOS versions.
