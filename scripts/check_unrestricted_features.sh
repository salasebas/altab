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

require_production_wiring() {
  local contract="$1"
  local path="$2"
  rg -q -F "$contract" "$path" || fail "$path no longer uses $contract"
}

inspect_localized_resources() {
  local resourcesPath="$1"
  local resourcePath
  while IFS= read -r -d '' resourcePath; do
    plutil -p "$resourcePath" || return 1
  done < <(find "$resourcesPath" -type f -name '*.strings' -print0)
}

check_source() {
  plutil -lint Info.plist >/dev/null
  plutil -lint alt-tab-macos.xcodeproj/project.pbxproj >/dev/null
  if plutil -p Info.plist | rg '"(Domain|ApiDomain)"'; then
    fail "Info.plist contains a paid-service setting"
  fi

  local paidArchitecture='License(Manager|State|API)|RemoteLicenseClient|MachineFingerprint|SystemKeychain|Pro(GatedPreferences|Feature|Transition|Prompt|Badge|Gradient|Conversion)|Upgrade(Tab|MenuItem|Button)|upgradeToPro|isPro(Locked|Available)|proGatedIndices|attemptHardGatedFeature'
  local paidFallback='PreferenceDefinition|snapshotAndDowngrade|isStoredValuePro|free(Default|Tier)|revert(ed|s|ing)? (to )?(the )?free defaults?|downgrad(e|es|ed|ing) (a |the )?(stored )?preference'
  local paidUi='AlTab Pro|Get Pro|Pro (feature|license|tier|trial)|Pro-only|Pro only|14-day (free )?trial|Start my .*trial|Trial (expired|ends|includes)|license key|Activate( your)? .*license|Deactivate( your)? .*license|My Account|Upgrade to Lifetime Pro|Unlock .* with Pro|one-time purchase|Manage activations|view receipts|money-back guarantee'
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
  require_production_wiring 'Preferences.effectiveShortcutStyle(shortcutIndex) == .searchOnRelease' src/App.swift
  require_production_wiring 'TilesView.startSearchSession(shouldStartInSearchMode)' src/App.swift
  require_production_wiring 'SearchModeResolver.enableEditing(mode: searchMode)' src/switcher/main-window/TilesView.swift
  require_production_wiring 'Preferences.effectiveAppearanceSize(SwitcherSession.activeShortcutIndex) == .auto' src/switcher/main-window/TilesView.swift
  require_production_wiring 'Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex)' src/switcher/Appearance.swift
  require_production_wiring 'Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex)' src/switcher/main-window/TileView.swift
  require_production_wiring 'Preferences.shortcutRegistrationPlan' src/preferences/settings-window/tabs/controls/ControlsTab.swift
  require_production_wiring 'Preferences.canAddShortcut' src/preferences/settings-window/tabs/controls/ControlsTab.swift
}

check_bundle() {
  local appPath="$1"
  local infoPath="$appPath/Contents/Info.plist"
  local resourcesPath="$appPath/Contents/Resources"
  [[ -d "$appPath" ]] || fail "app bundle not found: $appPath"
  [[ -d "$resourcesPath" ]] || fail "resource directory not found: $resourcesPath"
  plutil -lint "$infoPath" >/dev/null
  if plutil -p "$infoPath" | grep -E '"(Domain|ApiDomain)"|alt-tab\.app'; then
    fail "$appPath contains a paid-service setting"
  fi

  local executableName
  executableName="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$infoPath")"
  local executable="$appPath/Contents/MacOS/$executableName"
  local paidSymbols='License(Manager|State|API)|RemoteLicenseClient|MachineFingerprint|SystemKeychain|Pro(GatedPreferences|Feature|Transition|Prompt|Badge|Gradient|Conversion)|Upgrade(Tab|MenuItem|Button)|upgradeToPro|isProLocked|snapshotAndDowngrade'
  if strings "$executable" | grep -E "$paidSymbols|alt-tab\.app|LemonSqueezy|/v1/license|/my-account"; then
    fail "$appPath contains paid-access symbols or endpoints"
  fi
  local paidContent='AlTab Pro|Get Pro|Pro (feature|license|tier|trial)|Pro-only|14-day (free )?trial|Start my .*trial|Trial (expired|ends|includes)|license key|Activate( your)? .*license|Deactivate( your)? .*license|My Account|Upgrade to Lifetime Pro|Unlock .* with Pro|one-time purchase|Manage activations|view receipts|money-back guarantee|alt-tab\.app|LemonSqueezy'
  if grep -R -a -E -i "$paidContent" "$resourcesPath"; then
    fail "$appPath exposes paid-access, trial, account, or upsell content"
  else
    local grepStatus=$?
    [[ "$grepStatus" -eq 1 ]] || fail "could not scan all bundle resources"
  fi
  local localizedResources
  localizedResources="$(inspect_localized_resources "$resourcesPath")" || fail "could not inspect localized bundle resources"
  if printf '%s\n' "$localizedResources" | grep -E -i "$paidContent"; then
    fail "$appPath exposes paid-access, trial, account, or upsell content"
  fi

  for setting in '"App Icons"' '"Titles"' '"Auto"' '"Search"' '"Shortcut"' '"Ordering & Grouping"'; do
    printf '%s\n' "$localizedResources" | grep -F "$setting" >/dev/null || fail "$appPath is missing the included setting $setting"
  done
}

bundleOnly=false
if [[ "${1:-}" == "--bundle-only" ]]; then bundleOnly=true; shift; fi
if [[ "$bundleOnly" == false ]]; then check_source; else [[ $# -gt 0 ]] || fail "--bundle-only requires an app path"; fi
for appPath in "$@"; do check_bundle "$appPath"; done
echo "unrestricted-features check passed"
