# LegacyPreferencesImporter — Specs

## Purpose

Altab performs one automatic, local import from AltTab's `com.lwouis.alt-tab-macos` defaults domain. The operation copies compatible user configuration into `dev.salasebas.Altab` without changing the AltTab domain, its license suite, or either app's Keychain data. It runs before Altab's normal preference migration and default registration.

The importer stores `legacyPreferencesImportCompleted` only in Altab's domain. A missing source is a completed no-op, and later launches do not re-read or re-import source choices. `Preferences.replacePersistentDomain` preserves this internal marker whenever Reset Settings or Settings Import replaces the user-owned domain, so neither workflow can silently repopulate settings from AltTab on the next launch. Values already present in Altab's persistent domain always win; registered defaults do not count as explicit values.

## Imported matrix

Every imported key belongs to `Preferences.ownedKeys` and has a category-specific validator.

| Category | Keys | Validation |
| --- | --- | --- |
| Configuration size | `shortcutCount` | Integer string, `1...9` |
| Gesture | `nextWindowGesture` | Current enum index |
| Static shortcuts | Focus, previous, cancel, close, minimize/deminimize, fullscreen, quit, hide/show app, search | Exact bounded storage dictionary, successful secure app decode, then canonical re-archive |
| Keyboard triggers | `holdShortcut` and `nextWindowShortcut`, keyboard indices `0...8` | Exact bounded storage dictionary, successful secure app decode, then canonical re-archive |
| Input behavior | Arrow keys, Vim keys, mouse hover, cursor-follow-focus, trackpad haptics | Exact Bool or current enum index |
| Appearance | Colored-circle, thumbnail, space-label and status-icon visibility; appearance style/size/theme; legacy theme; titles and truncation; active screen; display delay; fade animations; preview/capture behavior | Exact Bool, current enum index, or display delay `0...900` ms |
| Menu/language | Menu icon style/visibility and language | Exact Bool or current enum index |
| Exceptions | `exceptions` | JSON decodes as current `[ExceptionEntry]`, including valid enum values and non-empty bundle identifiers |
| Per-configuration | All 16 keys in `IncludedFeatures.perShortcutPreferenceBaseNames` across keyboard `0...8` and gesture `9` | Current enum range or exact Bool by key |

Malformed allowed values are skipped independently. Unknown keys and unsupported indices are ignored.

## Explicit exclusions

- Altab never imports `preferencesVersion`; a source version is read only to normalize an in-memory copy through `PreferencesMigrations`. Altab's existing version is never overwritten or used to classify the upstream profile.
- `startAtLogin` is excluded so installing Altab cannot cause both apps to launch.
- `screenRecordingPermissionSkipped`, `settingsWindowShownOnFirstLaunch`, onboarding state, and permission flags are excluded because permissions and first-run state do not transfer across bundle identities.
- License/trial/pro-transition state, customer/account/checkout/cookies/fingerprints/activation data, usage/conversion/analytics counters, updater/Sparkle/appcast fields, crash/service fields, and window geometry/transient UI state are excluded.
- The importer contains no Security/Keychain API and never reads a Keychain item.

The only license-suite reads are the six integer keys below from `com.lwouis.alt-tab-macos.license`. They are recovery inputs, not imported license state:

| Snapshot | Main-domain choice | Forced fallback required |
| --- | --- | --- |
| `proTransition.rememberedAppearanceStyle` | `appearanceStyle` | `0` |
| `proTransition.rememberedAppearanceSize` | `appearanceSize` | `1` |
| `proTransition.rememberedShortcutStyle` | `shortcutStyle` | `1` |
| `proTransition.rememberedAppearanceStyleOverride` | index-0 `appearanceStyleOverride` | `0` |
| `proTransition.rememberedAppearanceSizeOverride` | index-0 `appearanceSizeOverride` | `1` |
| `proTransition.rememberedShortcutStyleOverride` | index-0 `shortcutStyleOverride` | `1` |

Each snapshot must be an integer in the current enum range, and the source main value must still equal the known forced fallback. The source dictionaries remain unchanged. No license suite is written or created for Altab, and historical license/Keychain data is not deleted.

## Migration ordering

The importer recovers the six remembered choices into a value-copy of the source snapshot, then normalizes that copy through the existing source-version-gated `PreferencesMigrations` transforms with app-identity side effects disabled. After normalization, allowlist validation and missing-key copying occur. Altab's normal migration records `PreferencesMigrations.currentSchemaVersion`, currently `12.0.0`, which is deliberately independent from Altab's public app/build version. Domains written by earlier Altab builds with `preferencesVersion = 1` are recognized as already using the current owned schema and are advanced directly without legacy transforms. Imported current values and explicit Altab values therefore cannot be reinterpreted as pre-11.x upstream values.

Shortcut storage must be an exact two-field dictionary with a bounded string and data payload. The importer then calls the app's `NSSecureCoding` decoder behind an Objective-C exception boundary and re-archives a successful result through `Preferences.shortcutStorage`. It deliberately does not depend on the private `NSKeyedArchiver` wire layout. Any shape, size, decoding, or exception failure skips that shortcut. Obsolete string/data formats are also skipped instead of being guessed.

## Regression guards

- Unit tests pin the allowlist to every currently owned key except the three bundle-identity exclusions, exercise every category and index, verify current canonical shortcut fixtures and reject plausible fake archives, cover Altab-version-`1` ordering, and prove reset or settings-import replacement followed by relaunch cannot re-import.
- `scripts/check_legacy_preferences_import.sh` restricts source-domain literals, forbids source-domain mutation APIs, and rejects Security/Keychain symbols in importer production code.
- Tests use isolated destination suites and source dictionaries. They never read or modify the developer's real defaults domains.
