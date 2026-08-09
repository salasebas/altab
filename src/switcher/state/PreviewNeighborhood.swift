import Foundation

/// Pure selection of which windows deserve a just-in-time full-resolution Preview capture (#5861 /
/// issue #45). Returns the selected window plus up to `radius` **displayed** neighbors on each side
/// in cycling order (wrapping like Tab). Hidden / filtered-out windows are skipped so the
/// neighborhood always matches what the user can Tab onto.
enum PreviewNeighborhood {
    static let defaultRadius = 2

    /// `windowIds` and `isDisplayed` are parallel arrays over the switcher's `Windows.list` order.
    /// Missing ids (`nil`) are omitted from the result set but still consume a list index.
    static func ids(
        selectedIndex: Int,
        windowIds: [UInt32?],
        isDisplayed: [Bool],
        radius: Int = defaultRadius
    ) -> Set<UInt32> {
        let count = windowIds.count
        guard count > 0, selectedIndex >= 0, selectedIndex < count,
              isDisplayed.count == count else { return [] }
        var ids = Set<UInt32>()
        if let wid = windowIds[selectedIndex] {
            ids.insert(wid)
        }
        for step in [1, -1] {
            var index = selectedIndex
            var found = 0
            var iterations = 0
            while found < radius && iterations < count {
                index = (index + step + count) % count
                iterations += 1
                if isDisplayed[index] {
                    found += 1
                    if let wid = windowIds[index] {
                        ids.insert(wid)
                    }
                }
            }
        }
        return ids
    }
}
