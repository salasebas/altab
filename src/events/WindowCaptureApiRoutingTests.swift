import XCTest

/// Pins macOS 26+ capture route selection and burst-wide Preview detection as pure, deterministic
/// decisions — no ScreenCaptureKit, AppKit, or UserDefaults. Production wires these kernels in
/// `WindowCaptureEvents` / `Preferences` (see `WindowCaptureEventsSpecs.md` and issue #44).
final class WindowCaptureApiRoutingTests: XCTestCase {

    // MARK: - API route selection

    /// Non-fullscreen thumbnail capture → `captureScreenshot` (avoids stream churn / WindowServer leak).
    func testNonFullscreenThumbnailUsesCaptureScreenshot() {
        XCTAssertEqual(
            WindowCaptureApiRouting.api(isFullscreen: false, usesPreview: false),
            .captureScreenshot)
    }

    /// Fullscreen window → `captureSampleBuffer` (captureScreenshot fails with -3811 on inactive Space).
    func testFullscreenUsesCaptureSampleBuffer() {
        XCTAssertEqual(
            WindowCaptureApiRouting.api(isFullscreen: true, usesPreview: false),
            .captureSampleBuffer)
    }

    /// Any shortcut uses Preview → full-resolution path stays on `captureSampleBuffer` (IOSurface).
    func testPreviewUsesCaptureSampleBufferEvenWhenNotFullscreen() {
        XCTAssertEqual(
            WindowCaptureApiRouting.api(isFullscreen: false, usesPreview: true),
            .captureSampleBuffer)
    }

    /// Fullscreen + Preview both force sample-buffer; sample-buffer wins either way.
    func testFullscreenWithPreviewUsesCaptureSampleBuffer() {
        XCTAssertEqual(
            WindowCaptureApiRouting.api(isFullscreen: true, usesPreview: true),
            .captureSampleBuffer)
    }

    // MARK: - Effective Preview detection (burst-wide OR)

    /// No slot enables Preview → false.
    func testAnyShortcutUsesPreviewWhenNoneEnabled() {
        XCTAssertFalse(WindowCaptureApiRouting.anyShortcutUsesPreview(maxIndex: 3) { _ in false })
    }

    /// Global/slot-0 only → true (index 0 is included in 0...maxIndex).
    func testAnyShortcutUsesPreviewWhenGlobalEnabled() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutUsesPreview(maxIndex: 3) { $0 == 0 })
    }

    /// A later per-shortcut override alone is enough — captures aren't tied to one shortcut.
    func testAnyShortcutUsesPreviewWhenOnlyLaterSlotEnabled() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutUsesPreview(maxIndex: 3) { $0 == 3 })
    }

    /// Empty range still evaluates index 0 (0...0).
    func testAnyShortcutUsesPreviewIncludesZeroWhenMaxIndexIsZero() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutUsesPreview(maxIndex: 0) { $0 == 0 })
        XCTAssertFalse(WindowCaptureApiRouting.anyShortcutUsesPreview(maxIndex: 0) { _ in false })
    }
}
