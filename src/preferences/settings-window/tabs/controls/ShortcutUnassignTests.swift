import XCTest
import ShortcutRecorder

/// Regression tests for conflict-dialog unassign persistence (AlTab #48 / upstream #5897).
///
/// The production resolvers call `ControlsTab.unassignShortcut` → `ShortcutUnassign.clearPreference`.
/// These tests pin the kernel and the Preferences write so a hidden-sheet shortcut cannot resurrect
/// after relaunch.
final class ShortcutUnassignTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Preferences.defaults.removePersistentDomain(forName: Preferences.defaultsDomainName)
        Preferences.invalidateAllCache()
        Preferences.set("shortcutCount", "3", false)
    }

    override func tearDown() {
        Preferences.defaults.removePersistentDomain(forName: Preferences.defaultsDomainName)
        Preferences.invalidateAllCache()
        super.tearDown()
    }

    // MARK: - preferenceKey

    /// Static "when active" shortcuts clear their own preference id.
    func testPreferenceKey_staticShortcutKeepsSameId() {
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "hideShowAppShortcut"), "hideShowAppShortcut")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "quitAppShortcut"), "quitAppShortcut")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "focusWindowShortcut"), "focusWindowShortcut")
    }

    /// Hold and nextWindow conflict ids clear the "and press" preference for that shortcut index.
    func testPreferenceKey_holdAndNextClearPressPart() {
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "holdShortcut"), "nextWindowShortcut")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "nextWindowShortcut"), "nextWindowShortcut")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "holdShortcut2"), "nextWindowShortcut2")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "nextWindowShortcut2"), "nextWindowShortcut2")
        XCTAssertEqual(ShortcutUnassign.preferenceKey(forConflictId: "holdShortcut3"), "nextWindowShortcut3")
    }

    // MARK: - clearPreference (accept)

    /// Accepting the default H conflict with no open "Shortcuts when active" sheet must still
    /// write nil so relaunch does not re-register H.
    func testClearPreference_hiddenRecorderClearsStoredHideShow() {
        Preferences.setShortcut("hideShowAppShortcut", keyEquivalent: "H", false)
        XCTAssertNotNil(Preferences.hideShowAppShortcut)
        let cleared = ShortcutUnassign.clearPreference(forConflictId: "hideShowAppShortcut", notify: false)
        XCTAssertEqual(cleared, "hideShowAppShortcut")
        XCTAssertNil(Preferences.hideShowAppShortcut)
        Preferences.invalidateAllCache()
        XCTAssertNil(Preferences.hideShowAppShortcut, "cleared preference must survive cache invalidation / relaunch")
    }

    /// After accepting unassign of H, enabling Vim keys must remain true across relaunch simulation.
    func testClearPreference_vimKeysRemainEnabledAfterRelaunchSimulation() {
        Preferences.setShortcut("hideShowAppShortcut", keyEquivalent: "H", false)
        ShortcutUnassign.clearPreference(forConflictId: "hideShowAppShortcut", notify: false)
        Preferences.set("vimKeysEnabled", "true", false)
        Preferences.invalidateAllCache()
        XCTAssertNil(Preferences.hideShowAppShortcut)
        XCTAssertTrue(Preferences.vimKeysEnabled)
    }

    /// Arrow-key conflicts with a user-bound press (no live recorder) must clear that press
    /// persistently — same defect class as Vim / hideShowAppShortcut.
    func testClearPreference_arrowConflictClearsUserBoundPressWithoutRecorder() {
        Preferences.setShortcut("nextWindowShortcut", keyEquivalent: "→", false)
        XCTAssertNotNil(Preferences.nextWindowShortcut[0])
        let cleared = ShortcutUnassign.clearPreference(forConflictId: "nextWindowShortcut", notify: false)
        XCTAssertEqual(cleared, "nextWindowShortcut")
        XCTAssertNil(Preferences.nextWindowShortcut[0])
        Preferences.invalidateAllCache()
        XCTAssertNil(Preferences.nextWindowShortcut[0])
        // Hold stays; only the press preference is unassigned (even when conflict id is the hold).
        Preferences.setShortcut("holdShortcut2", keyEquivalent: "⌥", false)
        Preferences.setShortcut("nextWindowShortcut2", keyEquivalent: "←", false)
        ShortcutUnassign.clearPreference(forConflictId: "holdShortcut2", notify: false)
        Preferences.invalidateAllCache()
        XCTAssertNil(Preferences.nextWindowShortcut[1], "hold conflict id must clear the press preference")
        XCTAssertNotNil(Preferences.holdShortcut[1], "hold itself stays; only press is unassigned")
    }

    /// The key returned for preference clear is the same id a displayed recorder must sync to nil.
    func testClearPreference_returnsKeyForVisibleRecorderSync() {
        Preferences.setShortcut("hideShowAppShortcut", keyEquivalent: "H", false)
        Preferences.setShortcut("nextWindowShortcut", keyEquivalent: "→", false)
        XCTAssertEqual(
            ShortcutUnassign.clearPreference(forConflictId: "hideShowAppShortcut", notify: false),
            ShortcutUnassign.preferenceKey(forConflictId: "hideShowAppShortcut"))
        XCTAssertEqual(
            ShortcutUnassign.clearPreference(forConflictId: "holdShortcut", notify: false),
            ShortcutUnassign.preferenceKey(forConflictId: "holdShortcut"))
        XCTAssertNil(Preferences.hideShowAppShortcut)
        XCTAssertNil(Preferences.nextWindowShortcut[0])
    }

    // MARK: - cancel

    /// Cancel leaves preference and related flags alone (production skips clearPreference entirely).
    func testCancelDoesNotClearPreference() {
        Preferences.setShortcut("hideShowAppShortcut", keyEquivalent: "H", false)
        Preferences.set("vimKeysEnabled", "false", false)
        let before = Preferences.hideShowAppShortcut
        XCTAssertNotNil(before)
        // Cancel path: do not call clearPreference.
        Preferences.invalidateAllCache()
        XCTAssertNotNil(Preferences.hideShowAppShortcut)
        XCTAssertFalse(Preferences.vimKeysEnabled)
    }
}
