import Cocoa

class TileFontIconView: NSView {
    enum Rendering {
        case symbol
        case badge
    }

    struct SymbolCacheKey: Hashable {
        var symbol: String
        var size: CGFloat
        var colorKey: String
    }

    private struct BadgeSizing {
        static let containerFromIconRatio = CGFloat(0.43)
        static let textFromContainerRatio = CGFloat(0.57)
        static let minContainerHeight = CGFloat(11)
        static let minTextHeight = CGFloat(8)
        static let maxTextHeight = CGFloat(18)
        static let horizontalPaddingRatio = CGFloat(0.10)
        static let minHorizontalPadding = CGFloat(2)
        static let appIconsMinRectWidthRatio = CGFloat(1.35)
        static let maxDigits = 4
    }

    private struct BadgeMetrics {
        let containerHeight: CGFloat
        let textHeight: CGFloat
    }

    static var symbolCache = [SymbolCacheKey: NSImage]()

    static func badgeBaseSize(forIconSize iconSize: CGFloat) -> CGFloat {
        max((iconSize * BadgeSizing.containerFromIconRatio).rounded(), BadgeSizing.minContainerHeight)
    }

    private let rendering: Rendering
    private let symbolSize: CGFloat
    private let symbolColor: NSColor
    private let badgeFillColor: NSColor
    private let badgeTextColor: NSColor
    private let badgeFont: NSFont
    private let badgeContainerHeight: CGFloat
    private let badgeHorizontalPadding: CGFloat
    private var text = ""
    private var symbol: Symbols?
    private var cachedSymbolImage: NSImage?
    private var cachedBadgeAttributedString: NSAttributedString?
    private var cachedBadgeTextSize = NSSize.zero

    convenience init(symbol: Symbols, tooltip: String? = nil, size: CGFloat = Appearance.fontHeight, color: NSColor = Appearance.fontColor) {
        self.init(rendering: .symbol, initialSymbol: symbol, initialText: "", size: size, symbolColor: color, badgeFillColor: .clear, badgeTextColor: .clear)
        toolTip = tooltip
        frame.size = symbolSizeForCurrentImage()
    }

    convenience init(badgeSize: CGFloat,
                     fillColor: NSColor = NSColor(srgbRed: 1, green: 0.25, blue: 0.2, alpha: 0.9),
                     textColor: NSColor = .white) {
        self.init(rendering: .badge, initialSymbol: nil, initialText: "0", size: badgeSize, symbolColor: .clear, badgeFillColor: fillColor, badgeTextColor: textColor)
        frame.size = badgeFrameSize(textWidth: maxBadgeTextWidth(), text: String(repeating: "8", count: BadgeSizing.maxDigits))
    }

