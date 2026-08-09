#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "service-isolation check failed: $1" >&2
  exit 1
}

reject_matches() {
  local description="$1"
  local pattern="$2"
  shift 2
  if rg -n --hidden --glob '!scripts/check_service_isolation.sh' "$pattern" "$@"; then
    fail "$description"
  fi
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
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrincipalClass' Info.plist)" == "NSApplication" ]] || fail "NSPrincipalClass is not NSApplication"
  if plutil -p Info.plist | rg '"(SU[A-Z]|AppCenter)'; then
    fail "Info.plist contains updater or AppCenter keys"
  fi
  reject_matches "project still references an inherited service" 'Sparkle|AppCenter|CrashReporter|PLCrash|vendor/(Sparkle|AppCenter)' alt-tab-macos.xcodeproj/project.pbxproj
  reject_matches "production code contains an inherited service path" 'import (Sparkle|AppCenter|AppCenterCrashes)|SPU(StandardUpdaterController|Updater)|AppCenter\.start|MSACCrashes|api\.appcenter\.ms|in\.appcenter\.ms|appcast(U|u)rl|appcast\.xml|syncLicenseCookie|checkForUpdatesNow|SUAutomaticallyUpdate|SUEnableAutomaticChecks|AppCenterSecret' src Info.plist alt-tab-macos-Bridging-Header.h config
  reject_matches "updater or crash-consent UI remains localized" '"(AlTab crashed last time you used it\. Sending a crash report will help get the issue fixed|Always send crash reports|Ask whether to send crash reports|Auto-install updates periodically|Check for updates now…|Check for updates periodically|Check for updates…|Crash reports policy|Don’t check for updates periodically|Don’t send|Never send crash reports|Remember my choice|Send a crash report\?|Updates policy|A debug profile \(versions, settings, hardware\) is attached to help diagnose the issue\.|A new version of AlTab is available|Update now|You.re running v%1\$@\. v%2\$@ is available\.)"' resources/l10n
  local removedPaths=(
    vendor/Sparkle
    vendor/AppCenter
    vendor/scripts/update_sparkle.sh
    vendor/scripts/update_appcenter.sh
    scripts/copy_sparkle_helpers.sh
    scripts/update_appcast.sh
    scripts/upload_symbols_to_appcenter.sh
    scripts/codesign/setup_ci_master.sh
    scripts/determine_next_version.sh
    scripts/extract_latest_changelog.sh
    scripts/notarytool
    scripts/package_and_notarize_release.sh
    scripts/print_env.sh
    scripts/replace_environment_variables_in_app.sh
    scripts/update_readme_and_website.sh
    scripts/update_website.sh
    scripts/build_readme_svg.py
    docs/readme/main.svg
    docs/readme/screenshot-source.webp
    docs/readme/sponsor.svg
    src/api/Secrets.swift
    src/events/UserDefaultsEvents.swift
    src/pro/license/LicenseCookie.swift
    src/secondary-windows/DebugProfile.swift
    src/vendors/AppCenterApplication.h
    src/vendors/AppCenterApplication.m
    src/vendors/AppCenterCrashes.swift
    src/vendors/SparkleDelegate.swift
    appcast.xml
    .github/workflows/ci_cd.yml
    package-lock.json
    # release.config.js is allowed: fork-owned semantic-release for changelog /
    # altab-v* source tags only (no appcast, AppCenter, Sparkle, or binary CI).
  )
  for path in "${removedPaths[@]}"; do
    [[ ! -e "$path" ]] || fail "$path still exists"
  done
}

check_bundle() {
  local appPath="$1"
  local infoPath="$appPath/Contents/Info.plist"
  local resourcesPath="$appPath/Contents/Resources"
  [[ -d "$appPath" ]] || fail "app bundle not found: $appPath"
  [[ -d "$resourcesPath" ]] || fail "resource directory not found: $resourcesPath"
  plutil -lint "$infoPath" >/dev/null
  if plutil -p "$infoPath" | grep -E '"(SU[A-Z]|AppCenter)'; then
    fail "$appPath contains updater or AppCenter plist keys"
  fi
  local inheritedArtifact
  inheritedArtifact="$(find "$appPath/Contents" \( -iname '*Sparkle*' -o -iname '*AppCenter*' -o -iname '*CrashReporter*' -o -iname '*PLCrash*' -o -name 'Updater.app' -o -name 'Autoupdate' \) -print -quit)" || fail "could not inspect bundle artifacts"
  if [[ -n "$inheritedArtifact" ]]; then
    fail "$appPath contains inherited service artifacts"
  fi
  local executableName
  executableName="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$infoPath")"
  local executable="$appPath/Contents/MacOS/$executableName"
  if otool -L "$executable" | grep -Ei 'Sparkle|AppCenter|CrashReporter|PLCrash'; then
    fail "$appPath links an inherited service"
  fi
  if strings "$executable" | grep -E 'api\.appcenter\.ms|in\.appcenter\.ms|MSACCrashes|AppCenter\.start|SPUStandardUpdaterController'; then
    fail "$appPath contains inherited service initialization symbols"
  fi
  local serviceUi='Check for updates|Updates policy|Crash reports policy|Send a crash report'
  if grep -R -a -E "$serviceUi" "$resourcesPath"; then
    fail "$appPath exposes updater or crash-reporting UI"
  else
    local grepStatus=$?
    [[ "$grepStatus" -eq 1 ]] || fail "could not scan all bundle resources"
  fi
  local localizedResources
  localizedResources="$(inspect_localized_resources "$resourcesPath")" || fail "could not inspect localized bundle resources"
  if printf '%s\n' "$localizedResources" | grep -E "$serviceUi"; then
    fail "$appPath exposes updater or crash-reporting UI"
  fi
}

bundleOnly=false
if [[ "${1:-}" == "--bundle-only" ]]; then bundleOnly=true; shift; fi
if [[ "$bundleOnly" == false ]]; then check_source; else [[ $# -gt 0 ]] || fail "--bundle-only requires an app path"; fi
for appPath in "$@"; do check_bundle "$appPath"; done
echo "service-isolation check passed"
