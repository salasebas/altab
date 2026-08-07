import XCTest

/// Pins Screen Recording probe decisions so timer ticks never call prompt-capable APIs and Deny
/// cannot loop system dialogs (issue #36).
final class ScreenRecordingPermissionDecisionTests: XCTestCase {
    /// Silent grant → granted without prompt, even if skip is set.
    func testSilentGrantIsGrantedWithoutPrompt() {
        let outcome = ScreenRecordingPermissionDecision.resolve(.init(
            preflightGranted: true, skipped: true, allowPrompt: true, hasIssuedPromptCapableProbe: false))
        XCTAssertEqual(outcome.status, .granted)
        XCTAssertFalse(outcome.shouldRunPromptCapableProbe)
    }

    /// Skip without grant → skipped; never prompt.
    func testSkipWithoutGrantIsSkippedWithoutPrompt() {
        let outcome = ScreenRecordingPermissionDecision.resolve(.init(
            preflightGranted: false, skipped: true, allowPrompt: true, hasIssuedPromptCapableProbe: false))
        XCTAssertEqual(outcome.status, .skipped)
        XCTAssertFalse(outcome.shouldRunPromptCapableProbe)
    }

    /// Timer-style tick (allowPrompt false) while not granted → quiet notGranted.
    func testTimerTickNeverRequestsPromptCapableProbe() {
        let outcome = ScreenRecordingPermissionDecision.resolve(.init(
            preflightGranted: false, skipped: false, allowPrompt: false, hasIssuedPromptCapableProbe: false))
        XCTAssertEqual(outcome.status, .notGranted)
        XCTAssertFalse(outcome.shouldRunPromptCapableProbe)
        XCTAssertFalse(ScreenRecordingPermissionDecision.timerMayUsePromptCapableProbe())
    }

    /// First explicit request while not granted → one prompt-capable probe.
    func testFirstExplicitRequestAllowsOnePromptCapableProbe() {
        let outcome = ScreenRecordingPermissionDecision.resolve(.init(
            preflightGranted: false, skipped: false, allowPrompt: true, hasIssuedPromptCapableProbe: false))
        XCTAssertTrue(outcome.shouldRunPromptCapableProbe)
        XCTAssertTrue(outcome.hasIssuedPromptCapableProbe)
        XCTAssertEqual(outcome.status, .notGranted)
    }

    /// After a prompt was issued, further allowPrompt calls stay quiet.
    func testSecondRequestAfterPromptStaysQuiet() {
        let outcome = ScreenRecordingPermissionDecision.resolve(.init(
            preflightGranted: false, skipped: false, allowPrompt: true, hasIssuedPromptCapableProbe: true))
        XCTAssertEqual(outcome.status, .notGranted)
        XCTAssertFalse(outcome.shouldRunPromptCapableProbe)
        XCTAssertTrue(outcome.hasIssuedPromptCapableProbe)
    }

    /// Prompt-capable granted → granted.
    func testPromptCapableGrantedResolvesGranted() {
        XCTAssertEqual(ScreenRecordingPermissionDecision.resolveAfterPromptCapableProbe(granted: true, skipped: false), .granted)
    }

    /// Prompt-capable denied without skip → notGranted.
    func testPromptCapableDeniedResolvesNotGranted() {
        XCTAssertEqual(ScreenRecordingPermissionDecision.resolveAfterPromptCapableProbe(granted: false, skipped: false), .notGranted)
    }

    /// Prompt-capable denied with skip → skipped.
    func testPromptCapableDeniedWithSkipResolvesSkipped() {
        XCTAssertEqual(ScreenRecordingPermissionDecision.resolveAfterPromptCapableProbe(granted: false, skipped: true), .skipped)
    }
}
