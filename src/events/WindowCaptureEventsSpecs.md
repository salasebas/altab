# WindowCaptureEvents — Specs

> **Line coverage:** _pending — run `/coverage-explore` to populate_

## Summary

One-shot window screenshots for thumbnails and Preview. macOS 26+ captures through ScreenCaptureKit
(`WindowCaptureScreenshots`); older versions capture through the private `CGSHWCaptureWindowList`
(`WindowCaptureScreenshotsPrivateApi`), because SCK is unreliable there (macOS 14 crashes inside Apple's
code, macOS 15 leaks).

ScreenCaptureKit is **weak-linked** (`-weak_framework ScreenCaptureKit` in `config/base.xcconfig`).
Xcode 26's `SCScreenshotManager.h` has a stray semicolon between `API_AVAILABLE` and
`@interface SCScreenshotConfiguration`, so the availability annotation never attaches and the class ref
would otherwise link strongly. dyld binds Objective-C class refs eagerly, which aborted the process
before `main` on any macOS without that class — regardless of `#available` gates in this file.

## Thumbnail vs lazy full-resolution Preview (#5861 / issue #45)

Ordinary captures are **always thumbnail-scale**, regardless of Preview preferences. Full-resolution
frames exist only for the Preview overlay and are fetched **just-in-time** for the selected window and
up to two displayed cycling neighbors in each direction (`PreviewNeighborhood`, default radius 2 — at
most five windows). Frames land in a session-owned ten-entry LRU (`PreviewFrameLru` /
`SwitcherSession`), use a distinct throttle key (`preview-wid-*` vs `capture-wid-*`), and are released
when the session ends. Preview shows the existing thumbnail immediately, then swaps in the sharp frame
asynchronously; later thumbnail refreshes must not downgrade a sharp frame already on screen.

Show-time ordering: enqueue full-res Preview fetches **before** the ordinary thumbnail pass so the
selected window sharpens first. Capturing is skipped entirely when no shortcut's effective settings
display thumbnails or Preview (`Preferences.anyShortcutShowsWindowCaptures`).

Below macOS 26, `CGSHWCaptureWindowList` always captures full-size, so `Window.thumbnail` is already
sharp and the lazy full-res path is a no-op.

## SCK API selection (macOS 26+)

Two public one-shot APIs exist, each broken differently:

