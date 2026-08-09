import XCTest

/// Pins just-in-time Preview neighborhood selection as pure, deterministic set membership — no
/// AppKit or capture. Production wires these in `Windows.selectedNeighborhoodIds` (issue #45).
final class PreviewNeighborhoodTests: XCTestCase {
    /// Single displayed window → only its id.
    func testSelectedAloneWhenNoNeighbors() {
        let ids = PreviewNeighborhood.ids(
            selectedIndex: 0,
            windowIds: [10],
            isDisplayed: [true]
        )
        XCTAssertEqual(ids, [10])
    }

    /// Five displayed windows, select middle → selected + ±2 = all five.
    func testIncludesTwoNeighborsEachSide() {
        let ids = PreviewNeighborhood.ids(
            selectedIndex: 2,
            windowIds: [1, 2, 3, 4, 5],
            isDisplayed: [true, true, true, true, true]
        )
        XCTAssertEqual(ids, [1, 2, 3, 4, 5])
    }

    /// Hidden entries between selected and next displayed are skipped.
    func testSkipsHiddenWindows() {
        // list: A(shown), B(hidden), C(shown), D(shown), E(hidden), F(shown)
        // selected C (index 2), radius 1 each side → A (skip B), D
        let ids = PreviewNeighborhood.ids(
            selectedIndex: 2,
            windowIds: [10, 20, 30, 40, 50, 60],
            isDisplayed: [true, false, true, true, false, true],
            radius: 1
        )
        XCTAssertEqual(ids, [10, 30, 40])
    }

    /// Selection at end wraps to start for the forward side.
    func testWrapsAtListBoundary() {
        // [A, B, C] all displayed, select C (2), radius 1 → C + A (forward) + B (backward)
        let ids = PreviewNeighborhood.ids(
            selectedIndex: 2,
            windowIds: [1, 2, 3],
            isDisplayed: [true, true, true],
            radius: 1
        )
        XCTAssertEqual(ids, [1, 2, 3])
    }

    /// Invalid index → empty.
    func testEmptyWhenSelectedIndexOutOfRange() {
        XCTAssertTrue(PreviewNeighborhood.ids(
            selectedIndex: 5,
            windowIds: [1, 2],
            isDisplayed: [true, true]
        ).isEmpty)
        XCTAssertTrue(PreviewNeighborhood.ids(
            selectedIndex: -1,
            windowIds: [1],
            isDisplayed: [true]
        ).isEmpty)
    }

    /// Length mismatch → empty.
    func testMismatchedArraysReturnEmpty() {
        XCTAssertTrue(PreviewNeighborhood.ids(
            selectedIndex: 0,
            windowIds: [1, 2],
            isDisplayed: [true]
        ).isEmpty)
    }

    /// Nil id at selected or neighbor is not in the set.
    func testNilWindowIdsOmitted() {
        let ids = PreviewNeighborhood.ids(
            selectedIndex: 1,
            windowIds: [nil, 20, nil],
            isDisplayed: [true, true, true],
            radius: 1
        )
        XCTAssertEqual(ids, [20])
    }
}
