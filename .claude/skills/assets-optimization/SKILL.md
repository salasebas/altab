---
name: assets-optimization
description: Audit and optimize every image asset shipped with AltTab. Apply the right format per asset class (licensed PDF fallbacks for semantic symbols and other vectors, HEIC for raster) and the right post-processing (strip Figma cruft from PDFs, encode raster sources to HEIC at q50 with visual review). Use whenever new assets are added, when the bundle size needs shrinking, or whenever you want a full assets audit.
---

# /assets-optimization — AltTab asset audit and optimization

## Goal

Every byte that ships in `AltTab.app/Contents/Resources/` should justify itself. Vectors stay vector, rasters compress to HEIC, and neither carries metadata, color profiles, accessibility tags, or producer signatures that AppKit doesn't use.

This skill applies a known-good pipeline to each asset class. It is opinionated about the right format and the right encoder for each kind of content.

## When to use

- A designer drops new exports into `~/Desktop/` or `resources/`.
- Someone asks "why is the bundle so big?".
- After adding a new icon, illustration, app icon variant, or menubar variant.
- Periodic audit when nothing else is broken.

## Step 1: Inventory

Run a one-shot enumeration so you know what you're working with:

```sh
find resources -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' -o -iname '*.svg' -o -iname '*.icns' \) \
  -exec ls -la {} \; | awk '{printf "%8d  %s\n", $5, $9}' | sort -k2
```

Group what you see by directory. For AltTab the relevant buckets are:

- `resources/icons/menubar/` — small template icons shown in the macOS menubar.
- `resources/icons/tabs/` — Preferences sidebar icons (template, sized ~13pt).
- `resources/icons/permission-window/` — first-launch permission window icons (~32pt).
- `resources/icons/app/` — the macOS app icon (`.icns` + `.iconset/`). **Don't touch** — `.icns` is required by the bundle and Apple's tooling produces near-optimal output already.
- `resources/illustrations/` — the appearance-tab preview thumbnails. Raster (screenshots inside).

For each asset, decide what category it falls into:

| Source content | Right format | Why |
|---|---|---|
| Custom vector design (Figma/Sketch/Illustrator) | **PDF** | macOS 10.13 doesn't accept SVG; PDF is the universal vector container AppKit reads natively. |
| System-style interface icon | **Semantic catalog + licensed PDF fallback** | Ask AppKit for the system symbol on macOS 11+, then fall back to an audited Tabler PDF on every unsupported API or name. |
| Photographic / screenshot-heavy | **HEIC** | HEIC at q50 beats JPEG by ~30% at the same perceptual quality. |
| Tiny pixel-precise UI sprite | **PNG @2x** | Below ~40×40px the PDF overhead exceeds the bitmap savings. PNG wins. |
| App icon (the macOS bundle one) | **`.icns`** | Required by `CFBundleIconFile`. |

If an asset is in the wrong format, flag it. If it's in the right format but unoptimized, run the matching pipeline below.

## Step 2: Vector PDFs — Figma exports

Figma's "Export → PDF" output is bloated. For each menubar/illustration/icon vector PDF that came from Figma, you can strip ~50–75% of the bytes without losing a single rendered pixel.

What Figma adds that AppKit doesn't need:

