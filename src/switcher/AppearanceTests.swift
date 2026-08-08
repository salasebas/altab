import XCTest

final class AppearanceTests: XCTestCase {
    func testTileSpacingValuesAreBoundedAndKeepEightPointDefault() {
        XCTAssertEqual(TileSpacingPreference.validRange, 0...16)
        XCTAssertEqual(Preferences.defaultValues["tileSpacingPoints"] as? String, "8")
        XCTAssertEqual(TileSpacingPreference.defaultValue, 8)
        XCTAssertEqual(TileSpacingPreference.clamped(-1), 0)
        XCTAssertEqual(TileSpacingPreference.clamped(17), 16)
    }

    func testTileSpacingAppliesOnlyToGridStyles() {
        for value in TileSpacingPreference.validRange {
            let spacing = CGFloat(value)
            XCTAssertEqual(AppearanceTestable.interCellPadding(.thumbnails, spacing), spacing)
            XCTAssertEqual(AppearanceTestable.interCellPadding(.appIcons, spacing), spacing)
            XCTAssertEqual(AppearanceTestable.interCellPadding(.titles, spacing), 1)
        }
    }

    func testOnePointGridLayoutPreservesLegacyFramesAndWrap() {
        var ltr = TileGridLayout(widthMax: 203, tileHeight: 50, spacing: 1, isLeftToRight: true)
        let ltrPlacements = [100, 100, 100].map { ltr.place(CGFloat($0)) }
        XCTAssertEqual(ltrPlacements.map { $0.origin }, [CGPoint(x: 1, y: 1), CGPoint(x: 102, y: 1), CGPoint(x: 1, y: 52)])
        XCTAssertEqual(ltrPlacements.map { $0.startsNewRow }, [false, false, true])
        XCTAssertEqual(ltr.maxX, 203)
        XCTAssertEqual(ltr.maxY, 103)
        var rtl = TileGridLayout(widthMax: 203, tileHeight: 50, spacing: 1, isLeftToRight: false)
        let rtlPlacements = [100, 100, 100].map { rtl.place(CGFloat($0)) }
        XCTAssertEqual(rtlPlacements.map { $0.origin }, [CGPoint(x: 102, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 102, y: 52)])
        XCTAssertEqual(rtlPlacements.map { $0.startsNewRow }, ltrPlacements.map { $0.startsNewRow })
        XCTAssertEqual(rtl.maxX, ltr.maxX)
        XCTAssertEqual(rtl.maxY, ltr.maxY)
    }

    func testEveryTileSpacingProducesExactGapsWithoutOverlap() {
        for value in TileSpacingPreference.validRange {
            let spacing = CGFloat(value)
            let width = CGFloat(40)
            let height = CGFloat(30)
            let widthMax = width * 2 + spacing * 3
            var layout = TileGridLayout(widthMax: widthMax, tileHeight: height, spacing: spacing, isLeftToRight: true)
            let frames = (0..<3).map { _ -> CGRect in
                let placement = layout.place(width)
                return CGRect(origin: placement.origin, size: CGSize(width: width, height: height))
            }
            XCTAssertEqual(frames[1].minX - frames[0].maxX, spacing)
            XCTAssertEqual(frames[2].minY - frames[0].maxY, spacing)
            XCTAssertFalse(frames[0].intersects(frames[1]))
            XCTAssertFalse(frames[0].intersects(frames[2]))
            XCTAssertEqual(layout.maxY, spacing * 3 + height * 2)
        }
    }

