import Cocoa
import XCTest

final class LegacyPreferencesImporterTests: XCTestCase {
    private var destination: UserDefaults!
    private var destinationDomainName: String!
    private var registrationDomain: [String: Any]!

    override func setUp() {
        super.setUp()
        destinationDomainName = "test-legacy-import-destination-\(UUID().uuidString)"
        destination = UserDefaults(suiteName: destinationDomainName)!
        registrationDomain = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        PreferencesMigrations.legacyIncludedFeaturesDefaults = nil
        ObjCExceptionCatcher.failAttempts = false
    }

    override func tearDown() {
        ObjCExceptionCatcher.failAttempts = false
        UserDefaults().removePersistentDomain(forName: destinationDomainName)
        UserDefaults.standard.setVolatileDomain(registrationDomain, forName: UserDefaults.registrationDomain)
        PreferencesMigrations.defaults = UserDefaults.standard
        Preferences.invalidateAllCache()
        super.tearDown()
    }

    func testNoSourceIsACompletedNoOp() {
        let result = run(nil)
        XCTAssertEqual(result, .noSource)
        XCTAssertEqual(persistent()[LegacyPreferencesImporter.completionKey] as? Bool, true)
        XCTAssertEqual(persistent().count, 1)
    }

    func testFullValidImportCoversEveryAllowedOwnedPreference() {
        let source = LegacyPreferencesImporter.validators.mapValues(validSourceValue)
        let result = run(source)
        XCTAssertEqual(result, .imported(importedCount: LegacyPreferencesImporter.allowedKeys.count, invalidCount: 0, preservedCount: 0))
        let stored = persistent()
        XCTAssertEqual(Set(stored.keys), LegacyPreferencesImporter.allowedKeys.union([LegacyPreferencesImporter.completionKey]))
        LegacyPreferencesImporter.allowedKeys.forEach { XCTAssertNotNil(stored[$0], "missing \($0)") }
    }

