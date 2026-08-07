import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

struct PreferenceDefaultsSchema {
    private var entries = [String: () -> Any]()

    mutating func add(_ key: String, _ value: @autoclosure @escaping () -> Any) {
        precondition(entries[key] == nil, "Duplicate preference default: \(key)")
        entries[key] = value
    }

    var keys: Set<String> { Set(entries.keys) }

    func values() -> [String: Any] {
        entries.mapValues { $0() }
    }
}

struct ShortcutRegistrationPlan {
    let activeKeys: Set<String>
    let supportedKeys: [String]
}

class Preferences {
    private static let persistentDomainStateKeys = [LegacyPreferencesImporter.completionKey]
    #if TESTING
    private static let testDefaultsDomainName = "dev.salasebas.AlTab.unit-tests"
    static var defaults = UserDefaults(suiteName: testDefaultsDomainName)!
    static var defaultsDomainName = testDefaultsDomainName
    #else
    fileprivate static let defaults = UserDefaults.standard
    fileprivate static let defaultsDomainName = App.bundleIdentifier
    #endif
    private static let defaultsSchema: PreferenceDefaultsSchema = {
        var schema = PreferenceDefaultsSchema()
        schema.add("shortcutCount", "2")
        schema.add("nextWindowGesture", GesturePreference.disabled.indexAsString)
        schema.add("focusWindowShortcut", defaultShortcut(returnKeyEquivalent()))
        schema.add("previousWindowShortcut", defaultShortcut("⇧"))
        schema.add("cancelShortcut", defaultShortcut("⎋"))
        schema.add("closeWindowShortcut", defaultShortcut("W"))
        schema.add("minDeminWindowShortcut", defaultShortcut("M"))
        schema.add("toggleFullscreenWindowShortcut", defaultShortcut("F"))
        schema.add("quitAppShortcut", defaultShortcut("Q"))
        schema.add("hideShowAppShortcut", defaultShortcut("H"))
        schema.add("searchShortcut", defaultShortcut("S"))
        schema.add("arrowKeysEnabled", "true")
        schema.add("vimKeysEnabled", "false")
        schema.add("mouseHoverEnabled", "false")
        schema.add("cursorFollowFocus", CursorFollowFocus.never.indexAsString)
        schema.add("hideColoredCircles", "false")
        schema.add("showSymbolsInHoverControls", "true")
        schema.add("windowDisplayDelay", "100")
        schema.add("appearanceStyle", AppearanceStylePreference.thumbnails.indexAsString)
        schema.add("appearanceSize", AppearanceSizePreference.auto.indexAsString)
        schema.add("appearanceTheme", AppearanceThemePreference.system.indexAsString)
        schema.add("tileSpacingPoints", String(TileSpacingPreference.defaultValue))
        schema.add("theme", ThemePreference.macOs.indexAsString)
        schema.add("showOnScreen", ShowOnScreenPreference.active.indexAsString)
        schema.add("titleTruncation", TitleTruncationPreference.end.indexAsString)
        schema.add("alignThumbnails", RowAlignmentPreference.center.indexAsString)
        schema.add("showTitles", ShowTitlesPreference.windowTitle.indexAsString)
        schema.add("fadeOutAnimation", "false")
        schema.add("previewFadeInAnimation", "true")
        schema.add("startAtLogin", "true")
        schema.add("menubarIcon", MenubarIconPreference.outlined.indexAsString)
        schema.add("menubarIconShown", "true")
        schema.add("language", LanguagePreference.systemDefault.indexAsString)
        schema.add("exceptions", defaultExceptions())
        schema.add("hideThumbnails", "false")
        schema.add("hideSpaceNumberLabels", "false")
        schema.add("hideStatusIcons", "false")
        schema.add("previewFocusedWindow", "false")
        schema.add("captureWindowsInBackground", "true")
        schema.add("screenRecordingPermissionSkipped", "false")
        schema.add("trackpadHapticFeedbackEnabled", "true")
        schema.add("settingsWindowShownOnFirstLaunch", "false")
        for index in 0..<maxShortcutCount {
            schema.add(indexToName("holdShortcut", index), defaultShortcut("⌥"))
            schema.add(indexToName("nextWindowShortcut", index), defaultShortcut(index == 0 ? "⇥" : (index == 1 ? keyAboveTabDependingOnInputSource() : "")))
        }
        for index in 0...maxShortcutCount {
            schema.add(indexToName("appsToShow", index), index == 1 ? AppsToShowPreference.active.indexAsString : (index == 2 ? AppsToShowPreference.nonActive.indexAsString : AppsToShowPreference.all.indexAsString))
            schema.add(indexToName("spacesToShow", index), SpacesToShowPreference.all.indexAsString)
            schema.add(indexToName("screensToShow", index), ScreensToShowPreference.all.indexAsString)
            schema.add(indexToName("showMinimizedWindows", index), ShowHowPreference.show.indexAsString)
            schema.add(indexToName("showHiddenWindows", index), ShowHowPreference.show.indexAsString)
            schema.add(indexToName("showFullscreenWindows", index), ShowHowPreference.show.indexAsString)
            schema.add(indexToName("showWindowlessApps", index), ShowHowPreference.showAtTheEnd.indexAsString)
            schema.add(indexToName("windowOrder", index), WindowOrderPreference.recentlyFocused.indexAsString)
            schema.add(indexToName("shortcutStyle", index), ShortcutStylePreference.focusOnRelease.indexAsString)
            schema.add(indexToName("showAppsOrWindows", index), GroupAppsPreference.allWindows.indexAsString)
            schema.add(indexToName("showTabsAsWindows", index), GroupTabsPreference.singleWindow.indexAsString)
            // `hasOverride(_:_:)` consults `persistentDomain` so these registered defaults don't
            // make an unset override look set.
            schema.add(indexToName("appearanceStyleOverride", index), AppearanceStylePreference.thumbnails.indexAsString)
            schema.add(indexToName("appearanceSizeOverride", index), AppearanceSizePreference.medium.indexAsString)
            schema.add(indexToName("appearanceThemeOverride", index), AppearanceThemePreference.system.indexAsString)
            schema.add(indexToName("shortcutStyleOverride", index), ShortcutStylePreference.doNothingOnRelease.indexAsString)
            schema.add(indexToName("previewFocusedWindowOverride", index), "false")
        }
        return schema
    }()
    static let defaultValues = defaultsSchema.values()
    static let ownedKeys = defaultsSchema.keys

