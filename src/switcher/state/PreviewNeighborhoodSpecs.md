# PreviewNeighborhood — Specs

> **Line coverage:** _pending — run `/coverage-explore` to populate_

## Summary

Pure neighborhood for lazy full-resolution Preview captures. At show time and on every selection
change, only the selected window plus up to `radius` (default 2) displayed neighbors in each Tab
direction are requested at full resolution — at most five windows when every neighbor is visible.

Hidden / filtered-out list entries are skipped so the set matches what the user can cycle onto.
Order wraps like Tab (`% count`).

## Edge cases

- **Empty / out-of-range selection**: returns empty set.
- **Mismatched arrays**: `isDisplayed.count != windowIds.count` → empty set.
- **Hidden neighbors**: skipped; keep walking until `radius` displayed windows found or the whole
  list has been scanned once per direction.
- **Wrap**: last + 1 → first, first − 1 → last.
- **Nil window ids**: index still counts for walk, but is not inserted into the result.
- **Small lists**: walking stops after one full lap per direction; may return fewer than `1 + 2*radius`.

## Test scenarios

Mirrors `PreviewNeighborhoodTests.swift` 1:1.

- **testSelectedAloneWhenNoNeighbors** — single displayed window → only its id.
- **testIncludesTwoNeighborsEachSide** — five displayed windows, select middle → all five.
- **testSkipsHiddenWindows** — hidden entries between selected and next displayed are skipped.
- **testWrapsAtListBoundary** — selection at end wraps to start for the forward side.
- **testEmptyWhenSelectedIndexOutOfRange** — invalid index → empty.
- **testMismatchedArraysReturnEmpty** — length mismatch → empty.
- **testNilWindowIdsOmitted** — nil id at selected or neighbor is not in the set.
