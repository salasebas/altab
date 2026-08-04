#!/usr/bin/env bash

set -ex

xcodebuild -version
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -showBuildSettings | grep SWIFT_VERSION
scripts/check_service_isolation.sh

set -o pipefail && xcodebuild test -project alt-tab-macos.xcodeproj -scheme Test -configuration Release | scripts/xcbeautify
