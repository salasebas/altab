import AppKit
import XCTest

final class SymbolCatalogTests: XCTestCase {
    func testEverySymbolHasAUniqueSystemNameAndVisibleFallback() {
        let bundle = Bundle(for: SymbolCatalogTests.self)
        let systemNames = Symbols.allCases.map(\.systemName)
        XCTAssertEqual(Set(systemNames).count, systemNames.count)
        for symbol in Symbols.allCases {
            XCTAssertFalse(symbol.systemName.isEmpty, symbol.rawValue)
            if case let .asset(name) = symbol.fallback {
                XCTAssertFalse(name.isEmpty, symbol.rawValue)
            }
            let image = SymbolImages.image(
                for: symbol,
                pointSize: 28,
                preferSystemSymbols: false,
                assetLoader: { self.asset(named: $0, bundle: bundle) }
            )
            XCTAssertNotNil(visibleBounds(image, canvasSize: 112), symbol.rawValue)
        }
    }

    func testEveryCatalogAssetIsBundledAsVectorPdf() throws {
        let bundle = Bundle(for: SymbolCatalogTests.self)
        let assetNames = Set(Symbols.allCases.compactMap(\.fallbackAssetName))
        XCTAssertFalse(assetNames.isEmpty)
        for name in assetNames {
            let url = try XCTUnwrap(
                bundle.url(forResource: name, withExtension: "pdf", subdirectory: "symbols"),
                name
            )
            XCTAssertEqual(try Data(contentsOf: url).prefix(4), Data("%PDF".utf8), name)
        }
    }

    func testSpaceNumbersRenderAtRepresentativeSizes() {
        XCTAssertEqual(SymbolImages.validSpaceNumbers, 0 ... 19)
        for number in SymbolImages.validSpaceNumbers {
            for size in [CGFloat(11), 13, 18, 28] {
                let image = SymbolImages.spaceNumber(number, pointSize: size)
                XCTAssertNotNil(
                    visibleBounds(image, canvasSize: Int(size * 4)),
                    "space \(number) at \(size)pt"
                )
            }
        }
    }

    func testOutOfRangeSpaceNumberUsesVisibleFallback() {
        for number in [-1, 20] {
            XCTAssertNotNil(visibleBounds(SymbolImages.spaceNumber(number, pointSize: 18), canvasSize: 72))
        }
    }

    func testMissingAssetUsesAnExplicitVisibleFallback() {
        let image = SymbolImages.image(
            for: .plus,
            pointSize: 18,
            preferSystemSymbols: false,
            assetLoader: { _ in nil }
        )
        XCTAssertNotNil(visibleBounds(image, canvasSize: 72))
    }

    func testFilledFallbacksPreserveTheirCenterCutout() throws {
        for symbol in [Symbols.filledCircledStar, .minusCircleFill] {
            let image = SymbolImages.image(
                for: symbol,
                pointSize: 18,
                preferSystemSymbols: false,
                assetLoader: { _ in nil }
            )
            let bitmap = try XCTUnwrap(renderedBitmap(image, canvasSize: 72))
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 36, y: 36)).alphaComponent, 0.05)
            XCTAssertNotNil(visibleBounds(image, canvasSize: 72))
        }
    }

    private func asset(named name: String, bundle: Bundle) -> NSImage? {
        guard let url = bundle.url(forResource: name, withExtension: "pdf", subdirectory: "symbols")
        else { return nil }
        return NSImage(contentsOf: url)
    }

    private func visibleBounds(_ image: NSImage, canvasSize: Int) -> CGRect? {
        guard let bitmap = renderedBitmap(image, canvasSize: canvasSize) else { return nil }
        var bounds: CGRect?
        for y in 0 ..< canvasSize {
            for x in 0 ..< canvasSize where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
                bounds = bounds?.union(CGRect(x: x, y: y, width: 1, height: 1)) ?? CGRect(
                    x: x,
                    y: y,
                    width: 1,
                    height: 1
                )
            }
        }
        return bounds
    }

    private func renderedBitmap(_ image: NSImage, canvasSize: Int) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvasSize,
            pixelsHigh: canvasSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = NSSize(width: canvasSize, height: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
        image.draw(
            in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize),
            from: CGRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}
