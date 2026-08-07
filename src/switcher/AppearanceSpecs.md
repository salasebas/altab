# Appearance (window sizing) — Specs

> **Line coverage:** `AppearanceTestable.swift` 79% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

The pure sizing and grid-geometry functions decide how big the switcher's thumbnails are and how tiles
are placed on a given display. The suite pins sizing output against
a table of **21 real device models** (laptops, monitors, ultrawides, TVs) with known pixel + physical
dimensions, so a tweak to the formula can't silently regress any class of screen.

- `comfortableWidth(physicalDimension)` → the fraction of the screen the switcher should occupy (smaller
  fraction on bigger/wider screens, separate expectations for horizontal vs vertical use).
- `goodValuesForThumbnailsWidthMinMax(ratio, rowCount)` → the (min, max) thumbnail width for a given
  screen aspect ratio and row count (3, 4, or 5 rows).
- `TileGridLayout` → the shared LTR/RTL placement, wrapping, content width, and content height used by
  both auto-size dry runs and the materialized switcher layout.
- `TileGridGeometry.targetFrame` → hover and drag hit areas that consume the configured inter-tile gap.

## Behavior & edge cases

- Driven entirely by a fixture table: each row is `(model, pixels, physical-mm, expected comfortable
  fractions, [(rowCount, expectedMin, expectedMax)])`. Both tests loop the table and assert with `0.01`
  tolerance, naming the failing model.
- Bigger physical screens get a smaller comfortable fraction (a 60" TV shouldn't show a half-screen
  switcher); ultrawides get distinct horizontal vs vertical fractions.
- Tile spacing is a bounded global choice of 0, 1, 4, or 8 points. Thumbnails and App Icons use it;
  Titles always preserve the legacy compact 1-point spacing.
- The 1-point default reproduces the legacy frames exactly. Every supported value creates equal
  horizontal and vertical gaps without overlap, and RTL frames mirror LTR within the document width.
- Hover and drag use the same effective spacing as layout, assigning the full gap to the preceding tile
  in logical layout order, as the legacy 1-point hit area did.

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testGoodValuesForThumbnailsWidthMinMax** — for every model × {3,4,5} rows, the computed (min, max) thumbnail width matches the fixture.
- **testComfortableWidth** — for every model, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions aren't reported, fall back to the 0.9 default rather than the 0.45 floor.
- **testGoodValuesForThumbnailsWidthMinMaxPortrait** — for aspectRatio < 1 (portrait usage), the (min, max) uses the portrait formula and stays within the [0.09, 0.30] clamps.
- **testTileSpacingValuesAreBoundedAndKeepOnePointDefault** — the finite values and registered default remain safe and pixel-compatible.
- **testTileSpacingAppliesOnlyToGridStyles** — Thumbnails/App Icons use the choice while Titles remains at 1 point.
- **testOnePointGridLayoutPreservesLegacyFramesAndWrap** — exact legacy LTR/RTL origins, wrapping, and content size.
- **testEveryTileSpacingProducesExactGapsWithoutOverlap** — equal row/column gaps and bounded content growth at every supported value.
- **testTileGridLayoutMirrorsLTRAndRTLWithinDocumentWidth** — logical tiles mirror across the final document width.
- **testTargetFramesCoverConfiguredGapSymmetrically** — hover/drag hit areas follow spacing in both directions.
