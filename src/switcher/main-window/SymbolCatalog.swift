import AppKit

enum SymbolFallback: Equatable {
    case asset(String)
    case circledStar
    case filledCircledStar
    case filledMinusCircle
}

enum Symbols: String, CaseIterable {
    case circledPlusSign
    case circledMinusSign
    case circledSlashSign
    case circledStar
    case filledCircledStar
    case circledInfo
    case paintpalette
    case command
    case gearshape
    case handRaised
    case link
    case arrowTriangleBranch
    case accessibility
    case display
    case plus
    case minus
    case minusCircleFill
    case cursorarrowRays
    case pauseRectangle
    case magnifyingglass
    case moonphaseWaningGibbousInverse
    case moonphaseLastQuarterInverse
    case moonphaseWaningCrescentInverse
    case sparkles
    case sunMax
    case moonFill
    case laptopcomputer

    var systemName: String {
        switch self {
        case .circledPlusSign: return "plus.circle"
        case .circledMinusSign: return "minus.circle"
        case .circledSlashSign: return "circle.slash"
        case .circledStar: return "star.circle"
        case .filledCircledStar: return "star.circle.fill"
        case .circledInfo: return "info.circle"
        case .paintpalette: return "paintpalette"
        case .command: return "command"
        case .gearshape: return "gearshape"
        case .handRaised: return "hand.raised"
        case .link: return "link"
        case .arrowTriangleBranch: return "arrow.triangle.branch"
        case .accessibility: return "accessibility"
        case .display: return "display"
        case .plus: return "plus"
        case .minus: return "minus"
        case .minusCircleFill: return "minus.circle.fill"
        case .cursorarrowRays: return "cursorarrow.rays"
        case .pauseRectangle: return "pause.rectangle"
        case .magnifyingglass: return "magnifyingglass"
        case .moonphaseWaningGibbousInverse: return "moonphase.waning.gibbous.inverse"
        case .moonphaseLastQuarterInverse: return "moonphase.last.quarter.inverse"
        case .moonphaseWaningCrescentInverse: return "moonphase.waning.crescent.inverse"
        case .sparkles: return "sparkles"
        case .sunMax: return "sun.max"
        case .moonFill: return "moon.fill"
        case .laptopcomputer: return "laptopcomputer"
        }
    }

    var fallback: SymbolFallback {
        switch self {
        case .circledPlusSign: return .asset("circle-plus")
        case .circledMinusSign: return .asset("circle-minus")
        case .circledSlashSign: return .asset("circle-off")
        case .circledStar: return .circledStar
        case .filledCircledStar: return .filledCircledStar
        case .circledInfo: return .asset("info-circle")
        case .paintpalette: return .asset("palette")
        case .command: return .asset("command")
        case .gearshape: return .asset("settings")
        case .handRaised: return .asset("hand-stop")
        case .link: return .asset("link")
        case .arrowTriangleBranch: return .asset("git-branch")
        case .accessibility: return .asset("accessible")
        case .display: return .asset("device-desktop")
        case .plus: return .asset("plus")
        case .minus: return .asset("minus")
        case .minusCircleFill: return .filledMinusCircle
        case .cursorarrowRays: return .asset("pointer")
        case .pauseRectangle: return .asset("player-pause")
        case .magnifyingglass: return .asset("search")
        case .moonphaseWaningGibbousInverse: return .asset("moon")
        case .moonphaseLastQuarterInverse: return .asset("moon-2")
        case .moonphaseWaningCrescentInverse: return .asset("moon-stars")
        case .sparkles: return .asset("twinkle")
        case .sunMax: return .asset("sun")
        case .moonFill: return .asset("moon-filled")
        case .laptopcomputer: return .asset("device-laptop")
        }
    }

    var fallbackAssetName: String? {
        guard case let .asset(name) = fallback else { return nil }
        return name
    }
}

enum SymbolImages {
    typealias AssetLoader = (String) -> NSImage?
    static let validSpaceNumbers = 0 ... 19

    static func image(
        for symbol: Symbols,
        pointSize: CGFloat,
        preferSystemSymbols: Bool = true,
        bundle: Bundle = .main
    ) -> NSImage {
        image(
            for: symbol,
            pointSize: pointSize,
            preferSystemSymbols: preferSystemSymbols,
            assetLoader: { asset(named: $0, bundle: bundle) }
        )
    }

