import XCTest

final class IncludedFeaturesTests: XCTestCase {
    private var originalDefaults: UserDefaults!
    private var originalDefaultsDomainName: String!
    private var isolatedDefaults: UserDefaults!
    private var isolatedDefaultsDomainName: String!

    override func setUp() {
        super.setUp()
        originalDefaults = Preferences.defaults
        originalDefaultsDomainName = Preferences.defaultsDomainName
        isolatedDefaultsDomainName = "\(App.bundleIdentifier).IncludedFeaturesTests.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: isolatedDefaultsDomainName)!
        isolatedDefaults.removePersistentDomain(forName: isolatedDefaultsDomainName)
        Preferences.defaults = isolatedDefaults
        Preferences.defaultsDomainName = isolatedDefaultsDomainName
        Preferences.invalidateAllCache()
    }

    override func tearDown() {
        isolatedDefaults.removePersistentDomain(forName: isolatedDefaultsDomainName)
        Preferences.defaults = originalDefaults
        Preferences.defaultsDomainName = originalDefaultsDomainName
        Preferences.invalidateAllCache()
        super.tearDown()
    }

    func testCompleteFeatureInventoryIsPinned() {
        XCTAssertEqual(Set(IncludedFeature.allCases), [
            .searchInSwitcher, .searchOnReleaseShortcut, .autoSize,
            .appIconsAndTitlesStyle, .additionalShortcuts, .perShortcutOptions,
        ])
        XCTAssertEqual(IncludedFeatures.keyboardShortcutIndices, Array(0...8))
        XCTAssertEqual(IncludedFeatures.additionalShortcutIndices, Array(1...8))
        XCTAssertEqual(IncludedFeatures.configurationIndices, Array(0...9))
        XCTAssertEqual(IncludedFeatures.perShortcutPreferenceBaseNames.count, 16)
    }

    func testProductionPreferencesStoreAndReadEveryPerShortcutSetting() {
        Preferences.set("appearanceStyle", AppearanceStylePreference.thumbnails.indexAsString, false)
        Preferences.set("appearanceSize", AppearanceSizePreference.medium.indexAsString, false)
        Preferences.set("appearanceTheme", AppearanceThemePreference.system.indexAsString, false)
        Preferences.set("shortcutStyle", ShortcutStylePreference.focusOnRelease.indexAsString, false)
        Preferences.set("previewFocusedWindow", "false", false)
        for index in IncludedFeatures.configurationIndices {
            let apps: AppsToShowPreference = index.isMultiple(of: 2) ? .active : .nonActive
            let spaces: SpacesToShowPreference = index.isMultiple(of: 2) ? .visible : .nonVisible
            let screens: ScreensToShowPreference = .showingAltTab
            let minimized: ShowHowPreference = index.isMultiple(of: 2) ? .hide : .showAtTheEnd
            let hidden: ShowHowPreference = index.isMultiple(of: 2) ? .showAtTheEnd : .hide
            let fullscreen: ShowHowPreference = .hide
            let windowless: ShowHowPreference = .show
            let order: WindowOrderPreference = index.isMultiple(of: 2) ? .alphabetical : .space
            let directShortcutStyle: ShortcutStylePreference = .doNothingOnRelease
            let groupApps: GroupAppsPreference = .mainWindow
            let groupTabs: GroupTabsPreference = .separateWindows
            let appearanceStyle: AppearanceStylePreference = index.isMultiple(of: 2) ? .appIcons : .titles
            let appearanceTheme: AppearanceThemePreference = index.isMultiple(of: 2) ? .dark : .light
            set(apps, "appsToShow", index)
            set(spaces, "spacesToShow", index)
            set(screens, "screensToShow", index)
            set(minimized, "showMinimizedWindows", index)
            set(hidden, "showHiddenWindows", index)
            set(fullscreen, "showFullscreenWindows", index)
            set(windowless, "showWindowlessApps", index)
            set(order, "windowOrder", index)
            set(directShortcutStyle, "shortcutStyle", index)
            set(groupApps, "showAppsOrWindows", index)
            set(groupTabs, "showTabsAsWindows", index)
            set(appearanceStyle, "appearanceStyleOverride", index)
            set(AppearanceSizePreference.auto, "appearanceSizeOverride", index)
            set(appearanceTheme, "appearanceThemeOverride", index)
            set(ShortcutStylePreference.searchOnRelease, "shortcutStyleOverride", index)
            Preferences.set(Preferences.indexToName("previewFocusedWindowOverride", index), "true", false)

            let configuration = Preferences.shortcut(at: index)
            XCTAssertEqual(configuration.appsToShow, apps, "index \(index)")
            XCTAssertEqual(configuration.spacesToShow, spaces, "index \(index)")
            XCTAssertEqual(configuration.screensToShow, screens, "index \(index)")
            XCTAssertEqual(configuration.showMinimizedWindows, minimized, "index \(index)")
            XCTAssertEqual(configuration.showHiddenWindows, hidden, "index \(index)")
            XCTAssertEqual(configuration.showFullscreenWindows, fullscreen, "index \(index)")
            XCTAssertEqual(configuration.showWindowlessApps, windowless, "index \(index)")
            XCTAssertEqual(configuration.windowOrder, order, "index \(index)")
            XCTAssertEqual(configuration.shortcutStyle, directShortcutStyle, "index \(index)")
            XCTAssertEqual(Preferences.groupApps(index), groupApps, "index \(index)")
            XCTAssertEqual(Preferences.groupTabs(index), groupTabs, "index \(index)")
            XCTAssertEqual(Preferences.effectiveAppearanceStyle(index), appearanceStyle, "index \(index)")
            XCTAssertEqual(Preferences.effectiveAppearanceSize(index), .auto, "index \(index)")
            XCTAssertEqual(Preferences.effectiveAppearanceTheme(index), appearanceTheme, "index \(index)")
            XCTAssertEqual(Preferences.effectiveShortcutStyle(index), .searchOnRelease, "index \(index)")
            XCTAssertTrue(Preferences.effectivePreviewSelectedWindow(index), "index \(index)")
            for overrideName in IncludedFeatures.overrideBaseNames {
                XCTAssertTrue(Preferences.hasOverride(overrideName, index), "\(overrideName), index \(index)")
            }
        }
    }

