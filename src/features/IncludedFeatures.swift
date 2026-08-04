import Foundation

enum IncludedFeature: String, CaseIterable {
    case searchInSwitcher
    case searchOnReleaseShortcut
    case autoSize
    case appIconsAndTitlesStyle
    case additionalShortcuts
    case perShortcutOptions
}

enum IncludedFeatures {
    static let keyboardShortcutCount = 9
    static let keyboardShortcutIndices = Array(0..<keyboardShortcutCount)
    static let additionalShortcutIndices = Array(1..<keyboardShortcutCount)
    static let gestureIndex = keyboardShortcutCount
    static let configurationIndices = Array(0...gestureIndex)
    static let shortcutTriggerBaseNames = ["holdShortcut", "nextWindowShortcut"]
    static let perShortcutPreferenceBaseNames = [
        "appsToShow", "spacesToShow", "screensToShow",
        "showMinimizedWindows", "showHiddenWindows", "showFullscreenWindows", "showWindowlessApps",
        "windowOrder", "shortcutStyle", "showAppsOrWindows", "showTabsAsWindows",
        "appearanceStyleOverride", "appearanceSizeOverride", "appearanceThemeOverride",
        "shortcutStyleOverride", "previewFocusedWindowOverride",
    ]
    static let overrideBaseNames = [
        "appearanceStyleOverride", "appearanceSizeOverride", "appearanceThemeOverride",
        "shortcutStyleOverride", "previewFocusedWindowOverride",
    ]
}
