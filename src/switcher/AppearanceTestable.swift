import Foundation

struct TileGridPlacement {
    let origin: CGPoint
    let startsNewRow: Bool
}

struct TileGridLayout {
    let widthMax: CGFloat
    let tileHeight: CGFloat
    let spacing: CGFloat
    let isLeftToRight: Bool
    private(set) var currentX: CGFloat
    private(set) var currentY: CGFloat
    private(set) var maxX = CGFloat(0)
    private(set) var maxY: CGFloat

    init(widthMax: CGFloat, tileHeight: CGFloat, spacing: CGFloat, isLeftToRight: Bool) {
        self.widthMax = widthMax
        self.tileHeight = tileHeight
        self.spacing = spacing
        self.isLeftToRight = isLeftToRight
        currentX = TileGridGeometry.startingX(widthMax, spacing, isLeftToRight)
        currentY = spacing
        maxY = spacing + tileHeight + spacing
    }

    mutating func place(_ width: CGFloat) -> TileGridPlacement {
        var projectedX = TileGridGeometry.projectedX(currentX, width, spacing, isLeftToRight).rounded(.down)
        let startsNewRow = TileGridGeometry.needsNewRow(projectedX, widthMax, isLeftToRight)
        if startsNewRow {
            currentX = TileGridGeometry.startingX(widthMax, spacing, isLeftToRight)
            currentY = (currentY + tileHeight + spacing).rounded(.down)
            projectedX = TileGridGeometry.projectedX(currentX, width, spacing, isLeftToRight).rounded(.down)
            maxY = max(currentY + tileHeight + spacing, maxY)
        }
        let origin = CGPoint(x: TileGridGeometry.originX(currentX, width, isLeftToRight), y: currentY)
        currentX = projectedX
        maxX = max(isLeftToRight ? currentX : widthMax - currentX, maxX)
        return TileGridPlacement(origin: origin, startsNewRow: startsNewRow)
    }
}

enum TileGridGeometry {
    static func startingX(_ widthMax: CGFloat, _ spacing: CGFloat, _ isLeftToRight: Bool) -> CGFloat {
        isLeftToRight ? spacing : widthMax - spacing
    }

    static func projectedX(_ currentX: CGFloat, _ width: CGFloat, _ spacing: CGFloat, _ isLeftToRight: Bool) -> CGFloat {
        isLeftToRight ? currentX + width + spacing : currentX - width - spacing
    }

    static func needsNewRow(_ projectedX: CGFloat, _ widthMax: CGFloat, _ isLeftToRight: Bool) -> Bool {
        isLeftToRight ? projectedX > widthMax : projectedX < 0
    }

    static func originX(_ currentX: CGFloat, _ width: CGFloat, _ isLeftToRight: Bool) -> CGFloat {
        isLeftToRight ? currentX : currentX - width
    }

    static func rowWidth(_ widths: [CGFloat], _ spacing: CGFloat) -> CGFloat {
        spacing + widths.reduce(CGFloat(0)) { $0 + $1 + spacing }
    }

    static func targetFrame(_ frame: CGRect, _ spacing: CGFloat, _ isLeftToRight: Bool) -> CGRect {
        CGRect(x: frame.minX - (isLeftToRight ? 0 : spacing), y: frame.minY, width: frame.width + spacing, height: frame.height + spacing)
    }

    static func documentOffsetX(_ widthMax: CGFloat, _ documentWidth: CGFloat, _ isLeftToRight: Bool) -> CGFloat {
        isLeftToRight ? 0 : max(0, widthMax - documentWidth)
    }
}

class AppearanceTestable {
    static func interCellPadding(_ style: AppearanceStylePreference, _ selectedSpacing: CGFloat) -> CGFloat {
        style == .titles ? 1 : selectedSpacing
    }

    /// How wide should the TilesPanel be, for comfortable viewing?
    /// * a comfortable field-of-view is 50-60 degrees
    /// * people sit at various distances from the screen. We can't know how far they sit
    /// * most people will seat far enough so that they can view the whole width of the screen
    /// * some people use wide-screen or TV monitors. Those people tend to be too close to the screen, since they need to use keyboard and mouse on their desk
    /// Let's use this heuristic: let's assume that people can view 60cm comfortably. Bigger screens can only show parts of AltTab
    /// Let's clamp at 90% like Windows 11
    /// Let's clamp at 45% (value for the biggest, 60" screens)
    static func comfortableWidth(_ physicalWidth: Double?) -> Double {
        if let physicalWidth {
            return min(0.9, max(0.45, 600.0 / physicalWidth))
        }
        return 0.9
    }

    // calculate windowMinWidthInRow and windowMaxWidthInRow such that:
    // * fullscreen windows fill their tile vertically
    // * narrow windows have enough width that a few words can be read from their title
    static func goodValuesForThumbnailsWidthMinMax(_ aspectRatio: CGFloat, _ rowsCount: CGFloat) -> (CGFloat, CGFloat) {
        let minRatio: CGFloat
        let maxRatio: CGFloat
        if aspectRatio >= 1 {
            minRatio = 0.7 / (aspectRatio * rowsCount)
            maxRatio = 1.5 / (aspectRatio * rowsCount)
        } else {
            minRatio = 1.3 / rowsCount
            maxRatio = 2.1 / rowsCount
        }
        // Make sure the values are clamped between some reasonable bounds
        return (max(0.09, minRatio), min(0.30, maxRatio))
    }

    /// Returns the horizontal origins that place a packed row at its semantic leading, center, or
    /// trailing edge. The input frames may be anchored to a wider packing area than the final
    /// container (as happens in RTL), so the result is derived from the row's actual bounds.
    static func alignedRowOrigins(_ frames: [CGRect], _ containerWidth: CGFloat, _ edgePadding: CGFloat, _ alignment: RowAlignmentPreference, _ isLeftToRight: Bool) -> [CGFloat] {
        guard let rowMinX = frames.map(\.minX).min(), let rowMaxX = frames.map(\.maxX).max() else { return [] }
        let rowWidth = rowMaxX - rowMinX
        let freeWidth = max(0, containerWidth - edgePadding * 2 - rowWidth)
        let factor: CGFloat
        switch alignment {
            case .leading: factor = isLeftToRight ? 0 : 1
            case .center: factor = 0.5
            case .trailing: factor = isLeftToRight ? 1 : 0
        }
        let targetMinX = edgePadding + (freeWidth * factor).rounded()
        let offset = targetMinX - rowMinX
        return frames.map { $0.minX + offset }
    }
}
