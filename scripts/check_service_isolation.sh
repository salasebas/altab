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
    release.config.js
  )
  for path in "${removedPaths[@]}"; do
    [[ ! -e "$path" ]] || fail "$path still exists"
  done
}

check_bundle() {
  local appPath="$1"
  local infoPath="$appPath/Contents/Info.plist"
  [[ -d "$appPath" ]] || fail "app bundle not found: $appPath"
  plutil -lint "$infoPath" >/dev/null
  if plutil -p "$infoPath" | rg '"(SU[A-Z]|AppCenter)'; then
    fail "$appPath contains updater or AppCenter plist keys"
  fi
  if find "$appPath/Contents" \( -iname '*Sparkle*' -o -iname '*AppCenter*' -o -iname '*CrashReporter*' -o -iname '*PLCrash*' -o -name 'Updater.app' -o -name 'Autoupdate' \) -print | rg .; then
    fail "$appPath contains inherited service artifacts"
  fi
  local executableName
  executableName="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$infoPath")"
  local executable="$appPath/Contents/MacOS/$executableName"
  if otool -L "$executable" | rg -i 'Sparkle|AppCenter|CrashReporter|PLCrash'; then
    fail "$appPath links an inherited service"
  fi
  if strings "$executable" | rg 'api\.appcenter\.ms|in\.appcenter\.ms|MSACCrashes|AppCenter\.start|SPUStandardUpdaterController'; then
    fail "$appPath contains inherited service initialization symbols"
  fi
  if rg -a 'Check for updates|Updates policy|Crash reports policy|Send a crash report' "$appPath/Contents/Resources"; then
    fail "$appPath exposes updater or crash-reporting UI"
  fi
}

check_source
if [[ $# -gt 0 ]]; then
  for appPath in "$@"; do check_bundle "$appPath"; done
fi
echo "service-isolation check passed"
