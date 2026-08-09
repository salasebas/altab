import Cocoa

/// Off-main-thread screenshot capture for window thumbnails, plus the
/// "preview the selected window" overlay shown next to the switcher panel.
enum WindowThumbnails {
    static func previewSelectedIfNeeded() {
        if let session = SwitcherSession.current, ScreenRecordingPermission.status == .granted
               && Preferences.effectivePreviewSelectedWindow(session.shortcutIndex)
               && TilesPanel.shared.isKeyWindow,
           let window = Windows.selectedWindow(),
           let id = window.cgWindowId,
           // the session's full-res frame if already fetched, else the thumbnail upscaled while
           // fetchPreviewFrames' capture is in flight (it swaps in via PreviewPanel.updateIfShowing)
           let preview = session.previewFrame(id) ?? window.thumbnail,
           let position = window.position,
           let size = window.size {
            PreviewPanel.show(id, preview, position, size)
        } else {
            PreviewPanel.hide()
        }
    }

    /// Dispatch screenshot requests off the main-thread. These captures are thumbnail-scale ONLY (on
    /// macOS 26+): full-resolution frames for the Preview panel are fetched separately and just-in-time
    /// by `fetchPreviewFrames` into the session's capped cache, so idle RAM stays small and a show
    /// doesn't burst N full-res captures at the system capture path (#5861 / issue #45).
    static func refreshAsync(_ windows: [Window], _ source: RefreshCausedBy, windowRemoved: Bool = false, prioritizedIds: Set<CGWindowID>? = nil) {
        guard (!windows.isEmpty || windowRemoved) && ScreenRecordingPermission.status == .granted
               && !ScreenLockEvents.isScreenLocked
               && Preferences.anyShortcutShowsWindowCaptures
               && (Preferences.captureWindowsInBackground || SwitcherSession.isActive) else { return }
        var eligibleWindows = [Window]()
        for window in windows {
            if !window.isWindowlessApp, let cgWindowId = window.cgWindowId, cgWindowId != CGWindowID(bitPattern: -1) {
                eligibleWindows.append(window)
            }
        }
        guard (!eligibleWindows.isEmpty || windowRemoved) else { return }
        // ScreenCaptureKit's capture path is unreliable before macOS 26: macOS 14 crashes inside Apple's own
        // teardown (-[SCStreamManager serverDidDisconnect], a top crash in 11.3.0) and macOS 15 hits the bugs
        // in #5190 (https://github.com/lwouis/alt-tab-macos/issues/5190). Apple rewrote ScreenCaptureKit's
        // internals for macOS 26, so we only use it there; everything older captures via CGSHWCaptureWindowList.
        if #available(macOS 26.0, *) {
            WindowCaptureScreenshots.oneTimeScreenshots(eligibleWindows, source, prioritizedIds: prioritizedIds)
        } else {
            WindowCaptureScreenshotsPrivateApi.oneTimeScreenshots(eligibleWindows, source, prioritizedIds: prioritizedIds)
        }
    }

    /// Fetch just-in-time full-resolution Preview frames for the selected window and its ±2 cycling
    /// neighbors (so quick Tab presses land on a sharp Preview). Frames go to the session's capped cache,
    /// not `Window.thumbnail`, and die with the session. Called on show and on every selection move; the
    /// cache and the per-wid throttler keep re-requests cheap. No-op below macOS 26, where
    /// CGSHWCaptureWindowList always captures full-size, so `Window.thumbnail` is already sharp.
    static func fetchPreviewFrames() {
        guard #available(macOS 26.0, *), let session = SwitcherSession.current,
              ScreenRecordingPermission.status == .granted, !ScreenLockEvents.isScreenLocked,
              Preferences.effectivePreviewSelectedWindow(session.shortcutIndex) else { return }
        let missingIds = Windows.selectedNeighborhoodIds().filter { !session.hasPreviewFrame($0) }
        guard !missingIds.isEmpty else { return }
        let windowsToFetch = Windows.list.filter { $0.cgWindowId.map { missingIds.contains($0) } ?? false }
        let selectedId = Windows.selectedWindow()?.cgWindowId
        WindowCaptureScreenshots.oneTimeScreenshots(windowsToFetch, .refreshOnlyThumbnailsAfterShowUi,
            prioritizedIds: selectedId.map { [$0] } ?? [], fullRes: true)
    }

    static func captureFocusedInBackground(_ window: Window) {
        // no-op shell; full capture path remains refreshAsync / Preview (#45)
        _ = window
    }

    static func deferCaptureUntilRestoreEnds(_ window: Window) {
        // wired fully in issue #58
        _ = window
    }
}
