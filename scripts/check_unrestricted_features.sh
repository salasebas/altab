#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "unrestricted-features check failed: $1" >&2
  exit 1
}

reject_matches() {
  local description="$1"
  local pattern="$2"
  shift 2
  if rg -n --hidden "$pattern" "$@"; then
    fail "$description"
  fi
}

require_matches() {
  local description="$1"
  local pattern="$2"
  shift 2
  rg -q --hidden "$pattern" "$@" || fail "$description"
}

check_source() {
  plutil -lint Info.plist >/dev/null
  plutil -lint alt-tab-macos.xcodeproj/project.pbxproj >/dev/null
  if plutil -p Info.plist | rg '"(Domain|ApiDomain)"'; then
    fail "Info.plist contains a paid-service setting"
  fi

  local paidArchitecture='License(Manager|State|API)|RemoteLicenseClient|MachineFingerprint|SystemKeychain|Pro(GatedPreferences|Feature|Transition|Prompt|Badge|Gradient|Conversion)|Upgrade(Tab|MenuItem|Button)|upgradeToPro|isPro(Locked|Available)|proGatedIndices|attemptHardGatedFeature'
  local paidFallback='PreferenceDefinition|snapshotAndDowngrade|isStoredValuePro|free(Default|Tier)|revert(ed|s|ing)? (to )?(the )?free defaults?|downgrad(e|es|ed|ing) (a |the )?(stored )?preference'
  local paidUi='Altab Pro|Get Pro|Pro (feature|license|tier|trial)|Pro-only|Pro only|14-day (free )?trial|Start my .*trial|Trial (expired|ends|includes)|license key|Activate( your)? .*license|Deactivate( your)? .*license|My Account|Upgrade to Lifetime Pro|Unlock .* with Pro|one-time purchase|Manage activations|view receipts|money-back guarantee'
  local paidEndpoint='alt-tab\.app|LemonSqueezy|checkoutUrl|accountUrl|licenseApiBaseUrl|/v1/license|/my-account'

  reject_matches "production code or project contains paid-access architecture" "$paidArchitecture" --glob '*.swift' src alt-tab-macos.xcodeproj/project.pbxproj
  reject_matches "production code contains forced paid-tier preference fallback logic" "$paidFallback" --glob '*.swift' src
  reject_matches "live code, resources, or configuration contains a licensing/sales endpoint" "$paidEndpoint" -i --glob '*.swift' --glob '*.strings' --glob '*.xcconfig' src resources/l10n Info.plist config alt-tab-macos.xcodeproj/project.pbxproj
  reject_matches "live UI contains a paid-access, trial, or upsell phrase" "$paidUi" -i --glob '*.swift' --glob '*.strings' src resources/l10n
  reject_matches "application source contains license Keychain operations" 'SecItem(Add|Update|Delete|CopyMatching)|kSecClassGenericPassword|kSecAttrService' --glob '*.swift' src

  local removedPaths=(
    src/pro
    src/preferences/PreferenceDefinition.swift
    src/preferences/settings-window/tabs/UpgradeTab.swift
  )
  for path in "${removedPaths[@]}"; do
    [[ ! -e "$path" ]] || fail "$path still exists"
  done

  local catalog=src/features/IncludedFeatures.swift
  local tests=src/features/IncludedFeaturesTests.swift
  local specs=src/features/IncludedFeaturesSpecs.md
  for path in "$catalog" "$tests" "$specs"; do
    [[ -f "$path" ]] || fail "$path is missing"
  done
  for feature in searchInSwitcher searchOnReleaseShortcut autoSize appIconsAndTitlesStyle additionalShortcuts perShortcutOptions; do
    require_matches "included feature catalog is missing $feature" "case $feature" "$catalog"
  done
  require_matches "included feature catalog does not pin all nine shortcut slots" 'static let keyboardShortcutCount = 9' "$catalog"
  for override in appearanceStyleOverride appearanceSizeOverride appearanceThemeOverride shortcutStyleOverride previewFocusedWindowOverride; do
    require_matches "included feature matrix is missing $override" "\"$override\"" "$catalog" "$tests"
  done
  require_matches "unrestricted feature tests are not in the unit-test target" 'IncludedFeaturesTests\.swift' alt-tab-macos.xcodeproj/project.pbxproj
  require_matches "feature tests do not pin stored selections without fallback" 'testFormerlyRestrictedSelectionsAreReturnedWithoutFallback' "$tests"
  require_matches "feature tests do not pin every shortcut index" 'testEverySupportedShortcutKeyIsRegisteredAndExecutable' "$tests"
  require_matches "feature tests do not pin every per-shortcut option" 'testEveryPerShortcutPreferenceVariantIsRepresentedForKeyboardAndGesture' "$tests"

  require_matches "search entry is not wired into the switcher" 'SearchModeResolver\.enableEditing\(mode: searchMode\)' src/switcher/main-window/TilesView.swift
  require_matches "Search on Release no longer starts a search session" 'effectiveShortcutStyle\(shortcutIndex\) == \.searchOnRelease' src/App.swift
  require_matches "Auto size no longer reaches switcher layout" 'effectiveAppearanceSize\(SwitcherSession\.activeShortcutIndex\) == \.auto' src/switcher/main-window/TilesView.swift
  require_matches "App Icons no longer reaches switcher rendering" 'effectiveAppearanceStyle\(SwitcherSession\.activeShortcutIndex\) == \.appIcons' src/switcher/main-window/TileView.swift src/switcher/main-window/TilesView.swift
  require_matches "Titles no longer reaches switcher rendering" 'effectiveAppearanceStyle\(SwitcherSession\.activeShortcutIndex\) == \.titles' src/switcher/main-window/TileView.swift src/switcher/main-window/TilesPanel.swift
  require_matches "the complete shortcut capacity is no longer available" 'static let maxShortcutCount = IncludedFeatures\.keyboardShortcutCount' src/preferences/Preferences.swift
  require_matches "shortcut identifiers no longer resolve through the tested routing catalog" 'IncludedFeatures\.shortcutAction\(id\)' src/switcher/ShortcutAction.swift
  require_matches "hold shortcuts no longer execute the focus action" 'case \.focusTarget:' src/switcher/ShortcutAction.swift
  require_matches "next-window shortcuts no longer execute their indexed action" 'case \.showOrCycle\(let index\):' src/switcher/ShortcutAction.swift
  for consumer in effectiveAppearanceStyle effectiveAppearanceSize effectiveAppearanceTheme effectiveShortcutStyle effectivePreviewSelectedWindow; do
    require_matches "per-shortcut preference consumer $consumer is missing" "static func $consumer" src/preferences/Preferences.swift
  done
}

