#!/usr/bin/env bash

set -ex

derivedDataPath="${1:-DerivedData}"
debugAppPath="$derivedDataPath/Build/Products/Debug/AlTab Dev.app"
releaseAppPath="$derivedDataPath/Build/Products/Release/AlTab.app"
releaseBinaryPath="$releaseAppPath/Contents/MacOS/AlTab"

# CI and packaging validation: explicit ad-hoc Debug (no user Keychain identity) and unsigned Release.
set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Debug -configuration Debug -derivedDataPath "$derivedDataPath" CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES | scripts/xcbeautify
set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -configuration Release -derivedDataPath "$derivedDataPath" ARCHS='arm64 x86_64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= build | scripts/xcbeautify
file "$debugAppPath/Contents/MacOS/AlTab Dev"
file "$releaseBinaryPath"
lipo "$releaseBinaryPath" -verify_arch arm64 x86_64
scripts/check_service_isolation.sh "$debugAppPath" "$releaseAppPath"
scripts/check_unrestricted_features.sh "$debugAppPath" "$releaseAppPath"
scripts/check_symbol_assets.sh "$debugAppPath" "$releaseAppPath"
