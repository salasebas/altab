import Foundation

/// Pure LRU bookkeeping for session-scoped full-resolution Preview frames (#5861 / issue #45).
/// Keys are `CGWindowID` raw values (`UInt32`) so this stays free of AppKit and unit-testable.
/// Production wires storage in `SwitcherSession`; eviction drops the least-recently-used entry.
enum PreviewFrameLru {
    static let maxEntries = 10

    /// Record access or store of `wid` (most recently used last). Duplicates are removed first.
    static func touch(_ wid: UInt32, order: [UInt32]) -> [UInt32] {
        var next = order.filter { $0 != wid }
        next.append(wid)
        return next
    }

    /// If `order` exceeds `maxEntries`, drop the least-recently-used (first) entry.
    static func evictIfNeeded(order: [UInt32],
                              maxEntries: Int = maxEntries) -> (order: [UInt32], evicted: UInt32?) {
        guard order.count > maxEntries else { return (order, nil) }
        var next = order
        let evicted = next.removeFirst()
        return (next, evicted)
    }

    /// Store bookkeeping: touch then evict if over capacity. Returns new order and optional eviction.
    static func afterStore(_ wid: UInt32, order: [UInt32],
                           maxEntries: Int = maxEntries) -> (order: [UInt32], evicted: UInt32?) {
        evictIfNeeded(order: touch(wid, order: order), maxEntries: maxEntries)
    }
}