    func testTileGridLayoutMirrorsLTRAndRTLWithinDocumentWidth() {
        for value in TileSpacingPreference.validRange {
            let spacing = CGFloat(value)
            let widthMax = CGFloat(250)
            let widths: [CGFloat] = [40, 55, 35]
            var ltr = TileGridLayout(widthMax: widthMax, tileHeight: 30, spacing: spacing, isLeftToRight: true)
            var rtl = TileGridLayout(widthMax: widthMax, tileHeight: 30, spacing: spacing, isLeftToRight: false)
            let ltrFrames = widths.map { CGRect(origin: ltr.place($0).origin, size: CGSize(width: $0, height: 30)) }
            let rtlFrames = widths.map { CGRect(origin: rtl.place($0).origin, size: CGSize(width: $0, height: 30)) }
            XCTAssertEqual(ltr.maxX, rtl.maxX)
            let rtlOffset = TileGridGeometry.documentOffsetX(widthMax, rtl.maxX, false)
            for index in widths.indices {
                XCTAssertEqual(rtlFrames[index].minX - rtlOffset, ltr.maxX - ltrFrames[index].maxX)
                XCTAssertEqual(rtlFrames[index].minY, ltrFrames[index].minY)
            }
        }
    }

    func testTargetFramesCoverConfiguredGapSymmetrically() {
        let frame = CGRect(x: 20, y: 30, width: 40, height: 50)
        for value in TileSpacingPreference.validRange {
            let spacing = CGFloat(value)
            let ltr = TileGridGeometry.targetFrame(frame, spacing, true)
            let rtl = TileGridGeometry.targetFrame(frame, spacing, false)
            XCTAssertEqual(ltr, CGRect(x: 20, y: 30, width: 40 + spacing, height: 50 + spacing))
            XCTAssertEqual(rtl, CGRect(x: 20 - spacing, y: 30, width: 40 + spacing, height: 50 + spacing))
            if spacing > 0 {
                XCTAssertTrue(ltr.contains(CGPoint(x: frame.maxX + spacing / 2, y: frame.midY)))
                XCTAssertTrue(rtl.contains(CGPoint(x: frame.minX - spacing / 2, y: frame.midY)))
                XCTAssertTrue(ltr.contains(CGPoint(x: frame.midX, y: frame.maxY + spacing / 2)))
            }
        }
    }

    // TODO add 6, 7, 8 rowsCount and reuse vertical screens data from bellow
    func testGoodValuesForThumbnailsWidthMinMax() throws {
        var actual: (CGFloat, CGFloat)
        for (model, (pixelWidth, pixelHeight), _, (expectedHorizontal, _), expectedArray) in screens {
            for (rowCount, expectedMin, expectedMax) in expectedArray {
                actual = AppearanceTestable.goodValuesForThumbnailsWidthMinMax((pixelWidth * expectedHorizontal) / (pixelHeight * 0.8), CGFloat(rowCount))
                XCTAssertEqual(actual.0, expectedMin, accuracy: 0.01, model)
                XCTAssertEqual(actual.1, expectedMax, accuracy: 0.01, model)
            }
        }
    }


    func testComfortableWidth() throws {
        var actual: Double
        for (model, _, (physicalWidth, physicalHeight), (expectedHorizontal, expectedVertical), _) in screens {
            // screen used horizontally
            actual = AppearanceTestable.comfortableWidth(physicalWidth)
            XCTAssertEqual(actual, expectedHorizontal, accuracy: 0.01, model)
            // screen used vertically
            actual = AppearanceTestable.comfortableWidth(physicalHeight)
            XCTAssertEqual(actual, expectedVertical, accuracy: 0.01, model)
        }

    }

    /// Screens that don't report their physical dimensions (`physicalWidth == nil`) get the 0.9
    /// default — the same clamp Windows 11 uses. Without this, ultrawides would fall to 0.45 just
    /// because we lack the data, which is worse than picking a sane default.
    func testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil() throws {
        XCTAssertEqual(AppearanceTestable.comfortableWidth(nil), 0.9)
    }