    // system preferences
    static var finderShowsQuitMenuItem: Bool { UserDefaults(suiteName: "com.apple.Finder")?.bool(forKey: "QuitMenuItem") ?? false }
    static let staticShortcutKeys = [
        "focusWindowShortcut", "previousWindowShortcut", "cancelShortcut", "closeWindowShortcut",
        "minDeminWindowShortcut", "toggleFullscreenWindowShortcut", "quitAppShortcut", "hideShowAppShortcut", "searchShortcut",
    ]
    static var allShortcutPreferenceKeys: [String] {
        staticShortcutKeys + activeShortcutPreferenceKeys(shortcutCount: maxShortcutCount)
    }
    static let emptyShortcut = Shortcut(code: .none, modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil)
    private static let shortcutStorageStringField = "string"
    private static let shortcutStorageDataField = "secureData"

    // persisted values
    static var holdShortcut: [Shortcut?] { (0..<shortcutCount).map { CachedUserDefaults.shortcut(indexToName("holdShortcut", $0)) } }
    static var nextWindowShortcut: [Shortcut?] { (0..<shortcutCount).map { CachedUserDefaults.shortcut(indexToName("nextWindowShortcut", $0)) } }
    static var nextWindowGesture: GesturePreference { CachedUserDefaults.macroPref("nextWindowGesture", GesturePreference.allCases) }
    static var focusWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("focusWindowShortcut") }
    static var previousWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("previousWindowShortcut") }
    static var cancelShortcut: Shortcut? { CachedUserDefaults.shortcut("cancelShortcut") }
    static var closeWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("closeWindowShortcut") }
    static var minDeminWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("minDeminWindowShortcut") }
    static var toggleFullscreenWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("toggleFullscreenWindowShortcut") }
    static var quitAppShortcut: Shortcut? { CachedUserDefaults.shortcut("quitAppShortcut") }
    static var hideShowAppShortcut: Shortcut? { CachedUserDefaults.shortcut("hideShowAppShortcut") }
    static var searchShortcut: Shortcut? { CachedUserDefaults.shortcut("searchShortcut") }
    // periphery:ignore
    static var arrowKeysEnabled: Bool { CachedUserDefaults.bool("arrowKeysEnabled") }
    // periphery:ignore
    static var vimKeysEnabled: Bool { CachedUserDefaults.bool("vimKeysEnabled") }
    static var mouseHoverEnabled: Bool { CachedUserDefaults.bool("mouseHoverEnabled") }
    static var cursorFollowFocus: CursorFollowFocus { CachedUserDefaults.macroPref("cursorFollowFocus", CursorFollowFocus.allCases) }
    static var trackpadHapticFeedbackEnabled: Bool { CachedUserDefaults.bool("trackpadHapticFeedbackEnabled") }
    static var hideColoredCircles: Bool { CachedUserDefaults.bool("hideColoredCircles") }
    static var showSymbolsInHoverControls: Bool { CachedUserDefaults.bool("showSymbolsInHoverControls") }
    static var windowDisplayDelay: DispatchTimeInterval { DispatchTimeInterval.milliseconds(CachedUserDefaults.int("windowDisplayDelay")) }
    static var fadeOutAnimation: Bool { CachedUserDefaults.bool("fadeOutAnimation") }
    static var previewFadeInAnimation: Bool { CachedUserDefaults.bool("previewFadeInAnimation") }
    static var hideSpaceNumberLabels: Bool { CachedUserDefaults.bool("hideSpaceNumberLabels") }
    static var hideStatusIcons: Bool { CachedUserDefaults.bool("hideStatusIcons") }
    // periphery:ignore
    static var startAtLogin: Bool { CachedUserDefaults.bool("startAtLogin") }
    static var exceptions: [ExceptionEntry] { CachedUserDefaults.json("exceptions", [ExceptionEntry].self) }
    static var previewSelectedWindow: Bool { CachedUserDefaults.bool("previewFocusedWindow") }
    static var captureWindowsInBackground: Bool { CachedUserDefaults.bool("captureWindowsInBackground") }
    static var screenRecordingPermissionSkipped: Bool { CachedUserDefaults.bool("screenRecordingPermissionSkipped") }
    static var settingsWindowShownOnFirstLaunch: Bool { CachedUserDefaults.bool("settingsWindowShownOnFirstLaunch") }

    // macro values
    static var appearanceStyle: AppearanceStylePreference { CachedUserDefaults.macroPref("appearanceStyle", AppearanceStylePreference.allCases) }
    static var appearanceSize: AppearanceSizePreference { CachedUserDefaults.macroPref("appearanceSize", AppearanceSizePreference.allCases) }
    static var appearanceTheme: AppearanceThemePreference { CachedUserDefaults.macroPref("appearanceTheme", AppearanceThemePreference.allCases) }
    static var tileSpacingPoints: Int { TileSpacingPreference.clamped(CachedUserDefaults.int("tileSpacingPoints")) }
    // periphery:ignore
    static var theme: ThemePreference { ThemePreference.macOs/*CachedUserDefaults.macroPref("theme", ThemePreference.allCases)*/ }
    static var showOnScreen: ShowOnScreenPreference { CachedUserDefaults.macroPref("showOnScreen", ShowOnScreenPreference.allCases) }
    static var titleTruncation: TitleTruncationPreference { CachedUserDefaults.macroPref("titleTruncation", TitleTruncationPreference.allCases) }
    static var rowAlignment: RowAlignmentPreference { CachedUserDefaults.macroPref("alignThumbnails", RowAlignmentPreference.allCases) }
    static var showTitles: ShowTitlesPreference { CachedUserDefaults.macroPref("showTitles", ShowTitlesPreference.allCases) }
    static var appsToShow: [AppsToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("appsToShow", $0), AppsToShowPreference.allCases) } }
    static var spacesToShow: [SpacesToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("spacesToShow", $0), SpacesToShowPreference.allCases) } }
    static var screensToShow: [ScreensToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("screensToShow", $0), ScreensToShowPreference.allCases) } }
    static var showMinimizedWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showMinimizedWindows", $0), ShowHowPreference.allCases) } }
    static var showHiddenWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showHiddenWindows", $0), ShowHowPreference.allCases) } }
    static var showFullscreenWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showFullscreenWindows", $0), ShowHowPreference.allCases) } }
    static var showWindowlessApps: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showWindowlessApps", $0), ShowHowPreference.allCases) } }
    static var windowOrder: [WindowOrderPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("windowOrder", $0), WindowOrderPreference.allCases) } }

    static func showMinimizedWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showMinimizedWindows", i), ShowHowPreference.allCases) }
    static func showHiddenWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showHiddenWindows", i), ShowHowPreference.allCases) }
    static func showFullscreenWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showFullscreenWindows", i), ShowHowPreference.allCases) }
    static func showWindowlessApps(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showWindowlessApps", i), ShowHowPreference.allCases) }
    static func windowOrder(_ i: Int) -> WindowOrderPreference { CachedUserDefaults.macroPref(indexToName("windowOrder", i), WindowOrderPreference.allCases) }
    static func groupApps(_ i: Int) -> GroupAppsPreference { CachedUserDefaults.macroPref(indexToName("showAppsOrWindows", i), GroupAppsPreference.allCases) }
    static func groupTabs(_ i: Int) -> GroupTabsPreference { CachedUserDefaults.macroPref(indexToName("showTabsAsWindows", i), GroupTabsPreference.allCases) }
    static var shortcutStyle: ShortcutStylePreference { CachedUserDefaults.macroPref("shortcutStyle", ShortcutStylePreference.allCases) }
    static var menubarIcon: MenubarIconPreference { CachedUserDefaults.macroPref("menubarIcon", MenubarIconPreference.allCases) }
    static var menubarIconShown: Bool { CachedUserDefaults.bool("menubarIconShown") }
    static var language: LanguagePreference { CachedUserDefaults.macroPref("language", LanguagePreference.allCases) }

    static let minShortcutCount = 1
    static let maxShortcutCount = IncludedFeatures.keyboardShortcutCount
    static var shortcutCount: Int {
        max(minShortcutCount, min(maxShortcutCount, CachedUserDefaults.int("shortcutCount")))
    }

    static let gestureIndex = IncludedFeatures.gestureIndex

    static func initialize() {
        LegacyPreferencesImporter.importIfNeeded()
        PreferencesMigrations.removeCorruptedPreferences()
        PreferencesMigrations.migratePreferences()
        registerDefaults()
    }

    static func resetAll() {
        resetAll(defaults, defaultsDomainName)
    }

    static func resetAll(_ targetDefaults: UserDefaults, _ domainName: String) {
        replacePersistentDomain([:], targetDefaults, domainName)
    }

    static func replacePersistentDomain(_ values: [String: Any]) {
        replacePersistentDomain(values, defaults, defaultsDomainName)
    }

    static func replacePersistentDomain(_ values: [String: Any], _ targetDefaults: UserDefaults, _ domainName: String) {
        let existing = targetDefaults.persistentDomain(forName: domainName) ?? [:]
        var replacement = values
        for key in persistentDomainStateKeys {
            replacement.removeValue(forKey: key)
            if let value = existing[key] { replacement[key] = value }
        }
        targetDefaults.setPersistentDomain(replacement, forName: domainName)
        CachedUserDefaults.cache.withLock { $0.removeAll() }
        invalidateAllCache()
    }

    static func registerDefaults() {
        defaults.register(defaults: defaultValues)
    }

    static func markSettingsWindowShownOnFirstLaunch() {
        set("settingsWindowShownOnFirstLaunch", "true", false)
    }

    static func defaultShortcut(_ keyEquivalent: String) -> [String: Any] {
        shortcutStorage(shortcutFromKeyEquivalent(keyEquivalent), keyEquivalent)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, _ notify: Bool = true) {
        setShortcut(key, shortcut, stringRepresentation: nil, notify)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, stringRepresentation: String?, _ notify: Bool = true) {
        defaults.set(shortcutStorage(shortcut, stringRepresentation), forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static func setShortcut(_ key: String, keyEquivalent: String, _ notify: Bool = true) {
        setShortcut(key, shortcutFromKeyEquivalent(keyEquivalent), stringRepresentation: keyEquivalent, notify)
    }

    static func shortcut(_ key: String) -> Shortcut? {
        CachedUserDefaults.shortcut(key)
    }

    static func set<T>(_ key: String, _ value: T, _ notify: Bool = true) where T: Encodable {
        defaults.set(key == "exceptions" ? jsonEncode(value) : value, forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static func remove(_ key: String, _ notify: Bool = true) {
        defaults.removeObject(forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    /// `persistentDomain(forName:)` rebuilds a full snapshot dictionary on every call, which adds
    /// up: every `hasOverride` / `effectiveAppearanceStyle` consults `all`, and the switcher show
    /// path triggers a cascade of these per show. Cache the filtered snapshot; the only paths that
    /// mutate the domain (`set`, `setShortcut`, `remove`, `resetAll`, `replacePersistentDomain`) clear `cachedAll` below.
    private static var cachedAll: [String: Any]?

    static var all: [String: Any] {
        if let cachedAll { return cachedAll }
        let domain = defaults.persistentDomain(forName: defaultsDomainName) ?? [:]
        let filtered = domain.filter { ownedKeys.contains($0.key) }
        cachedAll = filtered
        return filtered
    }

    static func invalidateAllCache() {
        cachedAll = nil
    }

    static func onlyShowMainWindows(_ index: Int = SwitcherSession.activeShortcutIndex) -> Bool {
        return groupApps(index) == .mainWindow
    }

    // MARK: - Per-shortcut appearance overrides

    /// The 5 override base names. Their indexed forms (e.g. `appearanceStyleOverride2`) live in
    /// `Preferences.all` only when the user has explicitly set an override on that shortcut.
    static let appearanceOverrideBaseNames = IncludedFeatures.overrideBaseNames

    /// Reverse lookup from an override base name to the global key it overrides.
    static let overrideToGlobalKey: [String: String] = [
        "appearanceStyleOverride": "appearanceStyle",
        "appearanceSizeOverride": "appearanceSize",
        "appearanceThemeOverride": "appearanceTheme",
        "shortcutStyleOverride": "shortcutStyle",
        "previewFocusedWindowOverride": "previewFocusedWindow",
    ]

    /// True when the user has explicitly set an override for `baseName` on shortcut `index`.
    /// Reads from `persistentDomain` (`Preferences.all`) which excludes registered defaults, so
    /// an untouched override correctly reports `false` even though its key has a registered default.
    static func hasOverride(_ baseName: String, _ index: Int) -> Bool {
        all[indexToName(baseName, index)] != nil
    }

    static func removeOverride(_ baseName: String, _ index: Int) {
        remove(indexToName(baseName, index))
    }

    /// Indices (0..shortcutCount) whose stored override value differs from the current global.
    /// Used to render "Overridden in Shortcut: 1, 3" labels in AppearanceTab.
    static func shortcutIndicesWithDifferentValue(_ baseName: String, globalKey: String) -> [Int] {
        let globalValue = defaults.string(forKey: globalKey)
        return (0..<shortcutCount).filter { index in
            let key = indexToName(baseName, index)
            guard let overrideValue = all[key] as? String else { return false }
            return overrideValue != globalValue
        }
    }

    static func effectiveAppearanceStyle(_ index: Int) -> AppearanceStylePreference {
        let override = hasOverride("appearanceStyleOverride", index) ? CachedUserDefaults.macroPref(indexToName("appearanceStyleOverride", index), AppearanceStylePreference.allCases) : nil
        return override ?? appearanceStyle
    }

    static func effectiveAppearanceSize(_ index: Int) -> AppearanceSizePreference {
        let override = hasOverride("appearanceSizeOverride", index) ? CachedUserDefaults.macroPref(indexToName("appearanceSizeOverride", index), AppearanceSizePreference.allCases) : nil
        return override ?? appearanceSize
    }

    static func effectiveAppearanceTheme(_ index: Int) -> AppearanceThemePreference {
        let override = hasOverride("appearanceThemeOverride", index) ? CachedUserDefaults.macroPref(indexToName("appearanceThemeOverride", index), AppearanceThemePreference.allCases) : nil
        return override ?? appearanceTheme
    }

    static func effectiveShortcutStyle(_ index: Int) -> ShortcutStylePreference {
        let override = hasOverride("shortcutStyleOverride", index) ? CachedUserDefaults.macroPref(indexToName("shortcutStyleOverride", index), ShortcutStylePreference.allCases) : nil
        return override ?? shortcutStyle
    }

    static func effectivePreviewSelectedWindow(_ index: Int) -> Bool {
        let override = hasOverride("previewFocusedWindowOverride", index) ? CachedUserDefaults.bool(indexToName("previewFocusedWindowOverride", index)) : nil
        return override ?? previewSelectedWindow
    }

    /// Which Screen-Recording-dependent features any shortcut's effective settings rely on: the
    /// Thumbnails appearance style (window screenshots) and/or the "preview selected window" overlay.
    /// These are the only features needing the permission, so when none are configured the menubar
    /// callout that nags about the missing permission is pointless and is suppressed (see #5623). The
    /// result also drives which feature(s) the callout names. We OR each flag across every shortcut
    /// slot, so a per-shortcut override that enables Thumbnails/Preview on any one slot flips it on.
    /// The pure classification lives in `PermissionCalloutResolver` (unit-tested).
    static var screenRecordingDependentFeatures: PermissionCalloutResolver.DependentFeatures {
        var usesThumbnails = false
        var usesPreviews = false
        for index in 0...maxShortcutCount {
            usesThumbnails = usesThumbnails || effectiveAppearanceStyle(index) == .thumbnails
            usesPreviews = usesPreviews || effectivePreviewSelectedWindow(index)
            if usesThumbnails && usesPreviews { break }
        }
        return PermissionCalloutResolver.dependentFeatures(usesThumbnails: usesThumbnails, usesPreviews: usesPreviews)
    }

    /// key-above-tab is ` on US keyboard, but can be different on other keyboards
    static func keyAboveTabDependingOnInputSource() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_ANSI_Grave)) ?? "`"
    }

    static func returnKeyEquivalent() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_Return)) ?? "↩"
    }

    static func defaultExceptions() -> String {
        return jsonEncode([
            ExceptionEntry(bundleIdentifier: "com.apple.finder", hide: .whenNoOpenWindow, ignore: .none),
            ExceptionEntry(bundleIdentifier: "com.apple.ScreenSharing", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.microsoft.rdc.macos", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.teamviewer.TeamViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "org.virtualbox.app.VirtualBoxVM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.parallels.", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.XenAppViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.receiver.icaviewer.mac", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.nicesoftware.dcvviewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.vmware.fusion", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.utmapp.UTM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.McAfee.McAfeeSafariHost", hide: .always, ignore: .none),
        ])
    }

    static func jsonEncode<T>(_ value: T) -> String where T: Encodable {
        return String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }

    static func archiveShortcut(_ shortcut: Shortcut?) -> Data {
        if #available(macOS 10.13, *) {
            return try! NSKeyedArchiver.archivedData(withRootObject: shortcut ?? emptyShortcut, requiringSecureCoding: true)
        }
        return NSKeyedArchiver.archivedData(withRootObject: shortcut ?? emptyShortcut)
    }

    static func shortcutStorage(_ shortcut: Shortcut?, _ stringRepresentation: String?) -> [String: Any] {
        [
            shortcutStorageStringField: stringRepresentation ?? shortcut?.readableStringRepresentation(isASCII: true) ?? "",
            shortcutStorageDataField: archiveShortcut(shortcut),
        ]
    }

    static func decodeShortcutStorage(_ value: Any) -> (Bool, Shortcut?) {
        guard let storage = value as? [String: Any], let data = storage[shortcutStorageDataField] as? Data else { return (false, nil) }
        return unarchiveShortcut(data)
    }

    static func unarchiveShortcut(_ data: Data) -> (Bool, Shortcut?) {
        let shortcut: Shortcut?
        if #available(macOS 10.13, *) {
            shortcut = try? NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data)
        } else {
            shortcut = NSKeyedUnarchiver.unarchiveObject(with: data) as? Shortcut
        }
        guard let shortcut else { return (false, nil) }
        return (true, shortcut.keyCode == .none && shortcut.modifierFlags == [] ? nil : shortcut)
    }

    static func shortcutFromKeyEquivalent(_ keyEquivalent: String) -> Shortcut? {
        keyEquivalent.isEmpty ? nil : Shortcut(keyEquivalent: keyEquivalent)
    }

    static func indexToName(_ baseName: String, _ index: Int) -> String {
        baseName + (index == 0 ? "" : String(index + 1))
    }

    static func nameToIndex(_ name: String) -> Int {
        let digits = String(name.reversed().prefix { $0.isNumber }.reversed())
        guard !digits.isEmpty, let number = Int(digits) else { return 0 }
        return number - 1
    }

    static func activeShortcutPreferenceKeys(shortcutCount: Int) -> [String] {
        Array(0..<min(max(shortcutCount, 0), maxShortcutCount)).flatMap { index in
            IncludedFeatures.shortcutTriggerBaseNames.map { indexToName($0, index) }
        }
    }

    static func shortcutRegistrationPlan(shortcutCount: Int) -> ShortcutRegistrationPlan {
        let supportedKeys = activeShortcutPreferenceKeys(shortcutCount: maxShortcutCount)
        return ShortcutRegistrationPlan(activeKeys: Set(activeShortcutPreferenceKeys(shortcutCount: shortcutCount)), supportedKeys: supportedKeys)
    }

    static func canAddShortcut(_ currentCount: Int) -> Bool {
        currentCount >= minShortcutCount && currentCount < maxShortcutCount
    }
}