    func testPartialProfilePreservesPersistentValuesButNotRegisteredDefaults() {
        destination.register(defaults: ["appearanceStyle": "0", "language": "0"])
        destination.set("1", forKey: "appearanceStyle")
        let result = run(["appearanceStyle": "2", "language": "3"])
        XCTAssertEqual(result, .imported(importedCount: 1, invalidCount: 0, preservedCount: 1))
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "1")
        XCTAssertEqual(destination.string(forKey: "language"), "3")
    }

    func testRepeatedImportDoesNotReadNewChoicesOrOverwriteImportedValues() {
        XCTAssertEqual(run(["language": "3"]), .imported(importedCount: 1, invalidCount: 0, preservedCount: 0))
        XCTAssertEqual(run(["language": "4", "appearanceStyle": "2"]), .alreadyCompleted)
        XCTAssertEqual(destination.string(forKey: "language"), "3")
        XCTAssertNil(persistent()["appearanceStyle"])
    }

    func testMalformedValuesAreSkippedIndependently() {
        let source: [String: Any] = [
            "arrowKeysEnabled": "yes",
            "appearanceStyle": ["2"],
            "windowDisplayDelay": "12.5",
            "focusWindowShortcut": ["secureData": Data([0x00])],
            "exceptions": "not-json",
            "language": "3",
        ]
        XCTAssertEqual(run(source), .imported(importedCount: 1, invalidCount: 5, preservedCount: 0))
        XCTAssertEqual(destination.string(forKey: "language"), "3")
        ["arrowKeysEnabled", "appearanceStyle", "windowDisplayDelay", "focusWindowShortcut", "exceptions"].forEach {
            XCTAssertNil(persistent()[$0])
        }
    }

    func testOutOfRangeEnumsShortcutCountAndIndexesAreRejected() {
        let source: [String: Any] = [
            "shortcutCount": "10",
            "appearanceStyle": "3",
            "nextWindowGesture": "5",
            "language": String(LanguagePreference.allCases.count),
            "appsToShow11": "0",
            "appsToShow1": "0",
            "holdShortcut10": shortcutStorage(),
            "madeUpPreference": "0",
        ]
        XCTAssertEqual(run(source), .imported(importedCount: 0, invalidCount: 4, preservedCount: 0))
        XCTAssertEqual(Set(persistent().keys), [LegacyPreferencesImporter.completionKey])
    }

    func testUnknownBannedIdentityPermissionLoginUpdateServiceAndLicenseFieldsNeverImport() {
        let banned: [String: Any] = [
            "licenseKey": "secret",
            "trialStartDate": 1,
            "proTransition.isFreshInstall": true,
            "customerEmail": "person@example.com",
            "accountId": "customer",
            "checkoutSession": "checkout",
            "licenseCookie": "cookie",
            "machineFingerprint": "machine",
            "activationCode": "activation",
            "usageCount": 9,
            "conversionCount": 3,
            "analyticsEnabled": true,
            "updatePolicy": "0",
            "SU" + "EnableAutomaticChecks": true,
            "appcast" + "URL": "https://example.invalid",
            "crashPolicy": "0",
            "App" + "CenterSecret": "service",
            "NSWindow Frame SettingsWindow": "1 2 3 4",
            "startAtLogin": "false",
            "screenRecordingPermissionSkipped": "true",
            "settingsWindowShownOnFirstLaunch": "true",
            "accessibilityPermissionGranted": true,
            "preferencesVersion": "11.4.3",
        ]
        XCTAssertEqual(run(banned), .imported(importedCount: 0, invalidCount: 0, preservedCount: 0))
        banned.keys.forEach { XCTAssertNil(persistent()[$0], "imported banned key \($0)") }
    }

    func testSourceSnapshotRemainsByteForByteUnchanged() throws {
        let source: [String: Any] = [
            "appearanceStyle": "2",
            "focusWindowShortcut": shortcutStorage(),
            "licenseKey": "untouched",
            "preferencesVersion": "11.4.3",
        ]
        let before = try binaryPropertyList(source)
        _ = run(source, rememberedSelections: ["proTransition.rememberedAppearanceStyle": 1])
        XCTAssertEqual(try binaryPropertyList(source), before)
    }

    func testEveryPerShortcutSettingImportsAcrossKeyboardAndGestureConfigurations() {
        var source = [String: Any]()
        for index in IncludedFeatures.configurationIndices {
            for baseName in IncludedFeatures.perShortcutPreferenceBaseNames {
                source[Preferences.indexToName(baseName, index)] = validValue(baseName)
            }
        }
        XCTAssertEqual(source.count, 16 * 10)
        XCTAssertEqual(run(source), .imported(importedCount: 160, invalidCount: 0, preservedCount: 0))
        source.forEach { XCTAssertEqual(destination.string(forKey: $0.key), $0.value as? String) }
    }

    func testEveryKeyboardShortcutImportsAndGestureTriggerKeysRemainUnsupported() {
        var source = [String: Any]()
        for index in IncludedFeatures.keyboardShortcutIndices {
            source[Preferences.indexToName("holdShortcut", index)] = shortcutStorage()
            source[Preferences.indexToName("nextWindowShortcut", index)] = shortcutStorage()
        }
        source[Preferences.indexToName("holdShortcut", IncludedFeatures.gestureIndex)] = shortcutStorage()
        XCTAssertEqual(run(source), .imported(importedCount: 18, invalidCount: 0, preservedCount: 0))
        for index in IncludedFeatures.keyboardShortcutIndices {
            XCTAssertTrue(LegacyPreferencesImporter.isValidShortcutStorage(persistent()[Preferences.indexToName("holdShortcut", index)] as Any))
            XCTAssertTrue(LegacyPreferencesImporter.isValidShortcutStorage(persistent()[Preferences.indexToName("nextWindowShortcut", index)] as Any))
        }
        XCTAssertNil(persistent()[Preferences.indexToName("holdShortcut", IncludedFeatures.gestureIndex)])
    }

    func testSecureShortcutStorageCompatibility() {
        let secure = shortcutStorage()
        XCTAssertTrue(Preferences.decodeShortcutStorage(secure).0)
        let source: [String: Any] = [
            "focusWindowShortcut": secure,
            "closeWindowShortcut": secure,
            "quitAppShortcut": secure,
        ]
        XCTAssertEqual(run(source), .imported(importedCount: 3, invalidCount: 0, preservedCount: 0))
        ["focusWindowShortcut", "closeWindowShortcut", "quitAppShortcut"].forEach {
            guard let storage = persistent()[$0] as? [String: Any] else { return XCTFail("missing storage for \($0)") }
            XCTAssertNotNil(storage["secureData"] as? Data)
            XCTAssertTrue(LegacyPreferencesImporter.isValidShortcutStorage(storage))
        }
    }

    func testCanonicalEmptyShortcutStorageCompatibility() {
        let secure = Preferences.shortcutStorage(nil, "")
        let decoded = Preferences.decodeShortcutStorage(secure)
        XCTAssertTrue(decoded.0)
        XCTAssertNil(decoded.1)
        guard let canonical = LegacyPreferencesImporter.canonicalShortcutStorage(secure) else { return XCTFail("canonical empty shortcut rejected") }
        XCTAssertTrue(Preferences.decodeShortcutStorage(canonical).0)
        XCTAssertEqual(canonical["string"] as? String, "")
    }

    func testStructurallyPlausibleButUndecodableShortcutArchiveIsRejected() {
        let fake = structurallyPlausibleShortcutStorage()
        XCTAssertNil(LegacyPreferencesImporter.canonicalShortcutStorage(fake))
        XCTAssertEqual(run(["focusWindowShortcut": fake]), .imported(importedCount: 0, invalidCount: 1, preservedCount: 0))
        XCTAssertNil(persistent()["focusWindowShortcut"])
    }

    func testShortcutExceptionBoundaryFailureRejectsWithoutDecoding() {
        ObjCExceptionCatcher.failAttempts = true
        let secure = shortcutStorage()
        XCTAssertNil(LegacyPreferencesImporter.canonicalShortcutStorage(secure))
        XCTAssertEqual(run(["focusWindowShortcut": secure]), .imported(importedCount: 0, invalidCount: 1, preservedCount: 0))
        XCTAssertNil(persistent()["focusWindowShortcut"])
    }

    func testExceptionsRequireValidCurrentJSON() {
        let valid = Preferences.jsonEncode([ExceptionEntry(bundleIdentifier: "com.example.app", hide: .always, ignore: .none, windowTitleContains: ["Document"])] )
        XCTAssertEqual(run(["exceptions": valid]), .imported(importedCount: 1, invalidCount: 0, preservedCount: 0))
        XCTAssertEqual(destination.string(forKey: "exceptions"), valid)
    }

    func testExceptionsRejectInvalidEnumsShapeAndEmptyBundleIdentifiers() {
        let values = [
            #"[{"bundleIdentifier":"com.example","hide":"9","ignore":"0"}]"#,
            #"{"bundleIdentifier":"com.example","hide":"1","ignore":"0"}"#,
            #"[{"bundleIdentifier":"   ","hide":"1","ignore":"0"}]"#,
        ]
        for value in values {
            let suiteName = "test-invalid-exceptions-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            let result = LegacyPreferencesImporter.importIfNeeded(destination: defaults, destinationDomainName: suiteName, sourceDomain: ["exceptions": value], rememberedSelections: [:])
            XCTAssertEqual(result, .imported(importedCount: 0, invalidCount: 1, preservedCount: 0))
            XCTAssertNil(defaults.persistentDomain(forName: suiteName)?["exceptions"])
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
    }

    func testOlderSourceIsNormalizedWithoutChangingAlTabPreferencesVersion() {
        destination.set("99.99.99", forKey: "preferencesVersion")
        destination.set("1", forKey: "appearanceStyle")
        let source: [String: Any] = [
            "preferencesVersion": "7.13.1",
            "nextWindowGesture": "2",
            "appearanceStyle": "0",
        ]
        XCTAssertEqual(run(source), .imported(importedCount: 1, invalidCount: 0, preservedCount: 1))
        XCTAssertEqual(destination.string(forKey: "nextWindowGesture"), "3")
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "1")
        XCTAssertEqual(destination.string(forKey: "preferencesVersion"), "99.99.99")
    }

    func testImportThenAlTabSchemaMigrationPreservesCurrentImportedAndExplicitValues() {
        destination.setPersistentDomain(["language": "3", "preferencesVersion": "1"], forName: destinationDomainName)
        let source: [String: Any] = [
            "language": "4",
            "nextWindowGesture": "2",
            "preferencesVersion": "11.4.3",
            "showWindowlessApps": "2",
        ]
        XCTAssertEqual(run(source), .imported(importedCount: 2, invalidCount: 0, preservedCount: 1))
        PreferencesMigrations.defaults = destination
        PreferencesMigrations.migratePreferences()
        XCTAssertEqual(destination.string(forKey: "language"), "3")
        XCTAssertEqual(destination.string(forKey: "nextWindowGesture"), "2")
        XCTAssertEqual(destination.string(forKey: "showWindowlessApps"), "2")
        XCTAssertEqual(destination.string(forKey: "preferencesVersion"), PreferencesMigrations.currentSchemaVersion)
    }

    func testResetPreservesCompletionAndNextLaunchDoesNotReimport() {
        XCTAssertEqual(run(["language": "3"]), .imported(importedCount: 1, invalidCount: 0, preservedCount: 0))
        Preferences.resetAll(destination, destinationDomainName)
        XCTAssertEqual(persistent() as NSDictionary, [LegacyPreferencesImporter.completionKey: true] as NSDictionary)
        XCTAssertEqual(run(["language": "4"]), .alreadyCompleted)
        XCTAssertNil(persistent()["language"])
    }

    func testSettingsImportReplacementPreservesCompletionAndNextLaunchDoesNotReimport() {
        XCTAssertEqual(run(["language": "3"]), .imported(importedCount: 1, invalidCount: 0, preservedCount: 0))
        Preferences.replacePersistentDomain(["appearanceStyle": "2"], destination, destinationDomainName)
        XCTAssertEqual(persistent() as NSDictionary, ["appearanceStyle": "2", LegacyPreferencesImporter.completionKey: true] as NSDictionary)
        XCTAssertEqual(run(["language": "4"]), .alreadyCompleted)
        XCTAssertNil(persistent()["language"])
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "2")
    }

    func testAllSixRememberedSelectionsRecoverFromKnownForcedFallbacks() {
        let source: [String: Any] = [
            "appearanceStyle": "0",
            "appearanceSize": "1",
            "shortcutStyle": "1",
            "appearanceStyleOverride": "0",
            "appearanceSizeOverride": "1",
            "shortcutStyleOverride": "1",
        ]
        let remembered = Dictionary(uniqueKeysWithValues: zip(LegacyPreferencesImporter.rememberedSelectionKeys, [2, 3, 2, 1, 3, 2]))
        XCTAssertEqual(run(source, rememberedSelections: remembered), .imported(importedCount: 6, invalidCount: 0, preservedCount: 0))
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "2")
        XCTAssertEqual(destination.string(forKey: "appearanceSize"), "3")
        XCTAssertEqual(destination.string(forKey: "shortcutStyle"), "2")
        XCTAssertEqual(destination.string(forKey: "appearanceStyleOverride"), "1")
        XCTAssertEqual(destination.string(forKey: "appearanceSizeOverride"), "3")
        XCTAssertEqual(destination.string(forKey: "shortcutStyleOverride"), "2")
    }

    func testRememberedSelectionsRequireIntegerRangeAndExactForcedFallback() {
        let source: [String: Any] = [
            "appearanceStyle": "1",
            "appearanceSize": "1",
            "shortcutStyle": "1",
            "appearanceStyleOverride": "0",
        ]
        let remembered: [String: Any] = [
            LegacyPreferencesImporter.rememberedSelectionKeys[0]: 2,
            LegacyPreferencesImporter.rememberedSelectionKeys[1]: 99,
            LegacyPreferencesImporter.rememberedSelectionKeys[2]: "2",
            LegacyPreferencesImporter.rememberedSelectionKeys[3]: -1,
            "proTransition.customerEmail": "ignored@example.com",
        ]
        XCTAssertEqual(run(source, rememberedSelections: remembered), .imported(importedCount: 4, invalidCount: 0, preservedCount: 0))
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "1")
        XCTAssertEqual(destination.string(forKey: "appearanceSize"), "1")
        XCTAssertEqual(destination.string(forKey: "shortcutStyle"), "1")
        XCTAssertEqual(destination.string(forKey: "appearanceStyleOverride"), "0")
        XCTAssertNil(persistent()["proTransition.customerEmail"])
    }

    func testExistingAlTabValueWinsOverRecoveredSourceSelection() {
        destination.set("1", forKey: "appearanceStyle")
        let remembered = [LegacyPreferencesImporter.rememberedSelectionKeys[0]: 2]
        XCTAssertEqual(run(["appearanceStyle": "0"], rememberedSelections: remembered), .imported(importedCount: 0, invalidCount: 0, preservedCount: 1))
        XCTAssertEqual(destination.string(forKey: "appearanceStyle"), "1")
    }

    func testAllowlistClassifiesEveryOwnedKeyAndRejectsBannedCategories() {
        XCTAssertEqual(LegacyPreferencesImporter.allowedKeys.count, 215)
        XCTAssertEqual(Preferences.ownedKeys.subtracting(LegacyPreferencesImporter.allowedKeys), LegacyPreferencesImporter.excludedOwnedKeys)
        XCTAssertTrue(LegacyPreferencesImporter.allowedKeys.isDisjoint(with: LegacyPreferencesImporter.bannedExactKeys))
        XCTAssertEqual(Set(LegacyPreferencesImporter.rememberedSelectionKeys), [
            "proTransition.rememberedAppearanceStyle",
            "proTransition.rememberedAppearanceSize",
            "proTransition.rememberedShortcutStyle",
            "proTransition.rememberedAppearanceStyleOverride",
            "proTransition.rememberedAppearanceSizeOverride",
            "proTransition.rememberedShortcutStyleOverride",
        ])
        let banned = [
            "license", "trialStartDate", "proTransition.rememberedAppearanceStyle", "customerEmail",
            "accountId", "checkout", "cookie", "machineFingerprint", "activation", "usageCount",
            "conversionCount", "analytics", "updatePolicy", "SU" + "EnableAutomaticChecks", "appcast" + "URL",
            "crashPolicy", "App" + "CenterSecret", "NSWindow Frame SettingsWindow", "startAtLogin",
            "screenRecordingPermissionSkipped", "settingsWindowShownOnFirstLaunch", "onboardingComplete",
            "accessibilityPermissionGranted",
        ]
        banned.forEach { XCTAssertTrue(LegacyPreferencesImporter.isBannedKey($0), "not classified as banned: \($0)") }
    }

    private func run(_ source: [String: Any]?, rememberedSelections: [String: Any] = [:]) -> LegacyPreferencesImportResult {
        return LegacyPreferencesImporter.importIfNeeded(destination: destination, destinationDomainName: destinationDomainName, sourceDomain: source, rememberedSelections: rememberedSelections)
    }

    private func persistent() -> [String: Any] {
        return destination.persistentDomain(forName: destinationDomainName) ?? [:]
    }

    private func validValue(_ baseName: String) -> String {
        switch baseName {
            case "screensToShow", "showAppsOrWindows", "showTabsAsWindows": return "1"
            case "appearanceSizeOverride": return "3"
            case "previewFocusedWindowOverride": return "true"
            default: return "2"
        }
    }

    private func validSourceValue(_ validator: LegacyPreferenceValidator) -> Any {
        switch validator {
            case .boolean: return "false"
            case .enumeration: return "0"
            case .exceptions: return "[]"
            case let .integer(range): return String(range.lowerBound)
            case .shortcut: return shortcutStorage()
        }
    }

    private func shortcutStorage() -> [String: Any] {
        return Preferences.shortcutStorage(Preferences.shortcutFromKeyEquivalent("⌥"), "⌥")
    }

    private func structurallyPlausibleShortcutStorage() -> [String: Any] {
        let archive: [String: Any] = [
            "$archiver": "NSKeyedArchiver",
            "$objects": ["$null", ["$class": "fixture"], ["$classname": "SRShortcut", "$classes": ["SRShortcut", "NSObject"]]],
            "$top": ["root": "fixture"],
            "$version": 100_000,
        ]
        let data = try! PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0)
        return ["string": "⌘↩", "secureData": data]
    }

    private func binaryPropertyList(_ dictionary: [String: Any]) throws -> Data {
        return try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    }
}