    /// Portrait-oriented usage (aspectRatio < 1) takes the second formula branch with different
    /// constants. The fixture above is horizontal-only; this pins the portrait path.
    func testGoodValuesForThumbnailsWidthMinMaxPortrait() throws {
        // aspectRatio = 0.5, rowsCount = 4 → minRatio = 1.3/4 = 0.325, maxRatio = 2.1/4 = 0.525
        // Then clamp: lo = max(0.09, 0.325) = 0.325, hi = min(0.30, 0.525) = 0.30
        let (lo, hi) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(0.5, 4)
        XCTAssertEqual(lo, 0.325, accuracy: 0.001)
        XCTAssertEqual(hi, 0.30, accuracy: 0.001)
        // smaller portrait ratio with more rows → both fall into the clamp zone
        let (lo2, hi2) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(0.5, 16)
        XCTAssertEqual(lo2, max(0.09, 1.3 / 16), accuracy: 0.001)
        XCTAssertEqual(hi2, min(0.30, 2.1 / 16), accuracy: 0.001)
    }

    func testVariableWidthRowAlignmentInLeftToRightLayout() {
        let frames = [CGRect(x: 10, y: 10, width: 80, height: 50), CGRect(x: 100, y: 10, width: 120, height: 50)]
        XCTAssertEqual(aligned(frames, .leading, true), [10, 100])
        XCTAssertEqual(aligned(frames, .center, true), [45, 135])
        XCTAssertEqual(aligned(frames, .trailing, true), [80, 170])
    }

    func testVariableWidthRowAlignmentMirrorsInRightToLeftLayout() {
        let frames = [CGRect(x: 270, y: 10, width: 80, height: 50), CGRect(x: 140, y: 10, width: 120, height: 50)]
        XCTAssertEqual(aligned(frames, .leading, false), [210, 80])
        XCTAssertEqual(aligned(frames, .center, false), [175, 45])
        XCTAssertEqual(aligned(frames, .trailing, false), [140, 10])
    }

