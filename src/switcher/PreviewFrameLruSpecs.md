# PreviewFrameLru — Specs

> **Line coverage:** _pending — run `/coverage-explore` to populate_

## Summary

Pure LRU bookkeeping for full-resolution Preview frames. Frames live on `SwitcherSession` (not
`Window.thumbnail`) so they die with the session; this kernel only manages the access order and
capacity (`maxEntries = 10`). Production calls `afterStore` on capture delivery and `touch` on read
(`previewFrame`).

## Edge cases

- **Duplicate touch**: re-storing or re-accessing a wid already in the order moves it to most-recent
  without growing the list.
- **Eviction**: when order length exceeds capacity after a store, the least-recently-used (front of
  the order) is returned as `evicted` for the map removal.
- **Access without store**: `touch` alone does not evict; capacity is enforced only on store.

## Test scenarios

Mirrors `PreviewFrameLruTests.swift` 1:1.

### Touch / order
- **testTouchAppendsWhenAbsent** — empty order + touch → single-element order ending with wid.
- **testTouchMovesExistingToMostRecent** — touch a middle wid → it becomes last; no growth.
- **testTouchDoesNotDuplicate** — touch the same wid twice → still one entry.

### Eviction
- **testEvictIfNeededUnderCapacityReturnsNil** — count ≤ max → no eviction.
- **testEvictIfNeededOverCapacityDropsOldest** — count > max → first (oldest) is evicted.
- **testAfterStoreEvictsWhenOverCapacity** — filling past max returns the least-recently-used wid.
- **testAfterStoreRestoresOrderOnRestoredWid** — re-storing a wid already present does not grow order.
