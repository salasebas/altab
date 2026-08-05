#!/usr/bin/env bash

set -ex

xcodebuild -version
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -showBuildSettings | grep SWIFT_VERSION
scripts/check_service_isolation.sh
scripts/check_unrestricted_features.sh
scripts/check_legacy_preferences_import.sh

set -o pipefail && xcodebuild test -project alt-tab-macos.xcodeproj -scheme Test -configuration Release | scripts/xcbeautify
scripts/build_app.sh
