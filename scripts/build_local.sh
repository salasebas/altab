#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
derivedDataPath="$repoRoot/DerivedData/Local"

usage() {
  echo "Usage: scripts/build_local.sh [--universal]"
  echo "Builds an optimized local AlTab.app without publishing or notarizing it."
}

fail() {
  echo "local build failed: $1" >&2
  exit 1
}

read_build_setting() {
  local name="$1"
  local values
  values="$(printf '%s\n' "$effectiveSettings" | sed -n "s/^[[:space:]]*$name = //p")"
  [[ -n "$values" ]] || fail "Xcode did not report $name"
  [[ "$values" != *$'\n'* ]] || fail "Xcode reported $name more than once"
  printf '%s' "$values"
}

validate_identity() {
  [[ -n "$ALTAB_CODE_SIGN_IDENTITY" ]] || fail "ALTAB_CODE_SIGN_IDENTITY cannot be empty"
  [[ "$ALTAB_CODE_SIGN_IDENTITY" != *$'\n'* && "$ALTAB_CODE_SIGN_IDENTITY" != *$'\r'* ]] || fail "ALTAB_CODE_SIGN_IDENTITY must be one line"
}

validate_team_id() {
  [[ "$ALTAB_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "ALTAB_TEAM_ID must be a 10-character Apple Team ID"
}

validate_bundle_id() {
  [[ "$ALTAB_BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]] || fail "ALTAB_BUNDLE_ID must be a reverse-DNS bundle identifier"
}

universal=false
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    --help) usage; exit 0 ;;
    --universal) universal=true ;;
    *) usage >&2; exit 2 ;;
  esac
fi

for dependency in codesign lipo plutil xcodebuild; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done
if ! xcodeVersion="$(xcodebuild -version 2>&1)"; then
  printf '%s\n' "$xcodeVersion" >&2
  fail "full Xcode is unavailable; select it with DEVELOPER_DIR or xcode-select before building"
fi

nativeArchitecture="$(uname -m)"
if [[ "$nativeArchitecture" == "x86_64" ]] && [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" == "1" ]] && [[ "$(sysctl -in hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
  nativeArchitecture="arm64"
fi
[[ "$nativeArchitecture" == "arm64" || "$nativeArchitecture" == "x86_64" ]] || fail "unsupported host architecture: $nativeArchitecture"

buildArchitectures="$nativeArchitecture"
architectureMode="native"
onlyActiveArchitecture="YES"
if [[ "$universal" == true ]]; then
  buildArchitectures="arm64 x86_64"
  architectureMode="universal"
  onlyActiveArchitecture="NO"
fi

buildSettings=("ARCHS=$buildArchitectures" "ONLY_ACTIVE_ARCH=$onlyActiveArchitecture")
if [[ "${ALTAB_CODE_SIGN_IDENTITY+x}" == "x" ]]; then
  validate_identity
  buildSettings+=("CODE_SIGN_IDENTITY=$ALTAB_CODE_SIGN_IDENTITY")
fi
if [[ "${ALTAB_TEAM_ID+x}" == "x" ]]; then
  validate_team_id
  buildSettings+=("DEVELOPMENT_TEAM=$ALTAB_TEAM_ID")
fi
if [[ "${ALTAB_BUNDLE_ID+x}" == "x" ]]; then
  validate_bundle_id
  buildSettings+=("PRODUCT_BUNDLE_IDENTIFIER=$ALTAB_BUNDLE_ID")
fi

cd "$repoRoot"
buildArguments=(
  -project alt-tab-macos.xcodeproj
  -scheme Release
  -configuration Release
  -derivedDataPath "$derivedDataPath"
  "${buildSettings[@]}"
)
effectiveSettings="$(xcodebuild "${buildArguments[@]}" -showBuildSettings)" || fail "could not resolve Release build settings"
targetBuildDirectory="$(read_build_setting TARGET_BUILD_DIR)"
fullProductName="$(read_build_setting FULL_PRODUCT_NAME)"
resolvedBundleId="$(read_build_setting PRODUCT_BUNDLE_IDENTIFIER)"
resolvedSigningIdentity="$(read_build_setting CODE_SIGN_IDENTITY)"
[[ "$targetBuildDirectory" == /* ]] || fail "Xcode reported a non-absolute target build directory"
[[ "$fullProductName" == *.app && "$fullProductName" != */* ]] || fail "Xcode reported an unsafe app product name: $fullProductName"
appPath="$targetBuildDirectory/$fullProductName"

set -o pipefail
xcodebuild "${buildArguments[@]}" build | scripts/xcbeautify

[[ -d "$appPath" && ! -L "$appPath" ]] || fail "Release app was not produced at $appPath"
infoPath="$appPath/Contents/Info.plist"
builtBundleId="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$infoPath")" || fail "could not read the built bundle identifier"
[[ "$builtBundleId" == "$resolvedBundleId" ]] || fail "built bundle identifier does not match the resolved Release setting"
executableName="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$infoPath")" || fail "could not read the built executable name"
[[ -n "$executableName" && "$executableName" != */* ]] || fail "the built executable name is unsafe"
executablePath="$appPath/Contents/MacOS/$executableName"
[[ -f "$executablePath" && ! -L "$executablePath" ]] || fail "the built executable is missing"

actualArchitectures="$(lipo "$executablePath" -archs)" || fail "could not inspect the built architectures"
if [[ "$universal" == true ]]; then
  architectureCount="$(wc -w <<<"$actualArchitectures" | tr -d ' ')"
  [[ "$architectureCount" == "2" && " $actualArchitectures " == *" arm64 "* && " $actualArchitectures " == *" x86_64 "* ]] || fail "universal build has unexpected architectures: $actualArchitectures"
  reportedArchitectures="arm64 x86_64"
else
  [[ "$actualArchitectures" == "$nativeArchitecture" ]] || fail "native build has unexpected architectures: $actualArchitectures"
  reportedArchitectures="$actualArchitectures"
fi

codesign --verify --deep --strict "$appPath" || fail "the built app signature is invalid"
signatureDetails="$(codesign --display --verbose=4 "$appPath" 2>&1)" || fail "could not inspect the built app signature"
authority="$(printf '%s\n' "$signatureDetails" | sed -n 's/^Authority=//p' | sed -n '1p')"
teamId="$(printf '%s\n' "$signatureDetails" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
[[ "$teamId" != "not set" ]] || teamId=""
if [[ "$resolvedSigningIdentity" == "-" ]]; then
  printf '%s\n' "$signatureDetails" | grep -q '^Signature=adhoc$' || fail "default Release did not receive an ad-hoc signature"
  [[ -z "$authority" ]] || fail "ad-hoc Release unexpectedly has a signing authority"
  [[ -z "$teamId" ]] || fail "ad-hoc Release unexpectedly has Team ID $teamId"
  signatureMode="ad hoc"
else
  if printf '%s\n' "$signatureDetails" | grep -q '^Signature=adhoc$'; then fail "the requested signing identity produced an ad-hoc signature"; fi
  [[ -n "$authority" ]] || fail "the signed Release does not report a signing authority"
  signatureMode="identity ($authority)"
fi

scripts/check_service_isolation.sh --bundle-only "$appPath"
scripts/check_unrestricted_features.sh --bundle-only "$appPath"
scripts/check_symbol_assets.sh --bundle-only "$appPath"

echo "Local Release build passed"
echo "Architecture: $reportedArchitectures ($architectureMode)"
echo "Signature: $signatureMode"
echo "Team ID: ${teamId:-not set}"
echo "Bundle ID: $builtBundleId"
echo "App: $appPath"
printf 'Launch: open %q\n' "$appPath"