    func testEqualWidthAppIconRowUsesTheSameAlignmentGeometry() {
        let frames = [CGRect(x: 10, y: 10, width: 50, height: 50), CGRect(x: 70, y: 10, width: 50, height: 50)]
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 250, 10, .leading, true), [10, 70])
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 250, 10, .center, true), [70, 130])
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 250, 10, .trailing, true), [130, 190])
    }

    func testFullWidthRowDoesNotMoveForAnyAlignment() {
        let frames = [CGRect(x: 10, y: 10, width: 100, height: 50), CGRect(x: 120, y: 10, width: 90, height: 50)]
        for alignment in RowAlignmentPreference.allCases {
            XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 220, 10, alignment, true), [10, 120])
            XCTAssertEqual(AppearanceTestable.alignedRowOrigins(Array(frames.reversed()), 220, 10, alignment, false), [120, 10])
        }
    }

    func testRightToLeftRowNormalizesFromWiderPackingArea() {
        let frames = [CGRect(x: 890, y: 10, width: 100, height: 50)]
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 320, 10, .leading, false), [210])
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 320, 10, .center, false), [110])
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins(frames, 320, 10, .trailing, false), [10])
    }

    func testAlignedRowOriginsAreIdempotentAndHandleEmptyRows() {
        let frames = [CGRect(x: 270, y: 10, width: 80, height: 50), CGRect(x: 140, y: 10, width: 120, height: 50)]
        let origins = aligned(frames, .center, false)
        let alignedFrames = zip(frames, origins).map { CGRect(origin: CGPoint(x: $0.1, y: $0.0.minY), size: $0.0.size) }
        XCTAssertEqual(aligned(alignedFrames, .center, false), origins)
        XCTAssertEqual(AppearanceTestable.alignedRowOrigins([], 300, 10, .center, true), [])
    }

    private func aligned(_ frames: [CGRect], _ alignment: RowAlignmentPreference, _ isLeftToRight: Bool) -> [CGFloat] {
        AppearanceTestable.alignedRowOrigins(frames, 300, 10, alignment, isLeftToRight)
    }

    private let screens: [(String, (CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat), [(Int, CGFloat, CGFloat)])] = [
        // screen model, (widthInPixels, heightInPixels), (physicalWidthInMM, physicalHeightInMM), (expectedWidthForHorizontal, expectedWidthForVertical), (rowCount, expectedMinWidth, expectedMaxWidth)
        ("11\" Laptop: MacBook Air 11\": HD", (1366, 768), (255.7, 178.6), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("13\" Laptop: MacBook Air 13\": WXGA+", (1440, 900), (304.1, 197.8), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("14\" Laptop: MacBook Pro 14\": 3K", (3024, 1964), (311.0, 221.1), (0.90, 0.90), [(3, 0.13, 0.29), (4, 0.10, 0.22), (5, 0.09, 0.17)]),
        ("15\" Laptop: MacBook Pro 15\": QXGA", (2880, 1800), (344.4, 233.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("16\" Laptop: MacBook Pro 16\": 3.5K", (3456, 2234), (358.4, 245.9), (0.90, 0.90), [(3, 0.13, 0.29), (4, 0.10, 0.22), (5, 0.09, 0.17)]),
        ("19\" Monitor: Apple Studio Display 19\": HD", (1440, 900), (403.0, 236.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("20\" Monitor: Apple Cinema Display 20\": WSXGA+", (1680, 1050), (440.0, 268.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("21\" Monitor: LG 21:9 UltraWide: UWHD", (2560, 1080), (470.0, 290.0), (0.90, 0.90), [(3, 0.09, 0.19), (4, 0.09, 0.14), (5, 0.09, 0.11)]),
        ("22\" Monitor: ASUS 22\" Full HD: Full HD", (1920, 1080), (485.0, 290.0), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("24\" Monitor: Dell P2419H: Full HD", (1920, 1080), (531.3, 298.6), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("27\" Monitor: LG 27UK850-W: 4K", (3840, 2160), (596.8, 336.4), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("30\" Monitor: BenQ PD3200U: 4K", (3840, 2160), (657.5, 376.3), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("32\" Monitor: BenQ EW3270U: 4K", (3840, 2160), (711.5, 398.9), (0.84, 0.90), [(3, 0.12, 0.27), (4, 0.09, 0.20), (5, 0.09, 0.16)]),
        ("34\" UltraWide Monitor: LG 34UC79G-B: UWHD", (2560, 1080), (798.5, 336.5), (0.75, 0.90), [(3, 0.10, 0.22), (4, 0.09, 0.17), (5, 0.09, 0.14)]),
        ("34\" UltraWide Monitor: LG 34WN80C-B: UWQHD", (3440, 1440), (799.8, 334.8), (0.75, 0.90), [(3, 0.10, 0.22), (4, 0.09, 0.17), (5, 0.09, 0.13)]),
        ("32\" TV: Samsung UE32T5300: Full HD", (1920, 1080), (715.0, 406.0), (0.83, 0.90), [(3, 0.13, 0.27), (4, 0.09, 0.20), (5, 0.09, 0.16)]),
        ("40\" TV: Samsung Q60B: 4K", (3840, 2160), (889.0, 510.0), (0.67, 0.90), [(3, 0.16, 0.30), (4, 0.12, 0.25), (5, 0.09, 0.20)]),
        ("43\" TV: LG 43UN7300: 4K", (3840, 2160), (956.0, 551.0), (0.62, 0.90), [(3, 0.17, 0.30), (4, 0.13, 0.27), (5, 0.10, 0.22)]),
        ("50\" TV: Samsung TU8000: 4K", (3840, 2160), (1110.0, 630.0), (0.54, 0.90), [(3, 0.19, 0.30), (4, 0.15, 0.30), (5, 0.12, 0.25)]),
        ("55\" TV: LG OLED55CXPUA: 4K", (3840, 2160), (1210.0, 715.0), (0.49, 0.83), [(3, 0.21, 0.30), (4, 0.16, 0.30), (5, 0.13, 0.28)]),
        ("60\" TV: Vizio 60-inch 4K: 4K", (3840, 2160), (1320.0, 750.0), (0.45, 0.80), [(3, 0.23, 0.30), (4, 0.17, 0.30), (5, 0.14, 0.30)]),
    ]
}