    init(rendering: Rendering,
         initialSymbol: Symbols?,
         initialText: String,
         size: CGFloat,
         symbolColor: NSColor,
         badgeFillColor: NSColor,
         badgeTextColor: NSColor) {
        self.rendering = rendering
        self.symbolSize = size
        self.symbolColor = symbolColor
        self.badgeFillColor = badgeFillColor
        self.badgeTextColor = badgeTextColor
        let badgeMetrics = Self.badgeMetrics(size)
        badgeContainerHeight = badgeMetrics.containerHeight
        badgeHorizontalPadding = Self.badgeHorizontalPadding(badgeMetrics.containerHeight)
        badgeFont = NSFont.systemFont(ofSize: badgeMetrics.textHeight)
        text = initialText
        symbol = initialSymbol
        super.init(frame: .zero)
        cachedSymbolImage = initialSymbol.map { Self.cachedImage(for: $0, size: size, color: symbolColor) }
        if rendering == .badge {
            cachedBadgeAttributedString = badgeAttributedText(initialText)
            cachedBadgeTextSize = cachedBadgeAttributedString!.size()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var isOpaque: Bool { false }
    override var intrinsicContentSize: NSSize { frame.size }

    static func warmCaches(symbols: [Symbols], spaceNumbers: [Int] = [], size: CGFloat, color: NSColor) {
        for symbol in symbols { _ = cachedImage(for: symbol, size: size, color: color) }
        for number in spaceNumbers { _ = cachedSpaceNumberImage(number, size: size, color: color) }
    }

    func setText(_ text: String) {
        guard text.count <= 4 && rendering == .badge else { setFilledStar(); return }
        replaceTextIfNeeded(text)
    }

    func setStar() {
        setStarLike(false)
    }

    func setFilledStar() {
        setStarLike(true)
    }

    override func draw(_ dirtyRect: NSRect) {
        if rendering == .badge {
            drawBadge()
        } else {
            drawSymbol()
        }
    }

    private func setStarLike(_ filled: Bool) {
        guard rendering == .symbol else { replaceTextIfNeeded(""); return }
        let newSymbol = filled ? Symbols.filledCircledStar : Symbols.circledStar
        guard symbol != newSymbol else { return }
        symbol = newSymbol
        cachedSymbolImage = Self.cachedImage(for: newSymbol, size: symbolSize, color: symbolColor)
        frame.size = symbolSizeForCurrentImage()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private func replaceTextIfNeeded(_ newText: String) {
        guard newText != text else { return }
        text = newText
        if rendering == .badge {
            cachedBadgeAttributedString = badgeAttributedText(newText)
            cachedBadgeTextSize = cachedBadgeAttributedString!.size()
        }
        needsDisplay = true
    }

    private func drawSymbol() {
        cachedSymbolImage?.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private func drawBadge() {
        let badgeRect = anchoredBadgeRect()
        let innerRect = badgeRect
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerRect.height / 2, yRadius: innerRect.height / 2)
        badgeFillColor.setFill()
        innerPath.fill()
        guard let cachedBadgeAttributedString else { return }
        let textSize = cachedBadgeTextSize
        let textPoint = NSPoint(x: innerRect.midX - textSize.width / 2, y: innerRect.midY - textSize.height / 2)
        cachedBadgeAttributedString.draw(at: textPoint)
    }

    private func anchoredBadgeRect() -> NSRect {
        let size = badgeFrameSize(textWidth: cachedBadgeTextSize.width, text: text)
        return NSRect(x: (frame.width - size.width).rounded(), y: 0, width: size.width, height: size.height)
    }

    private func symbolSizeForCurrentImage() -> NSSize {
        cachedSymbolImage?.size ?? .zero
    }

    private func badgeFrameSize(textWidth: CGFloat, text: String) -> NSSize {
        let height = badgeContainerHeight
        var width = max(height, textWidth + badgeHorizontalPadding * 2)
        if Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .appIcons, text.count > 1 {
            let minRectWidth = (height * BadgeSizing.appIconsMinRectWidthRatio).rounded(.up)
            width = max(width, minRectWidth)
        }
        return NSSize(width: ceil(width), height: ceil(height))
    }

    private func badgeAttributedText(_ value: String) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [.font: badgeFont, .foregroundColor: badgeTextColor])
    }

    private func badgeTextWidth(_ value: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: badgeFont]
        return NSAttributedString(string: value, attributes: attrs).size().width
    }

    private static func badgeHorizontalPadding(_ height: CGFloat) -> CGFloat {
        max(BadgeSizing.minHorizontalPadding, (height * BadgeSizing.horizontalPaddingRatio).rounded())
    }

    private func maxBadgeTextWidth() -> CGFloat {
        badgeTextWidth(String(repeating: "8", count: BadgeSizing.maxDigits))
    }

    private static func badgeMetrics(_ size: CGFloat) -> BadgeMetrics {
        let rawContainerHeight = max(BadgeSizing.minContainerHeight, size.rounded())
        let textHeight = badgeTextHeight(fromRawContainerHeight: rawContainerHeight)
        let compactContainerHeight = (textHeight / BadgeSizing.textFromContainerRatio).rounded(.up)
        let containerHeight = max(BadgeSizing.minContainerHeight, min(rawContainerHeight, compactContainerHeight))
        return BadgeMetrics(containerHeight: containerHeight, textHeight: textHeight)
    }

    private static func badgeTextHeight(fromRawContainerHeight rawContainerHeight: CGFloat) -> CGFloat {
        min(max((rawContainerHeight * BadgeSizing.textFromContainerRatio).rounded(), BadgeSizing.minTextHeight), BadgeSizing.maxTextHeight)
    }

    static func cachedImage(for symbol: Symbols, size: CGFloat, color: NSColor) -> NSImage {
        cachedImage(identifier: symbol.rawValue, size: size, color: color) {
            SymbolImages.image(for: symbol, pointSize: renderPointSize(size))
        }
    }

    static func cachedSpaceNumberImage(_ number: Int, size: CGFloat, color: NSColor) -> NSImage {
        cachedImage(identifier: "space:\(number)", size: size, color: color) {
            SymbolImages.spaceNumber(number, pointSize: renderPointSize(size))
        }
    }

    private static func cachedImage(identifier: String, size: CGFloat, color: NSColor, makeTemplate: () -> NSImage) -> NSImage {
        let key = SymbolCacheKey(symbol: identifier, size: size, colorKey: symbolColorKey(color))
        if let cached = symbolCache[key] { return cached }
        let image = makeTemplate().tinted(color)
        symbolCache[key] = image
        return image
    }

    private static func renderPointSize(_ size: CGFloat) -> CGFloat {
        (size * 0.85).rounded()
    }

    static func symbolColorKey(_ color: NSColor) -> String {
        (color.usingColorSpace(.deviceRGB) ?? color).description
    }
}
