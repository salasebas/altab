#!/usr/bin/env bash

set -ex

derivedDataPath="DerivedData"
appPath="$derivedDataPath/Build/Products/Release/Altab.app"

set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -derivedDataPath "$derivedDataPath" | scripts/xcbeautify
file "$appPath/Contents/MacOS/Altab"
scripts/check_service_isolation.sh "$appPath"
