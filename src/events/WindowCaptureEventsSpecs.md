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

## SCK API selection (macOS 26+)

Two public one-shot APIs exist, each broken differently:

- `captureSampleBuffer` returns a zero-copy IOSurface, but Apple implements each call by creating and
  destroying a capture stream. On some machines that churn leaks WindowServer memory until macOS
  force-logs-out the session (#5786 / issue #44). Each call also emits WindowServer
  `Creating sharing context` events and `Screenshots via streams are inefficient` warnings.
- `captureScreenshot` (new in macOS 26) creates no per-call stream (zero of the above events), but:
  - it fails with `SCStreamError -3811` for a fullscreen window whose Space is not frontmost (it succeeds
    when that Space is frontmost, and for minimized, other-Space, partially-offscreen, and tabbed windows);
  - it returns a copied `CGImage` instead of an IOSurface, which measurably slows full-resolution captures
    of large windows (relevant to Preview; at thumbnail sizes it is slightly *faster* than
    `captureSampleBuffer`).

Routing lives in pure `WindowCaptureApiRouting.api(isFullscreen:usesPreview:)`:

- `captureScreenshot` for non-fullscreen thumbnail captures
- `captureSampleBuffer` for fullscreen windows, and for every window when any shortcut's effective
  settings enable preview-selected-window (full-resolution path)

Main-thread snapshots of size, scale, fullscreen state, and `usesPreview` are taken before hopping to
`screenshotsQueue`. Capture completion always balances `ActiveWindowCaptures`, ignores inactive UI
(`refreshOnlyThumbnailsAfterShowUi` when the switcher is gone), and does **not** fall back to
`captureSampleBuffer` after a `captureScreenshot` failure.

## Edge cases

- **Stale fullscreen state**: `isFullscreen` is snapshotted on the main thread when the burst is built, so
  a window mid-transition can be routed to `captureScreenshot` and fail with -3811. Deliberately no
  fallback/retry: the thumbnail keeps its previous contents and the next refresh re-routes. A fallback
  would silently reintroduce stream churn and hide new failure modes.
- **Preview is burst-wide, not per-window**: background captures aren't tied to a shortcut, so if any
  shortcut slot enables preview, every capture in the burst is full-resolution and uses
  `captureSampleBuffer` (`Preferences.anyShortcutUsesPreview` →
  `WindowCaptureApiRouting.anyShortcutUsesPreview`).
- **Privacy attribution cost is API-independent**: both APIs flip replayd's screen-capture attribution
  (~4 `updateScreenCaptureDidStart` events per capture) and cost systemstatusd the same CPU (measured
  within 2%). Switching APIs fixes the WindowServer leak, not the per-capture attribution overhead.

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

### API route selection
- **testNonFullscreenThumbnailUsesCaptureScreenshot** — not fullscreen, no Preview → `captureScreenshot`.
- **testFullscreenUsesCaptureSampleBuffer** — fullscreen, no Preview → `captureSampleBuffer`.
- **testPreviewUsesCaptureSampleBufferEvenWhenNotFullscreen** — Preview on → `captureSampleBuffer`.
- **testFullscreenWithPreviewUsesCaptureSampleBuffer** — both flags on → `captureSampleBuffer`.

### Effective Preview detection (burst-wide OR)
- **testAnyShortcutUsesPreviewWhenNoneEnabled** — every slot off → false.
- **testAnyShortcutUsesPreviewWhenGlobalEnabled** — only index 0 on → true.
- **testAnyShortcutUsesPreviewWhenOnlyLaterSlotEnabled** — only a later slot on → true.
- **testAnyShortcutUsesPreviewIncludesZeroWhenMaxIndexIsZero** — `maxIndex == 0` still evaluates slot 0.

## Manual QA

- Normal window thumbnails on macOS 26 (prefer `captureScreenshot` path).
- Minimized windows still get thumbnails.
- Other-Space windows still get thumbnails.
- Inactive-Space fullscreen windows remain capturable (`captureSampleBuffer`).
- Launch on macOS 14/15 must not abort before `main` (weak ScreenCaptureKit load).