class CachedUserDefaults {
    static var cache = ConcurrentMap<String, Any>()

    static func removeFromCache(_ key: String) {
        cache.withLock { $0.removeValue(forKey: key) }
    }

    /// retrieve strings in the globalDomain (e.g. defaults read -g KeyRepeat)
    /// these may be nil since we they don't have default values from AltTab
    static func globalString(_ key: String) -> String? {
        if let cached = cache.withLock({ $0[key] }) {
            return cached as? String
        }
        if let string = Preferences.defaults.string(forKey: key) {
            cache.withLock { $0[key] = string }
        }
        return nil
    }

    static func string(_ key: String) -> String {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as! String
        }
        let finalValue = Preferences.defaults.string(forKey: key)!
        cache.withLock { $0[key] = finalValue }
        return finalValue
    }

    static func shortcut(_ key: String) -> Shortcut? {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as? Shortcut
        }
        guard let objectValue = Preferences.defaults.object(forKey: key) else {
            cache.withLock { $0[key] = NSNull() }
            return nil
        }
        let (isValid, finalValue) = Preferences.decodeShortcutStorage(objectValue)
        if isValid {
            cache.withLock { $0[key] = finalValue ?? NSNull() }
            return finalValue
        }
        Preferences.defaults.removeObject(forKey: key)
        return shortcut(key)
    }

    static func int(_ key: String) -> Int {
        return getThenConvertOrReset(key, { s in Int(s) })
    }

    static func bool(_ key: String) -> Bool {
        return getThenConvertOrReset(key, { s in Bool(s) })
    }

    static func double(_ key: String) -> Double {
        return getThenConvertOrReset(key, { s in Double(s) })
    }

    static func macroPref<A>(_ key: String, _ macroPreferences: [A]) -> A {
        return getThenConvertOrReset(key, { s in Int(s).flatMap { macroPreferences[safe: $0] } })
    }

    /// some UI elements (e.g. dropdown, radios) need an int. We find the right int from the MacroPreference index
    static func intFromMacroPref(_ key: String, _ macroPreferences: [MacroPreference]) -> Int {
        let macroPref = macroPref(key, macroPreferences)
        return macroPreferences.firstIndex { $0.localizedString == macroPref.localizedString }!
    }

    static func json<T>(_ key: String, _ type: T.Type) -> T where T: Decodable {
        return getThenConvertOrReset(key, { s in jsonDecode(s, type) })
    }

    private static func getThenConvertOrReset<T>(_ key: String, _ getterFn: (String) -> T?) -> T {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as! T
        }
        let stringValue = Preferences.defaults.string(forKey: key)!
        if let finalValue = getterFn(stringValue) {
            cache.withLock { $0[key] = finalValue }
            return finalValue
        }
        // value couldn't be read properly; we remove it and work with the default
        Preferences.defaults.removeObject(forKey: key)
        let defaultStringValue = Preferences.defaults.string(forKey: key)!
        let defaultFinalValue = getterFn(defaultStringValue)!
        cache.withLock { $0[key] = defaultFinalValue }
        return defaultFinalValue
    }

    private static func jsonDecode<T>(_ value: String, _ type: T.Type) -> T? where T: Decodable {
        return value.data(using: .utf8).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

struct ExceptionEntry: Codable {
    var bundleIdentifier: String
    var hide: ExceptionHidePreference
    var ignore: ExceptionIgnorePreference
    var windowTitleContains: [String]?

    init(bundleIdentifier: String, hide: ExceptionHidePreference, ignore: ExceptionIgnorePreference, windowTitleContains: [String]? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.hide = hide
        self.ignore = ignore
        self.windowTitleContains = windowTitleContains
    }

    // Permissive decoder so we can read both the legacy single-string shape
    // (windowTitleContains: String?) and the current array shape ([String]?). Without this,
    // a decode failure on legacy data would cause `getThenConvertOrReset` in Preferences to
    // wipe the entry back to defaultExceptions(), losing the user's patterns.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        self.hide = try c.decode(ExceptionHidePreference.self, forKey: .hide)
        self.ignore = try c.decode(ExceptionIgnorePreference.self, forKey: .ignore)
        if let array = try? c.decode([String].self, forKey: .windowTitleContains) {
            self.windowTitleContains = array.isEmpty ? nil : array
        } else if let string = try? c.decode(String.self, forKey: .windowTitleContains), !string.isEmpty {
            self.windowTitleContains = [string]
        } else {
            self.windowTitleContains = nil
        }
    }
}
