import Cocoa

enum LegacyPreferencesImportResult: Equatable {
    case alreadyCompleted
    case noSource
    case imported(importedCount: Int, invalidCount: Int, preservedCount: Int)
}

enum LegacyPreferenceValidator {
    case boolean
    case enumeration(Int)
    case exceptions
    case integer(ClosedRange<Int>)
    case shortcut
}

class LegacyPreferencesImporter {
    static let sourceDomainName = "com.lwouis.alt-tab-macos"
    static let sourceLicenseDomainName = "com.lwouis.alt-tab-macos.license"
    static let completionKey = "legacyPreferencesImportCompleted"
    static let excludedOwnedKeys: Set<String> = [
        "screenRecordingPermissionSkipped", "settingsWindowShownOnFirstLaunch", "startAtLogin",
        "tileSpacingPoints",
    ]
    static let rememberedSelectionKeys = RememberedPreferenceRecovery.rules.map(\.rememberedKey)
    static let bannedExactKeys: Set<String> = excludedOwnedKeys.union([
        "crashPolicy", "preferencesVersion", "updatePolicy",
        "NSApplicationCrashOnExceptions", "NSNavLastRootDirectory", "NSQuitAlwaysKeepsWindows",
    ])
    static let bannedPrefixes = [
        "account", "activation", "analytics", "appcast", "appcenter", "checkout", "conversion",
        "cookie", "crash", "customer", "license", "machinefingerprint", "nswindow frame", "onboarding",
        "permissiongranted", "permissionskipped", "protransition.", "sparkle", "su", "trial", "update", "usage",
    ]
    static let validators: [String: LegacyPreferenceValidator] = {
        var values: [String: LegacyPreferenceValidator] = [
            "shortcutCount": .integer(Preferences.minShortcutCount...Preferences.maxShortcutCount),
            "nextWindowGesture": .enumeration(GesturePreference.allCases.count),
            "arrowKeysEnabled": .boolean,
            "vimKeysEnabled": .boolean,
            "mouseHoverEnabled": .boolean,
            "cursorFollowFocus": .enumeration(CursorFollowFocus.allCases.count),
            "hideColoredCircles": .boolean,
            "windowDisplayDelay": .integer(0...900),
            "appearanceStyle": .enumeration(AppearanceStylePreference.allCases.count),
            "appearanceSize": .enumeration(AppearanceSizePreference.allCases.count),
            "appearanceTheme": .enumeration(AppearanceThemePreference.allCases.count),
            "theme": .enumeration(ThemePreference.allCases.count),
            "showOnScreen": .enumeration(ShowOnScreenPreference.allCases.count),
            "titleTruncation": .enumeration(TitleTruncationPreference.allCases.count),
            "showTitles": .enumeration(ShowTitlesPreference.allCases.count),
            "fadeOutAnimation": .boolean,
            "previewFadeInAnimation": .boolean,
            "menubarIcon": .enumeration(MenubarIconPreference.allCases.count),
            "menubarIconShown": .boolean,
            "language": .enumeration(LanguagePreference.allCases.count),
            "exceptions": .exceptions,
            "hideThumbnails": .boolean,
            "hideSpaceNumberLabels": .boolean,
            "hideStatusIcons": .boolean,
            "previewFocusedWindow": .boolean,
            "captureWindowsInBackground": .boolean,
            "trackpadHapticFeedbackEnabled": .boolean,
        ]
        Preferences.staticShortcutKeys.forEach { values[$0] = .shortcut }
        for index in IncludedFeatures.keyboardShortcutIndices {
            IncludedFeatures.shortcutTriggerBaseNames.forEach { values[Preferences.indexToName($0, index)] = .shortcut }
        }
        let perShortcutValidators: [(String, LegacyPreferenceValidator)] = [
            ("appsToShow", .enumeration(AppsToShowPreference.allCases.count)),
            ("spacesToShow", .enumeration(SpacesToShowPreference.allCases.count)),
            ("screensToShow", .enumeration(ScreensToShowPreference.allCases.count)),
            ("showMinimizedWindows", .enumeration(ShowHowPreference.allCases.count)),
            ("showHiddenWindows", .enumeration(ShowHowPreference.allCases.count)),
            ("showFullscreenWindows", .enumeration(ShowHowPreference.allCases.count)),
            ("showWindowlessApps", .enumeration(ShowHowPreference.allCases.count)),
            ("windowOrder", .enumeration(WindowOrderPreference.allCases.count)),
            ("shortcutStyle", .enumeration(ShortcutStylePreference.allCases.count)),
            ("showAppsOrWindows", .enumeration(GroupAppsPreference.allCases.count)),
            ("showTabsAsWindows", .enumeration(GroupTabsPreference.allCases.count)),
            ("appearanceStyleOverride", .enumeration(AppearanceStylePreference.allCases.count)),
            ("appearanceSizeOverride", .enumeration(AppearanceSizePreference.allCases.count)),
            ("appearanceThemeOverride", .enumeration(AppearanceThemePreference.allCases.count)),
            ("shortcutStyleOverride", .enumeration(ShortcutStylePreference.allCases.count)),
            ("previewFocusedWindowOverride", .boolean),
        ]
        for index in IncludedFeatures.configurationIndices {
            perShortcutValidators.forEach { values[Preferences.indexToName($0.0, index)] = $0.1 }
        }
        precondition(Set(values.keys).isSubset(of: Preferences.ownedKeys))
        precondition(!values.keys.contains(where: isBannedKey))
        return values
    }()
    static var allowedKeys: Set<String> { Set(validators.keys) }

