import AppKit
import XCTest

final class BrandAssetsTests: XCTestCase {
    func testMenubarIconOpticalCoverage() throws {
        let bundle = Bundle(for: BrandAssetsTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "menubar-0", withExtension: "pdf"))
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        let canvasSize = 180
        let bounds = try XCTUnwrap(visibleBounds(image, canvasSize))
        let horizontalCoverage = bounds.width / CGFloat(canvasSize)
        let verticalCoverage = bounds.height / CGFloat(canvasSize)
        let artworkAspectRatio = bounds.width / bounds.height
        XCTAssertGreaterThanOrEqual(verticalCoverage, 0.75)
        XCTAssertLessThanOrEqual(artworkAspectRatio, 1.15)
        XCTAssertLessThanOrEqual(horizontalCoverage, 0.90)
    }

    private func visibleBounds(_ image: NSImage, _ canvasSize: Int) -> CGRect? {
        guard let bitmap = makeBitmap(canvasSize), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = NSSize(width: canvasSize, height: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
        image.draw(in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize), from: CGRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return visibleBounds(bitmap, canvasSize)
    }

    private func makeBitmap(_ canvasSize: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvasSize, pixelsHigh: canvasSize,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    }

    private func visibleBounds(_ bitmap: NSBitmapImageRep, _ canvasSize: Int) -> CGRect? {
        var minX = canvasSize
        var minY = canvasSize
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasSize {
            for x in 0..<canvasSize where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