1. **Embedded ICC color profile** (`/ICCBased ...`, ~3.2 KB compressed). Replace every `[/ICCBased N R]` reference with `/DeviceRGB` (or `/DeviceGray` for monochrome). Patches needed in:
   - the page `Resources/ColorSpace` dict
   - every Form XObject's `Resources/ColorSpace` dict (these are streams, not plain dicts — pikepdf's `pdf.objects` will only catch them if you accept both `Dictionary` and `Stream`)
   - every Image XObject's direct `/ColorSpace` key
   - every Shading dict inside `Pattern` entries (Figma's color icons use 8+ patterns, each with its own `/ColorSpace N R` reference)
2. **`/Metadata`** XMP packet (~830 B) — Figma's XML manifest.
3. **`/StructTreeRoot`, `/ParentTree`, `/StructElem`** — accessibility tags ("Document" / "Part" structural roles). AppKit's PDF renderer ignores them.
4. **`/Info` dict** — `Producer="Figma"`, `Title="Menubar 22x22@1x white"`. In Figma's exports the Info dict sometimes lives **inline inside the Catalog** rather than at the trailer level, so deleting `pdf.docinfo` isn't enough — also `del root[Name('/Info')]`.
5. **`/Lang`, `/MarkInfo`, `/Annots`, `/StructParents`, `/Tabs`** — empty or trivial page-level entries.
6. **`/ProcSet [/PDF]`** — deprecated since PDF 1.4.

Use the script:

```sh
python3 scripts/assets/optimize_figma_pdf.py resources/icons/menubar/*.pdf
```

It edits in place and prints the savings per file. After running, also pipe through `mutool clean -ggg -z` and `qpdf --object-streams=generate --recompress-flate --compression-level=9` for the final 1–2% squeeze.

Verify each file still renders by sips'ing it back to PNG and eyeballing:

```sh
for f in resources/icons/menubar/*.pdf; do
  sips -s format png "$f" --out "/tmp/$(basename $f .pdf).png" -Z 300 >/dev/null 2>&1
done
```

Open the PNGs in Preview to confirm nothing visual changed.

## Step 3: Semantic symbols with licensed fallbacks

Interface icons are declared in `src/switcher/main-window/SymbolCatalog.swift`. Each case has a public AppKit symbol name and either a Tabler fallback asset or a locally drawn fallback. The renderer tries the system API on macOS 11 and newer, then always falls back when the API or individual name is unavailable. This preserves the macOS 10.13 deployment target without bundling proprietary fonts or extracted system artwork.

The audited PDFs live in `resources/icons/symbols/`. They come from `@tabler/icons-pdf` 3.41.0 and are covered by `scripts/licenses/Tabler-Icons-LICENSE.txt`. Space numbers and circled stars are drawn with AppKit primitives instead of shipping one asset per variant.

To add a symbol:

1. Add a semantic case, system name, and fallback mapping in `SymbolCatalog.swift`.
2. Copy the matching PDF from the pinned Tabler package into `resources/icons/symbols/`. Never export or extract a proprietary system glyph as the fallback.
3. Add the filename to `scripts/check_symbol_assets.sh`; the guard treats the asset list as an audited allowlist.
4. Run the focused `SymbolCatalogTests` and both Debug/Release bundle guards.
5. Update the Tabler version, npm integrity, and license only when intentionally upgrading the source package.

## Step 4: Raster → HEIC at q50

For anything raster (illustration thumbnails, screenshots inside an icon, anything photographic), HEIC at quality 50 is the baseline. q50 is roughly 50% smaller than JPEG at perceptually-equivalent quality, and at the small display sizes used in this app the artifacts are invisible.

Pipeline (built-in to macOS via `sips`):

```sh
sips -Z 1000 -s format heic -s formatOptions 50 input.png --out output.heic
```

- `-Z 1000` resizes the longest edge to 1000px **preserving aspect ratio**. AltTab's illustration display is 500pt wide, so 1000px is the correct @2x ship size. Anything larger wastes bytes; anything smaller looks soft on Retina.
- `formatOptions 50` is the quality. q50 was chosen after a side-by-side comparison at q20/q35/q50/q65/q80 — q50 was the lowest setting where text in screenshots stayed legible and gradient backgrounds didn't band.

Use the script for batch conversion:

```sh
bash scripts/assets/encode_heic.sh ~/Desktop 1000 50
```

That walks all PNG/JPEG files in the source directory, resizes to longest-edge 1000px at q50 HEIC, writes outputs to `/tmp/heic-out/`.

### Visual review (mandatory)

Before swapping the new HEICs into `resources/`, **always** decode a representative sample back to PNG and visually compare against the source:

```sh
sips -s format png /tmp/heic-out/sample.heic --out /tmp/sample-decoded.png >/dev/null 2>&1
open /tmp/sample-decoded.png /Users/you/Desktop/sample.png
```

Pick the visually most demanding file from the batch — usually one with the most text or the strongest gradients. Confirm:

- No banding in flat color regions
- Text edges still crisp at native display size
- No haloing around anti-aliased edges
- Color rendition matches

If anything looks degraded, bump quality to q60 or q65 and re-batch. The user, not the script, is the final arbiter — show them the sample with sizes before committing.

### Bumping quality

If q50 isn't acceptable, the next quality steps are q60 and q65 — beyond that, returns diminish quickly. q80 is the previous default in this repo and roughly 2× the bytes of q50 for no visible improvement on AltTab's content.

## Step 5: pbxproj registration

Whenever you change the file extension of a resource (.jpg → .heic, .png → .pdf, etc.), update [alt-tab-macos.xcodeproj/project.pbxproj](alt-tab-macos.xcodeproj/project.pbxproj). The places that need patching:

1. **PBXBuildFile section** — comment + the comment inside `fileRef = ... /* name.ext */`.
2. **PBXFileReference section** — comment, `lastKnownFileType` (e.g. `image.pdf`, `image.heic`, `image.png`), and `path = "name.ext"`.
3. **PBXGroup section** — the file's entry inside its parent group's `children`.
4. **PBXResourcesBuildPhase section** — the entry in the main app target's `files`.

For pure extension swaps (no new files), `sed -i '' 's|old\.ext|new.ext|g'` plus a `lastKnownFileType` substitution covers it. For new files, generate new 24-char uppercase-hex object IDs (`python3 -c "import secrets; print(secrets.token_hex(12).upper())"`) and insert in all four places.

If you removed an asset entirely (file deleted from disk), delete its 4 entries from pbxproj — otherwise the build fails with "missing file" or ships dangling references.

## Step 6: Verify

```sh
bash ai/build.sh        # must show ** BUILD SUCCEEDED **
bash ai/run.sh          # launch the app and visually inspect every asset
```

Walk through every UI surface that loads an asset:

- Menubar icon (default + the two alternates from Preferences → General → Menubar icon)
- Preferences sidebar — 4 tab icons (SF Symbol on macOS 11+, bundled PDF below)
- Permissions window — open by revoking a permission
- Preferences → Appearance — illustration thumbnails change per show/hide row

Compare `git diff --stat` before committing. Asset replacements should net negative on bundle size.

## Reporting

After the run, report:

- File-by-file before/after sizes for everything that changed.
- Total bundle delta in KB.
- Any files left untouched and why (e.g., `app.icns` — bundle-required format).
- The encoder settings used (especially HEIC quality if not q50, so the next person knows).
- Anything the visual review revealed (e.g., "had to bump to q60 for `thumbnails_dark` because gradient banding at q50").
