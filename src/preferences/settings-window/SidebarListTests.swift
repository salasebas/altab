import XCTest
import Cocoa

/// Coverage for `SidebarListRow`'s recycled content.
///
/// (`SidebarListRow` compiles into the test target: the deployment target is 10.13 — same as the
/// app — and `_test-support/Mocks.swift` stubs the few app-only symbols it touches,
/// `SettingsWindow.contentWidth` and `SettingsSearchIndex`.)
final class SidebarListTests: XCTestCase {
    func testSetContentBuildsTooltipFromTitleAndSummary() {
        let row = SidebarListRow()
        row.setContent("Shortcut 2", "Option + Tab")
        XCTAssertEqual(row.toolTip, "Shortcut 2\nOption + Tab")
    }

    func testSetSummaryRefreshesTooltipWithoutReplacingTitle() {
        let row = SidebarListRow()
        row.setContent("Shortcut 3", "Control + Space")
        row.setSummary("Command + Space")
        XCTAssertEqual(row.toolTip, "Shortcut 3\nCommand + Space")
        row.setSummary("")
        XCTAssertEqual(row.toolTip, "Shortcut 3")
    }
}