    static func image(
        for symbol: Symbols,
        pointSize: CGFloat,
        preferSystemSymbols: Bool,
        assetLoader: AssetLoader
    ) -> NSImage {
        let size = max(1, pointSize)
        if preferSystemSymbols, #available(macOS 11.0, *), let native = NSImage(
            systemSymbolName: symbol.systemName,
            accessibilityDescription: nil
        ) {
            return scaledTemplate(native, pointSize: size)
        }
        switch symbol.fallback {
        case let .asset(assetName):
            guard let fallback = assetLoader(assetName) else { return missingSymbol(pointSize: size) }
            return scaledTemplate(fallback, pointSize: size)
        case .circledStar: return circledStar(pointSize: size)
        case .filledCircledStar: return filledCircle(pointSize: size, cutout: .star)
        case .filledMinusCircle: return filledCircle(pointSize: size, cutout: .minus)
        }
    }

    static func spaceNumber(_ number: Int, pointSize: CGFloat) -> NSImage {
        let size = max(1, pointSize)
        guard validSpaceNumbers.contains(number) else { return missingSymbol(pointSize: size) }
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setStroke()
            let lineWidth = max(1, size * 0.085)
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: lineWidth, dy: lineWidth))
            circle.lineWidth = lineWidth
            circle.stroke()
            let fontSize = size * (number < 10 ? 0.48 : 0.38)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.black,
            ]
            let text = String(number) as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func asset(named name: String, bundle: Bundle) -> NSImage? {
        guard let url = bundle.url(forResource: name, withExtension: "pdf", subdirectory: "symbols")
        else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func scaledTemplate(_ source: NSImage, pointSize: CGFloat) -> NSImage {
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return missingSymbol(pointSize: pointSize) }
        let scale = pointSize / max(sourceSize.width, sourceSize.height)
        let size = NSSize(width: ceil(sourceSize.width * scale), height: ceil(sourceSize.height * scale))
        let image = NSImage(size: size, flipped: false) { rect in
            source.draw(
                in: rect,
                from: NSRect(origin: .zero, size: sourceSize),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func circledStar(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let lineWidth = max(1, pointSize * 0.075)
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: lineWidth, dy: lineWidth))
            circle.lineWidth = lineWidth
            circle.stroke()
            let star = starPath(
                center: NSPoint(x: rect.midX, y: rect.midY),
                outerRadius: pointSize * 0.27,
                innerRadius: pointSize * 0.12
            )
            star.lineWidth = lineWidth
            star.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private enum CircleCutout {
        case star
        case minus
    }

    private static func filledCircle(pointSize: CGFloat, cutout: CircleCutout) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            let margin = max(1, pointSize * 0.075)
            let path = NSBezierPath()
            path.windingRule = .evenOdd
            path.appendOval(in: rect.insetBy(dx: margin, dy: margin))
            switch cutout {
            case .star:
                path.append(starPath(
                    center: NSPoint(x: rect.midX, y: rect.midY),
                    outerRadius: pointSize * 0.27,
                    innerRadius: pointSize * 0.12
                ))
            case .minus:
                let cutoutRect = NSRect(
                    x: rect.midX - pointSize * 0.22,
                    y: rect.midY - pointSize * 0.055,
                    width: pointSize * 0.44,
                    height: pointSize * 0.11
                )
                path.append(NSBezierPath(
                    roundedRect: cutoutRect,
                    xRadius: cutoutRect.height / 2,
                    yRadius: cutoutRect.height / 2
                ))
            }
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func starPath(center: NSPoint, outerRadius: CGFloat,
                                 innerRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for pointIndex in 0 ..< 10 {
            let radius = pointIndex.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(pointIndex) * .pi / 5 - .pi / 2
            let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            pointIndex == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        return path
    }

    private static func missingSymbol(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            NSColor.black.setStroke()
            let lineWidth = max(1, pointSize * 0.075)
            let outline = NSBezierPath(
                roundedRect: rect.insetBy(dx: lineWidth, dy: lineWidth),
                xRadius: pointSize * 0.2,
                yRadius: pointSize * 0.2
            )
            outline.lineWidth = lineWidth
            outline.stroke()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: pointSize * 0.55, weight: .semibold),
                .foregroundColor: NSColor.black,
            ]
            let text = "?" as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