    @discardableResult
    static func importIfNeeded() -> LegacyPreferencesImportResult {
        let destinationDomain = UserDefaults.standard.persistentDomain(forName: App.bundleIdentifier) ?? [:]
        guard destinationDomain[completionKey] as? Bool != true else { return .alreadyCompleted }
        let sourceDomain = UserDefaults.standard.persistentDomain(forName: sourceDomainName)
        let rememberedSelections = sourceDomain == nil ? [:] : readRememberedSelections()
        return importIfNeeded(destination: .standard, destinationDomainName: App.bundleIdentifier, sourceDomain: sourceDomain, rememberedSelections: rememberedSelections)
    }

    @discardableResult
    static func importIfNeeded(destination: UserDefaults, destinationDomainName: String, sourceDomain: [String: Any]?, rememberedSelections: [String: Any]) -> LegacyPreferencesImportResult {
        var destinationDomain = destination.persistentDomain(forName: destinationDomainName) ?? [:]
        guard destinationDomain[completionKey] as? Bool != true else { return .alreadyCompleted }
        guard var sourceDomain else {
            destinationDomain[completionKey] = true
            destination.setPersistentDomain(destinationDomain, forName: destinationDomainName)
            return .noSource
        }
        recoverRememberedSelections(&sourceDomain, rememberedSelections)
        let normalized = PreferencesMigrations.normalizeImportedPreferences(sourceDomain, sourceDomain["preferencesVersion"] as? String)
        var importedCount = 0
        var invalidCount = 0
        var preservedCount = 0
        for (key, validator) in validators {
            guard let sourceValue = normalized[key] else { continue }
            guard destinationDomain[key] == nil else {
                preservedCount += 1
                continue
            }
            guard let value = validatedValue(sourceValue, validator) else {
                invalidCount += 1
                continue
            }
            destinationDomain[key] = value
            importedCount += 1
        }
        destinationDomain[completionKey] = true
        destination.setPersistentDomain(destinationDomain, forName: destinationDomainName)
        Preferences.invalidateAllCache()
        return .imported(importedCount: importedCount, invalidCount: invalidCount, preservedCount: preservedCount)
    }

    static func isBannedKey(_ key: String) -> Bool {
        guard !bannedExactKeys.contains(key) else { return true }
        let normalized = key.lowercased()
        return normalized.contains("permission") || bannedPrefixes.contains { normalized.hasPrefix($0) }
    }

    private static func readRememberedSelections() -> [String: Any] {
        guard let defaults = UserDefaults(suiteName: sourceLicenseDomainName) else { return [:] }
        return rememberedSelectionKeys.reduce(into: [:]) { result, key in
            if let value = defaults.object(forKey: key) { result[key] = value }
        }
    }

    private static func recoverRememberedSelections(_ sourceDomain: inout [String: Any], _ rememberedSelections: [String: Any]) {
        for rule in RememberedPreferenceRecovery.rules {
            guard let value = rule.recoveredValue(rememberedSelections[rule.rememberedKey], sourceDomain[rule.preferenceKey]) else { continue }
            sourceDomain[rule.preferenceKey] = value
        }
    }

    private static func validatedValue(_ value: Any, _ validator: LegacyPreferenceValidator) -> Any? {
        switch validator {
            case .boolean:
                guard let value = exactBoolean(value) else { return nil }
                return String(value)
            case let .enumeration(count):
                guard let value = exactInteger(value), (0..<count).contains(value) else { return nil }
                return String(value)
            case .exceptions:
                guard let string = value as? String,
                      let data = string.data(using: .utf8),
                      let entries = try? JSONDecoder().decode([ExceptionEntry].self, from: data),
                      entries.allSatisfy({ !$0.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
                return string
            case let .integer(range):
                guard let value = exactInteger(value), range.contains(value) else { return nil }
                return String(value)
            case .shortcut:
                return canonicalShortcutStorage(value)
        }
    }

    static func isValidShortcutStorage(_ value: Any) -> Bool {
        return canonicalShortcutStorage(value) != nil
    }

    static func canonicalShortcutStorage(_ value: Any) -> [String: Any]? {
        guard let storage = prevalidatedShortcutStorage(value), let string = storage["string"] as? String else { return nil }
        var canonical: [String: Any]?
        guard ObjCExceptionCatcher.attempt({
            let decoded = Preferences.decodeShortcutStorage(storage)
            guard decoded.0 else { return }
            canonical = Preferences.shortcutStorage(decoded.1, string)
        }), let canonical else { return nil }
        return canonical
    }

    private static func prevalidatedShortcutStorage(_ value: Any) -> [String: Any]? {
        guard let storage = value as? [String: Any],
              Set(storage.keys) == ["secureData", "string"],
              let string = storage["string"] as? String,
              let data = storage["secureData"] as? Data,
              string.count <= 128,
              (64...16_384).contains(data.count) else { return nil }
        return storage
    }

    private static func exactBoolean(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        guard let value = value as? String else { return nil }
        if value == "true" { return true }
        if value == "false" { return false }
        return nil
    }

    private static func exactInteger(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        guard let value = value as? String,
              let integer = Int(value),
              String(integer) == value else { return nil }
        return integer
    }
}
