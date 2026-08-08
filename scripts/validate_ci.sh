#!/usr/bin/env bash

set -euxo pipefail

derivedDataPath="${1:-DerivedData}"

for dependency in git lipo plutil pnpm rg swiftformat xcodebuild; do
  if ! command -v "$dependency" >/dev/null; then
    echo "Missing required validation dependency: $dependency" >&2
    exit 1
  fi
done

plutil -lint Info.plist alt_tab_macos.entitlements alt-tab-macos.xcodeproj/project.pbxproj
find resources/l10n -type f -name '*.strings' -exec plutil -lint {} +
scripts/check_source_compliance.sh
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -list -derivedDataPath "$derivedDataPath"
pnpm run format:check
scripts/ensure_generated_files_are_up_to_date.sh
scripts/check_legacy_preferences_import.sh
scripts/check_local_codesign_setup.sh
scripts/check_local_build.sh
scripts/check_debug_install.sh
scripts/run_tests.sh "$derivedDataPath"
git diff --check
git diff --exit-code
