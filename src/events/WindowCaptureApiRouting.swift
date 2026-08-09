import Foundation

/// Pure decisions for one-shot window capture on macOS 26+: which ScreenCaptureKit API to call, and
/// whether any shortcut's effective settings require capture work at all. Holds no AppKit /
/// ScreenCaptureKit state so route selection stays unit-testable (same pattern as `AxQueryRouting`).
///
/// Production wires these to real state in `WindowCaptureEvents` / `Preferences`. See
/// `WindowCaptureEventsSpecs.md` for the API trade-offs and edge cases. Full-resolution Preview is
/// no longer a burst-wide route flag (#5861 / issue #45): thumbnails stay thumbnail-scale, and only
/// a few just-in-time Preview frames use full resolution via a separate capture path.
enum WindowCaptureApiRouting {
    /// One-shot ScreenCaptureKit capture API chosen for a window on macOS 26+.
    enum Api: Equatable {
        /// `SCScreenshotManager.captureScreenshot` — no per-call stream churn; fails on fullscreen
        /// windows whose Space is inactive; returns a copied CGImage.
        case captureScreenshot
        /// `SCScreenshotManager.captureSampleBuffer` — stream-backed, zero-copy IOSurface; kept for
        /// fullscreen/inactive-Space compatibility only (Preview no longer forces this path).
        case captureSampleBuffer
    }

    /// Choose the one-shot API from a main-thread snapshot of fullscreen state.
    /// Non-fullscreen captures (thumbnail or lazy full-res Preview) use `captureScreenshot`;
    /// fullscreen windows stay on `captureSampleBuffer` (captureScreenshot fails with -3811 when
    /// that Space is inactive).
    static func api(isFullscreen: Bool) -> Api {
        isFullscreen ? .captureSampleBuffer : .captureScreenshot
    }

    /// Whether any shortcut slot's effective preview-selected-window setting is on.
    static func anyShortcutUsesPreview(maxIndex: Int, effectivePreview: (Int) -> Bool) -> Bool {
        (0 ... maxIndex).contains { effectivePreview($0) }
    }

    /// Whether any shortcut's effective settings display window captures at all: Thumbnails style
    /// and/or the Preview overlay (whose instant first frame upscales a stored thumbnail). When
    /// neither is configured, stored images would never be shown, so all capture work is skipped.
    static func anyShortcutShowsWindowCaptures(
        maxIndex: Int,
        usesPreview: (Int) -> Bool,
        usesThumbnails: (Int) -> Bool
    ) -> Bool {
        anyShortcutUsesPreview(maxIndex: maxIndex, effectivePreview: usesPreview)
            || (0 ... maxIndex).contains { usesThumbnails($0) }
    }
}
