import Cocoa
import XCTest

final class TrafficLightButtonTests: XCTestCase {
    private var originalDefaults: UserDefaults!
    private var originalDefaultsDomainName: String!
    private var isolatedDefaults: UserDefaults!
    private var isolatedDefaultsDomainName: String!

    override func setUp() {
        super.setUp()
        originalDefaults = Preferences.defaults
        originalDefaultsDomainName = Preferences.defaultsDomainName
        isolatedDefaultsDomainName = "\(App.bundleIdentifier).TrafficLightButtonTests.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: isolatedDefaultsDomainName)!
        isolatedDefaults.removePersistentDomain(forName: isolatedDefaultsDomainName)
        Preferences.defaults = isolatedDefaults
        Preferences.defaultsDomainName = isolatedDefaultsDomainName
        Preferences.registerDefaults()
        Preferences.invalidateAllCache()
    }

    override func tearDown() {
        isolatedDefaults.removePersistentDomain(forName: isolatedDefaultsDomainName)
        Preferences.defaults = originalDefaults
        Preferences.defaultsDomainName = originalDefaultsDomainName
        Preferences.invalidateAllCache()
        super.tearDown()
    }

    func testSymbolsDefaultToEnabledAndPersistExplicitChoices() {
        XCTAssertTrue(Preferences.showSymbolsInHoverControls)
        Preferences.set("showSymbolsInHoverControls", "false", false)
        XCTAssertFalse(Preferences.showSymbolsInHoverControls)
        Preferences.defaults = UserDefaults(suiteName: isolatedDefaultsDomainName)!
        Preferences.registerDefaults()
        Preferences.invalidateAllCache()
        XCTAssertFalse(Preferences.showSymbolsInHoverControls)
    }

    func testDisablingSymbolsSkipsEveryGlyphButKeepsDiskAndDimmingPasses() {
        Preferences.set("hideColoredCircles", "false", false)
        Preferences.set("showSymbolsInHoverControls", "false", false)
        for type in allTypes {
            let button = DrawingSpy(type)
            button.draw(button.bounds)
            XCTAssertEqual(button.diskDrawCount, 1, "\(type)")
            XCTAssertEqual(button.symbolDrawCount, 0, "\(type)")
            XCTAssertEqual(button.dimmingDrawCount, 1, "\(type)")
        }
    }

    func testEnablingSymbolsDrawsEveryGlyph() {
        Preferences.set("hideColoredCircles", "false", false)
        Preferences.set("showSymbolsInHoverControls", "true", false)
        for type in allTypes {
            let button = DrawingSpy(type)
            button.draw(button.bounds)
            XCTAssertEqual(button.diskDrawCount, 1, "\(type)")
            XCTAssertEqual(button.symbolDrawCount, 1, "\(type)")
            XCTAssertEqual(button.dimmingDrawCount, 1, "\(type)")
        }
    }

    func testSymbolPreferenceIsIrrelevantWhenColoredCirclesAreHidden() {
        XCTAssertFalse(TrafficLightButton.shouldDrawSymbol(true, true))
        XCTAssertFalse(TrafficLightButton.symbolPreferenceIsEnabled(.thumbnails, true))
        XCTAssertFalse(TrafficLightButton.symbolPreferenceIsEnabled(.appIcons, false))
        XCTAssertFalse(TrafficLightButton.symbolPreferenceIsEnabled(.titles, false))
        XCTAssertTrue(TrafficLightButton.symbolPreferenceIsEnabled(.thumbnails, false))
    }

    private var allTypes: [TrafficLightButtonType] { [.quit, .close, .miniaturize, .fullscreen] }
}

private final class DrawingSpy: TrafficLightButton {
    var diskDrawCount = 0
    var symbolDrawCount = 0
    var dimmingDrawCount = 0

    init(_ type: TrafficLightButtonType) {
        super.init(type, "tooltip")
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func drawDisk(_ backgroundGradient: NSGradient, _ strokeColor: NSColor) -> NSBezierPath {
        diskDrawCount += 1
        return NSBezierPath()
    }

    override func drawSymbol(_ lineColor: NSColor) {
        symbolDrawCount += 1
    }

    override func drawDimming(_ disk: NSBezierPath) {
        dimmingDrawCount += 1
    }
}