check_bundle() {
  local appPath="$1"
  local infoPath="$appPath/Contents/Info.plist"
  local resourcesPath="$appPath/Contents/Resources"
  [[ -d "$appPath" ]] || fail "app bundle not found: $appPath"
  plutil -lint "$infoPath" >/dev/null
  if plutil -p "$infoPath" | rg '"(Domain|ApiDomain)"|alt-tab\.app'; then
    fail "$appPath contains a paid-service setting"
  fi

  local executableName
  executableName="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$infoPath")"
  local executable="$appPath/Contents/MacOS/$executableName"
  local paidSymbols='License(Manager|State|API)|RemoteLicenseClient|MachineFingerprint|SystemKeychain|Pro(GatedPreferences|Feature|Transition|Prompt|Badge|Gradient|Conversion)|Upgrade(Tab|MenuItem|Button)|upgradeToPro|isProLocked|snapshotAndDowngrade'
  if strings "$executable" | rg "$paidSymbols|alt-tab\.app|LemonSqueezy|/v1/license|/my-account"; then
    fail "$appPath contains paid-access symbols or endpoints"
  fi
  if rg -a -n -i 'Altab Pro|Get Pro|Pro (feature|license|tier|trial)|Pro-only|14-day (free )?trial|Start my .*trial|Trial (expired|ends|includes)|license key|Activate( your)? .*license|Deactivate( your)? .*license|My Account|Upgrade to Lifetime Pro|Unlock .* with Pro|one-time purchase|Manage activations|view receipts|money-back guarantee|alt-tab\.app|LemonSqueezy' "$resourcesPath"; then
    fail "$appPath exposes paid-access, trial, account, or upsell content"
  fi

  for setting in '"App Icons"' '"Titles"' '"Auto"' '"Search"' '"Shortcut"' '"Ordering & Grouping"'; do
    rg -a -q -F "$setting" "$resourcesPath" || fail "$appPath is missing the included setting $setting"
  done
}

check_source
if [[ $# -gt 0 ]]; then
  for appPath in "$@"; do check_bundle "$appPath"; done
fi
echo "unrestricted-features check passed"