- `captureSampleBuffer` returns a zero-copy IOSurface, but Apple implements each call by creating and
  destroying a capture stream. On some machines that churn leaks WindowServer memory until macOS
  force-logs-out the session (#5786 / issue #44). Each call also emits WindowServer
  `Creating sharing context` events and `Screenshots via streams are inefficient` warnings. Under large
  full-res bursts, replayd/systemstatusd attribution work can also wedge screenshots system-wide
  (#5861).
- `captureScreenshot` (new in macOS 26) creates no per-call stream (zero of the above events), but:
  - it fails with `SCStreamError -3811` for a fullscreen window whose Space is not frontmost (it succeeds
    when that Space is frontmost, and for minimized, other-Space, partially-offscreen, and tabbed windows);
  - it returns a copied `CGImage` instead of an IOSurface. At thumbnail sizes it is slightly *faster*
    than `captureSampleBuffer`; at full resolution the copy cost is acceptable because Preview frames are
    fetched lazily (a few per session), not as an N-window burst.

Routing lives in pure `WindowCaptureApiRouting.api(isFullscreen:)`:

- `captureScreenshot` for every non-fullscreen capture (thumbnail **and** lazy full-res Preview)
- `captureSampleBuffer` only for fullscreen windows (inactive-Space compatibility)

Main-thread snapshots of size, scale, fullscreen state, and per-request `fullRes` are taken before
hopping to `screenshotsQueue`. Capture completion always balances `ActiveWindowCaptures`, ignores
inactive UI (`refreshOnlyThumbnailsAfterShowUi` when the switcher is gone), and does **not** fall back
to `captureSampleBuffer` after a `captureScreenshot` failure. Full-res deliveries go to the session
cache (`deliver(..., fullRes: true)`); thumbnail deliveries call `Window.refreshThumbnail`.

## Edge cases

- **Stale fullscreen state**: `isFullscreen` is snapshotted on the main thread when the burst is built, so
  a window mid-transition can be routed to `captureScreenshot` and fail with -3811. Deliberately no
  fallback/retry: the thumbnail keeps its previous contents and the next refresh re-routes. A fallback
  would silently reintroduce stream churn and hide new failure modes.
- **Preview is no longer burst-wide full-res**: background and show-time thumbnail passes stay
  thumbnail-scale even when Preview is enabled. Only `WindowThumbnails.fetchPreviewFrames` requests
  `fullRes: true`, and only for the selected neighborhood missing from the session cache.
- **Throttle keys are resolution-specific**: a preview fetch must not be coalesced away by a thumbnail
  capture of the same wid submitted milliseconds earlier at show time (`preview-wid-*` vs `capture-wid-*`).
- **Privacy attribution cost is API-independent**: both APIs flip replayd's screen-capture attribution
  (~4 `updateScreenCaptureDidStart` events per capture) and cost systemstatusd the same CPU (measured
  within 2%). Switching APIs fixes the WindowServer leak; lazy full-res bounds the attribution backlog.

## Measurements (2026-07-11, macOS 26.5.1, M-series, 29-window payload, 10 switcher cycles per run)

| per run (~355 captures) | captureSampleBuffer | captureScreenshot |
|---|---|---|
| WindowServer sharing contexts / warnings | ~355 / ~355 | 0 / 0 |
| capture latency mean (thumbnail sizes) | 706 ms | 644 ms |
| capture latency mean (full-res, ≤5.2 MP) | 709 ms | 664 ms |
| replayd CPU | 2.0 s | 1.8 s |
| systemstatusd CPU | 4.8 s | 4.7 s |
| failures | 0 | only fullscreen-on-inactive-Space, always -3811 |

## Test scenarios

Mirrors `WindowCaptureApiRoutingTests.swift` 1:1 (pure kernel; integration paths need manual QA).
Related pure kernels: `PreviewFrameLruTests`, `PreviewNeighborhoodTests`.

### API route selection
- **testNonFullscreenUsesCaptureScreenshot** — not fullscreen → `captureScreenshot` (thumbnail or lazy Preview).
- **testFullscreenUsesCaptureSampleBuffer** — fullscreen → `captureSampleBuffer`.

### Effective Preview detection (OR across slots)
- **testAnyShortcutUsesPreviewWhenNoneEnabled** — every slot off → false.
- **testAnyShortcutUsesPreviewWhenGlobalEnabled** — only index 0 on → true.
- **testAnyShortcutUsesPreviewWhenOnlyLaterSlotEnabled** — only a later slot on → true.
- **testAnyShortcutUsesPreviewIncludesZeroWhenMaxIndexIsZero** — `maxIndex == 0` still evaluates slot 0.

### Effective capture work (thumbnails and/or Preview)
- **testAnyShortcutShowsWindowCapturesWhenNone** — neither feature → false (skip capture).
- **testAnyShortcutShowsWindowCapturesWhenOnlyPreview** — Preview alone → true.
- **testAnyShortcutShowsWindowCapturesWhenOnlyThumbnails** — Thumbnails style alone → true.
- **testAnyShortcutShowsWindowCapturesWhenBoth** — either feature on any slot → true.

## Manual QA

- Normal window thumbnails on macOS 26 stay thumbnail-scale with Preview enabled.
- Opening the switcher with many windows does not wedge system screenshots (bounded full-res work).
- Preview appears immediately from the thumbnail and sharpens without later thumbnail refreshes
  downgrading it.
- Cycling Tab through neighbors lands on pre-fetched sharp Previews when possible.
- Inactive-Space fullscreen windows remain capturable (`captureSampleBuffer`).
- Minimized and other-Space windows still get thumbnails.
- Idle after hide: full-res session cache is gone; only thumbnails remain.
- Launch on macOS 14/15 must not abort before `main` (weak ScreenCaptureKit load).
