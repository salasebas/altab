import XCTest

final class IncludedFeaturesTests: XCTestCase {
    func testCompleteFeatureMatrixIsPinned() {
        XCTAssertEqual(Set(IncludedFeature.allCases), [
            .searchInSwitcher, .searchOnReleaseShortcut, .autoSize,
            .appIconsAndTitlesStyle, .additionalShortcuts, .perShortcutOptions,
        ])
    }

    func testEveryPerShortcutPreferenceVariantIsRepresentedForKeyboardAndGesture() {
        XCTAssertEqual(IncludedFeatures.keyboardShortcutIndices, Array(0...8))
        XCTAssertEqual(IncludedFeatures.gestureIndex, 9)
        XCTAssertEqual(IncludedFeatures.configurationIndices, Array(0...9))
        XCTAssertEqual(IncludedFeatures.globalPreferenceKeys, ["appearanceStyle", "appearanceSize", "shortcutStyle"])
        XCTAssertEqual(IncludedFeatures.perShortcutPreferenceBaseNames, [
            "appsToShow", "spacesToShow", "screensToShow",
            "showMinimizedWindows", "showHiddenWindows", "showFullscreenWindows", "showWindowlessApps",
            "windowOrder", "shortcutStyle", "showAppsOrWindows", "showTabsAsWindows",
            "appearanceStyleOverride", "appearanceSizeOverride", "appearanceThemeOverride",
            "shortcutStyleOverride", "previewFocusedWindowOverride",
        ])
        XCTAssertEqual(IncludedFeatures.overrideBaseNames, [
            "appearanceStyleOverride", "appearanceSizeOverride", "appearanceThemeOverride",
            "shortcutStyleOverride", "previewFocusedWindowOverride",
        ])
        for index in IncludedFeatures.configurationIndices {
            for baseName in IncludedFeatures.perShortcutPreferenceBaseNames {
                let expected = baseName + (index == 0 ? "" : String(index + 1))
                XCTAssertEqual(IncludedFeatures.preferenceName(baseName, index), expected)
                XCTAssertEqual(IncludedFeatures.preferenceIndex(expected), index)
            }
        }
    }

    func testEverySupportedShortcutKeyIsRegisteredAndExecutable() {
        let expectedIndices = IncludedFeatures.keyboardShortcutIndices
        XCTAssertEqual(IncludedFeatures.activeShortcutPreferenceKeys(shortcutCount: IncludedFeatures.keyboardShortcutCount).count, IncludedFeatures.keyboardShortcutCount * 2)
        for baseName in ["holdShortcut", "nextWindowShortcut"] {
            let ids = expectedIndices.map { IncludedFeatures.preferenceName(baseName, $0) }
            XCTAssertEqual(ids.compactMap(IncludedFeatures.switcherShortcutIndex), expectedIndices)
        }
        for index in expectedIndices {
            XCTAssertEqual(IncludedFeatures.shortcutAction(IncludedFeatures.preferenceName("holdShortcut", index)), .focusTarget)
            XCTAssertEqual(IncludedFeatures.shortcutAction(IncludedFeatures.preferenceName("nextWindowShortcut", index)), .showOrCycle(index: index))
        }
        XCTAssertEqual(IncludedFeatures.additionalShortcutIndices, Array(1...8))
        XCTAssertNil(IncludedFeatures.switcherShortcutIndex("holdShortcut10"), "gesture settings are not keyboard shortcuts")
        XCTAssertNil(IncludedFeatures.switcherShortcutIndex("holdShortcutUnknown"))
    }

    func testShortcutCountUiAllowsEveryAdditionalSlot() {
        for count in 1..<IncludedFeatures.keyboardShortcutCount {
            XCTAssertTrue(IncludedFeatures.canAddShortcut(currentCount: count), "count \(count)")
        }
        XCTAssertFalse(IncludedFeatures.canAddShortcut(currentCount: IncludedFeatures.keyboardShortcutCount))
    }

    func testEveryOverrideWinsAndEveryUnsetOverrideUsesGlobalValue() {
        for index in IncludedFeatures.configurationIndices {
            XCTAssertEqual(IncludedFeatures.effectiveValue(global: "global-\(index)", override: nil), "global-\(index)")
            XCTAssertEqual(IncludedFeatures.effectiveValue(global: "global", override: "stored-\(index)"), "stored-\(index)")
        }
    }

    func testFormerlyRestrictedSelectionsAreReturnedWithoutFallback() {
        let appIcons = IncludedFeatures.effectiveValue(global: AppearanceStylePreference.appIcons, override: Optional<AppearanceStylePreference>.none)
        let titles = IncludedFeatures.effectiveValue(global: AppearanceStylePreference.titles, override: Optional<AppearanceStylePreference>.none)
        let autoSize = IncludedFeatures.effectiveValue(global: AppearanceSizePreference.auto, override: Optional<AppearanceSizePreference>.none)
        let searchOnRelease = IncludedFeatures.effectiveValue(global: ShortcutStylePreference.searchOnRelease, override: Optional<ShortcutStylePreference>.none)
        XCTAssertTrue(appIcons == .appIcons)
        XCTAssertTrue(titles == .titles)
        XCTAssertTrue(autoSize == .auto)
        XCTAssertTrue(searchOnRelease == .searchOnRelease)
    }

    func testSearchAlwaysEntersEditing() {
        XCTAssertEqual(SearchModeResolver.enableEditing(mode: .off), .enterEditing)
        XCTAssertEqual(SearchModeResolver.enableEditing(mode: .editing), .placeCaretOnly)
        XCTAssertEqual(SearchModeResolver.startMode(startInSearch: true), .editing)
    }
}
