import XCTest

/// Pins session Preview-frame LRU bookkeeping as pure, deterministic order operations — no AppKit
/// or capture. Production wires these in `SwitcherSession` (see issue #45 / upstream #5861).
final class PreviewFrameLruTests: XCTestCase {
    // MARK: - Touch / order

    /// Empty order + touch → single-element order ending with wid.
    func testTouchAppendsWhenAbsent() {
        XCTAssertEqual(PreviewFrameLru.touch(7, order: []), [7])
    }

    /// Touch a middle wid → it becomes last; length unchanged.
    func testTouchMovesExistingToMostRecent() {
        XCTAssertEqual(PreviewFrameLru.touch(2, order: [1, 2, 3]), [1, 3, 2])
    }

    /// Touch the same wid twice → still one entry.
    func testTouchDoesNotDuplicate() {
        let once = PreviewFrameLru.touch(5, order: [5])
        XCTAssertEqual(PreviewFrameLru.touch(5, order: once), [5])
    }

    // MARK: - Eviction

    /// count ≤ max → no eviction.
    func testEvictIfNeededUnderCapacityReturnsNil() {
        let order = Array(UInt32(1) ... UInt32(PreviewFrameLru.maxEntries))
        let result = PreviewFrameLru.evictIfNeeded(order: order)
        XCTAssertEqual(result.order, order)
        XCTAssertNil(result.evicted)
    }

    /// count > max → first (oldest) is evicted.
    func testEvictIfNeededOverCapacityDropsOldest() {
        let order = Array(UInt32(1) ... UInt32(PreviewFrameLru.maxEntries + 1))
        let result = PreviewFrameLru.evictIfNeeded(order: order)
        XCTAssertEqual(result.evicted, 1)
        XCTAssertEqual(result.order, Array(UInt32(2) ... UInt32(PreviewFrameLru.maxEntries + 1)))
    }

    /// Filling past max returns the least-recently-used wid.
    func testAfterStoreEvictsWhenOverCapacity() {
        let order = Array(UInt32(1) ... UInt32(PreviewFrameLru.maxEntries))
        let result = PreviewFrameLru.afterStore(UInt32(PreviewFrameLru.maxEntries + 1), order: order)
        XCTAssertEqual(result.evicted, 1)
        XCTAssertEqual(result.order.last, UInt32(PreviewFrameLru.maxEntries + 1))
        XCTAssertEqual(result.order.count, PreviewFrameLru.maxEntries)
    }

    /// Re-storing a wid already present does not grow order.
    func testAfterStoreRestoresOrderOnRestoredWid() {
        let order = Array(UInt32(1) ... UInt32(PreviewFrameLru.maxEntries))
        let result = PreviewFrameLru.afterStore(1, order: order)
        XCTAssertNil(result.evicted)
        XCTAssertEqual(result.order.count, PreviewFrameLru.maxEntries)
        XCTAssertEqual(result.order.last, 1)
    }
}
