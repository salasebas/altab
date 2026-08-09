# Appearance (window sizing and row alignment) — Specs

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
- `alignedRowOrigins(frames, containerWidth, padding, alignment, direction)` → the horizontal origins
  for a packed row using semantic Leading, Center, or Trailing alignment.
- `resolvedTileWidths(naturalWidths, uniformEnabled)` → optional equal outer widths for Thumbnails,
  driven by the widest natural tile in the current displayed set.
- `usesUniformTileWidths(style, preferenceEnabled)` → the preference only affects Thumbnails.
- `naturalOuterTileWidth(contentWidth, edgeInsets, minWidth)` → the existing outer tile width floor.

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
- Row alignment is semantic: Leading and Trailing mirror in right-to-left interfaces, while Center is
  unchanged. The kernel measures the row's actual frame bounds, so variable-width thumbnails and
  equal-width app icons share one path.
- The preference applies to Thumbnails and App Icons. The single-column Titles style keeps its
  existing centered layout while still using the same coordinate normalization.
- RTL rows may be initially anchored to a packing width larger than the final visible container. The
  aligned origins normalize that difference, keeping tiles, highlights, controls, and hit-testing in
  the document's coordinate space.
- Uniform tile widths is off by default. When off, natural variable widths and wrapping are unchanged.
- When on for Thumbnails, every displayed tile's outer width becomes the widest natural width from that
  set. Natural widths already include the min-width floor and thumbnail max sizing; the shared value
  does not re-scale images. Narrower thumbnails stay centered inside the expanded tile. App Icons and
  Titles ignore the preference. Wrapping and auto-size dry runs use the shared widths before packing.

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testGoodValuesForThumbnailsWidthMinMax** — for every model × {3,4,5} rows, the computed (min, max) thumbnail width matches the fixture.
- **testComfortableWidth** — for every model, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions aren't reported, fall back to the 0.9 default rather than the 0.45 floor.
- **testGoodValuesForThumbnailsWidthMinMaxPortrait** — for aspectRatio < 1 (portrait usage), the (min, max) uses the portrait formula and stays within the [0.09, 0.30] clamps.
- **testTileSpacingValuesAreBoundedAndKeepOnePointDefault** — the finite values and registered default remain safe and pixel-compatible.
- **testUniformTileWidthsDefaultIsOffAndOnlyAppliesToThumbnails** — preference default is false; only Thumbnails may enable uniform widths.
- **testUniformTileWidthsOffModePreservesNaturalWidths** — disabled mode returns natural widths and empty sets unchanged.
- **testUniformTileWidthsUsesWidestNaturalWidthForAllTiles** — enabled mode expands every tile to the widest natural width.
- **testNaturalOuterTileWidthAppliesMinFloorWithoutChangingAspectContent** — outer width uses content + insets and the min floor.
- **testUniformTileWidthsLayoutWrapsUsingSharedWidth** — packing/wrapping uses the shared width, not the narrower natural widths.
- **testUniformTileWidthsMirrorsInRightToLeftLayout** — uniform-width rows mirror LTR/RTL within the document width.
- **testTileSpacingAppliesOnlyToGridStyles** — Thumbnails/App Icons use the choice while Titles remains at 1 point.
- **testOnePointGridLayoutPreservesLegacyFramesAndWrap** — exact legacy LTR/RTL origins, wrapping, and content size.
- **testEveryTileSpacingProducesExactGapsWithoutOverlap** — equal row/column gaps and bounded content growth at every supported value.
- **testTileGridLayoutMirrorsLTRAndRTLWithinDocumentWidth** — logical tiles mirror across the final document width.
- **testTargetFramesCoverConfiguredGapSymmetrically** — hover/drag hit areas follow spacing in both directions.
- **testVariableWidthRowAlignmentInLeftToRightLayout** — Leading, Center, and Trailing place a short thumbnail row at the expected physical edges.
- **testVariableWidthRowAlignmentMirrorsInRightToLeftLayout** — semantic alignment mirrors while preserving logical tile order.
- **testEqualWidthAppIconRowUsesTheSameAlignmentGeometry** — app-icon rows use the same alignment kernel.
- **testFullWidthRowDoesNotMoveForAnyAlignment** — full rows remain visually unchanged for every value and direction.
- **testRightToLeftRowNormalizesFromWiderPackingArea** — RTL rows packed against a wider maximum are brought into the final document bounds.
- **testAlignedRowOriginsAreIdempotentAndHandleEmptyRows** — repeated alignment is stable and empty rows are a no-op.
