#!/usr/bin/env bash

set -ex

derivedDataPath="${1:-DerivedData}"

xcodebuild -version
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -derivedDataPath "$derivedDataPath" -showBuildSettings | grep SWIFT_VERSION
scripts/check_service_isolation.sh
scripts/check_unrestricted_features.sh
scripts/check_legacy_preferences_import.sh
scripts/check_symbol_assets.sh

set -o pipefail && xcodebuild test -project alt-tab-macos.xcodeproj -scheme Test -configuration Release -derivedDataPath "$derivedDataPath" | scripts/xcbeautify
scripts/build_app.sh "$derivedDataPath"