    func testProductionEffectivePreferencesUseStoredGlobalsWhenOverridesAreAbsent() {
        Preferences.set("appearanceStyle", AppearanceStylePreference.titles.indexAsString, false)
        Preferences.set("appearanceSize", AppearanceSizePreference.auto.indexAsString, false)
        Preferences.set("appearanceTheme", AppearanceThemePreference.dark.indexAsString, false)
        Preferences.set("shortcutStyle", ShortcutStylePreference.searchOnRelease.indexAsString, false)
        Preferences.set("previewFocusedWindow", "true", false)
        for index in IncludedFeatures.configurationIndices {
            for overrideName in IncludedFeatures.overrideBaseNames {
                Preferences.remove(Preferences.indexToName(overrideName, index), false)
                XCTAssertFalse(Preferences.hasOverride(overrideName, index), "\(overrideName), index \(index)")
            }
            XCTAssertEqual(Preferences.effectiveAppearanceStyle(index), .titles, "index \(index)")
            XCTAssertEqual(Preferences.effectiveAppearanceSize(index), .auto, "index \(index)")
            XCTAssertEqual(Preferences.effectiveAppearanceTheme(index), .dark, "index \(index)")
            XCTAssertEqual(Preferences.effectiveShortcutStyle(index), .searchOnRelease, "index \(index)")
            XCTAssertTrue(Preferences.effectivePreviewSelectedWindow(index), "index \(index)")
        }
    }

    func testShortcutRoutingUsesThePrecomputedProductionLookup() {
        for index in IncludedFeatures.keyboardShortcutIndices {
            XCTAssertEqual(ShortcutActions.switcherAction(Preferences.indexToName("holdShortcut", index)), .focusTarget)
            XCTAssertEqual(ShortcutActions.switcherAction(Preferences.indexToName("nextWindowShortcut", index)), .showOrCycle(index: index))
        }
        XCTAssertNil(ShortcutActions.switcherAction("holdShortcut10"), "gesture settings are not keyboard shortcuts")
        XCTAssertNil(ShortcutActions.switcherAction("holdShortcutUnknown"))
        XCTAssertNil(ShortcutActions.switcherAction("nextWindowShortcut0"))
    }

    func testShortcutCapacityIncludesEveryAdditionalSlot() {
        XCTAssertEqual(Preferences.minShortcutCount, 1)
        XCTAssertEqual(Preferences.maxShortcutCount, 9)
    }

    func testSearchAlwaysEntersEditing() {
        XCTAssertEqual(SearchModeResolver.enableEditing(mode: .off), .enterEditing)
        XCTAssertEqual(SearchModeResolver.enableEditing(mode: .editing), .placeCaretOnly)
        XCTAssertEqual(SearchModeResolver.startMode(startInSearch: true), .editing)
    }

    private func set<T: CaseIterable & Equatable>(_ value: T, _ baseName: String, _ index: Int) {
        let allCases = Array(T.allCases)
        Preferences.set(Preferences.indexToName(baseName, index), String(allCases.firstIndex(of: value)!), false)
    }
}
