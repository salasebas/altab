import Foundation

enum IncludedFeature: String, CaseIterable {
    case searchInSwitcher
    case searchOnReleaseShortcut
    case autoSize
    case appIconsAndTitlesStyle
    case additionalShortcuts
    case perShortcutOptions
}

enum IncludedShortcutAction: Equatable {
    case focusTarget
    case showOrCycle(index: Int)
}

enum IncludedFeatures {
    static let keyboardShortcutCount = 9
    static let keyboardShortcutIndices = Array(0..<keyboardShortcutCount)
    static let additionalShortcutIndices = Array(1..<keyboardShortcutCount)
    static let gestureIndex = keyboardShortcutCount
    static let configurationIndices = Array(0...gestureIndex)
    static let shortcutTriggerBaseNames = ["holdShortcut", "nextWindowShortcut"]
    static let globalPreferenceKeys = ["appearanceStyle", "appearanceSize", "shortcutStyle"]
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

    static func effectiveValue<T>(global: T, override: T?) -> T {
        override ?? global
    }

    static func preferenceName(_ baseName: String, _ index: Int) -> String {
        baseName + (index == 0 ? "" : String(index + 1))
    }

    static func preferenceIndex(_ name: String) -> Int {
        let digits = String(name.reversed().prefix { $0.isNumber }.reversed())
        guard !digits.isEmpty, let number = Int(digits) else { return 0 }
        return number - 1
    }

    static func activeShortcutPreferenceKeys(shortcutCount: Int) -> [String] {
        Array(0..<min(max(shortcutCount, 0), keyboardShortcutCount)).flatMap { index in
            shortcutTriggerBaseNames.map { preferenceName($0, index) }
        }
    }

    static func switcherShortcutIndex(_ name: String) -> Int? {
        for index in keyboardShortcutIndices where shortcutTriggerBaseNames.contains(where: { preferenceName($0, index) == name }) {
            return index
        }
        return nil
    }

    static func shortcutAction(_ name: String) -> IncludedShortcutAction? {
        guard let index = switcherShortcutIndex(name) else { return nil }
        return name.hasPrefix("holdShortcut") ? .focusTarget : .showOrCycle(index: index)
    }

    static func canAddShortcut(currentCount: Int) -> Bool {
        currentCount >= 1 && currentCount < keyboardShortcutCount
    }
}
