import XCTest

/// Pins macOS 26+ capture route selection and effective capture-preference detection as pure,
/// deterministic decisions — no ScreenCaptureKit, AppKit, or UserDefaults. Production wires these
/// kernels in `WindowCaptureEvents` / `Preferences` (see `WindowCaptureEventsSpecs.md` and issues
/// #44 / #45).
final class WindowCaptureApiRoutingTests: XCTestCase {
    // MARK: - API route selection

    /// Non-fullscreen capture (thumbnail or lazy full-res Preview) → `captureScreenshot`.
    func testNonFullscreenUsesCaptureScreenshot() {
        XCTAssertEqual(WindowCaptureApiRouting.api(isFullscreen: false), .captureScreenshot)
    }

    /// Fullscreen window → `captureSampleBuffer` (captureScreenshot fails with -3811 on inactive Space).
    func testFullscreenUsesCaptureSampleBuffer() {
        XCTAssertEqual(WindowCaptureApiRouting.api(isFullscreen: true), .captureSampleBuffer)
    }

    // MARK: - Effective Preview detection (OR across slots)

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

    // MARK: - Effective capture work (thumbnails and/or Preview)

    /// Neither thumbnails nor Preview on any slot → skip all capture work.
    func testAnyShortcutShowsWindowCapturesWhenNone() {
        XCTAssertFalse(WindowCaptureApiRouting.anyShortcutShowsWindowCaptures(
            maxIndex: 2, usesPreview: { _ in false }, usesThumbnails: { _ in false }
        ))
    }

    /// Preview alone is enough (instant frame upscales the stored thumbnail).
    func testAnyShortcutShowsWindowCapturesWhenOnlyPreview() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutShowsWindowCaptures(
            maxIndex: 2, usesPreview: { $0 == 1 }, usesThumbnails: { _ in false }
        ))
    }

    /// Thumbnails style alone is enough.
    func testAnyShortcutShowsWindowCapturesWhenOnlyThumbnails() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutShowsWindowCaptures(
            maxIndex: 2, usesPreview: { _ in false }, usesThumbnails: { $0 == 0 }
        ))
    }

    /// Either feature on any slot → true.
    func testAnyShortcutShowsWindowCapturesWhenBoth() {
        XCTAssertTrue(WindowCaptureApiRouting.anyShortcutShowsWindowCaptures(
            maxIndex: 1, usesPreview: { $0 == 0 }, usesThumbnails: { $0 == 1 }
        ))
    }
}
