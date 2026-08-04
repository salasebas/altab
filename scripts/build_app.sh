#!/usr/bin/env bash

set -ex

derivedDataPath="${1:-DerivedData}"
debugAppPath="$derivedDataPath/Build/Products/Debug/Altab Dev.app"
releaseAppPath="$derivedDataPath/Build/Products/Release/Altab.app"

set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Debug -configuration Debug -derivedDataPath "$derivedDataPath" | scripts/xcbeautify
set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -configuration Release -derivedDataPath "$derivedDataPath" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= build | scripts/xcbeautify
file "$debugAppPath/Contents/MacOS/Altab Dev"
file "$releaseAppPath/Contents/MacOS/Altab"
scripts/check_service_isolation.sh "$debugAppPath" "$releaseAppPath"
scripts/check_unrestricted_features.sh "$debugAppPath" "$releaseAppPath"
