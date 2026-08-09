import Foundation

/// Pure decisions for one-shot window capture on macOS 26+: which ScreenCaptureKit API to call, and
/// whether any shortcut's effective settings require full-resolution Preview capture. Holds no AppKit /
/// ScreenCaptureKit state so route selection stays unit-testable (same pattern as `AxQueryRouting`).
///
/// Production wires these to real state in `WindowCaptureEvents` / `Preferences`. See
/// `WindowCaptureEventsSpecs.md` for the API trade-offs and edge cases.
enum WindowCaptureApiRouting {
    /// One-shot ScreenCaptureKit capture API chosen for a window on macOS 26+.
    enum Api: Equatable {
        /// `SCScreenshotManager.captureScreenshot` — no per-call stream churn; fails on fullscreen
        /// windows whose Space is inactive; returns a copied CGImage.
        case captureScreenshot
        /// `SCScreenshotManager.captureSampleBuffer` — stream-backed, zero-copy IOSurface; kept for
        /// fullscreen/inactive-Space compatibility and full-resolution Preview.
        case captureSampleBuffer
    }

    /// Choose the one-shot API from main-thread snapshots of fullscreen state and effective Preview use.
    /// Non-fullscreen thumbnail captures use `captureScreenshot`; fullscreen windows and any burst that
    /// needs Preview-resolution stay on `captureSampleBuffer`.
    static func api(isFullscreen: Bool, usesPreview: Bool) -> Api {
        if isFullscreen || usesPreview { return .captureSampleBuffer }
        return .captureScreenshot
    }

    /// Whether any shortcut slot's effective preview-selected-window setting is on. Captures aren't
    /// tied to a specific shortcut, so sizing and routing for Preview must OR every slot.
    static func anyShortcutUsesPreview(maxIndex: Int, effectivePreview: (Int) -> Bool) -> Bool {
        (0...maxIndex).contains { effectivePreview($0) }
    }
}
