#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
buildScript="$repoRoot/scripts/build_local.sh"
testRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-local-build-check.XXXXXX")"
testRoot="$(cd -P "$testRoot" && pwd -P)"

cleanup() {
  local exitStatus=$?
  trap - EXIT HUP INT TERM
  rm -rf -- "$testRoot"
  exit "$exitStatus"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  echo "local-build check failed: $1" >&2
  exit 1
}

require_contains() {
  local path="$1"
  local expected="$2"
  rg -q -F -- "$expected" "$path" || fail "$path does not contain: $expected"
}

require_output() {
  local output="$1"
  local expected="$2"
  rg -q -F -- "$expected" "$output" || fail "output does not contain: $expected"
}

write_fixture() {
  fixtureRoot="$testRoot/fixture"
  mkdir -p "$fixtureRoot/scripts" "$testRoot/bin" "$testRoot/state"
  cp "$buildScript" "$fixtureRoot/scripts/build_local.sh"
  cat >"$fixtureRoot/scripts/xcbeautify" <<'EOF'
#!/usr/bin/env bash
cat
EOF
  for guard in service_isolation unrestricted_features symbol_assets; do
    cat >"$fixtureRoot/scripts/check_${guard}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[[ "\${1:-}" == "--bundle-only" ]] || exit 82
shift
[[ \$# -eq 1 ]] || exit 83
printf '%s\t%s\n' '$guard' "\$1" >>"\${LOCAL_BUILD_TEST_ROOT:?}/state/guards.log"
[[ "\${LOCAL_BUILD_TEST_FAIL_GUARD:-}" != '$guard' ]] || exit 81
echo "$guard check passed"
EOF
  done
  chmod +x "$fixtureRoot/scripts/"*.sh "$fixtureRoot/scripts/xcbeautify"
}

write_mock_tools() {
  cat >"$testRoot/bin/uname" <<'EOF'
#!/usr/bin/env bash
[[ $# -eq 1 && "$1" == "-m" ]] || exit 90
printf '%s\n' "${LOCAL_BUILD_TEST_HOST_ARCH:-arm64}"
EOF
  cat >"$testRoot/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
stateRoot="${LOCAL_BUILD_TEST_ROOT:?}/state"
if [[ $# -eq 1 && "$1" == "-version" ]]; then
  echo "Xcode 26.0.1"
  echo "Build version 17A400"
  exit 0
fi
derivedDataPath=""
architecture=""
onlyActiveArch=""
identity="-"
identityFromCommandLine=false
teamId=""
bundleId="dev.salasebas.AlTab"
previous=""
showSettings=false
build=false
for argument in "$@"; do
  if [[ "$previous" == "-derivedDataPath" ]]; then derivedDataPath="$argument"; fi
  case "$argument" in
    -derivedDataPath) previous="-derivedDataPath"; continue ;;
    -showBuildSettings) showSettings=true ;;
    build) build=true ;;
    ARCHS=*) architecture="${argument#ARCHS=}" ;;
    ONLY_ACTIVE_ARCH=*) onlyActiveArch="${argument#ONLY_ACTIVE_ARCH=}" ;;
    CODE_SIGN_IDENTITY=*) identity="${argument#CODE_SIGN_IDENTITY=}"; identityFromCommandLine=true ;;
    DEVELOPMENT_TEAM=*) teamId="${argument#DEVELOPMENT_TEAM=}" ;;
    PRODUCT_BUNDLE_IDENTIFIER=*) bundleId="${argument#PRODUCT_BUNDLE_IDENTIFIER=}" ;;
  esac
  previous=""
done
[[ -n "$derivedDataPath" && -n "$architecture" && -n "$onlyActiveArch" ]] || exit 91
if [[ "$showSettings" == true ]]; then
  printf '%s\n' "$@" >"$stateRoot/settings-arguments.log"
  if [[ "$identityFromCommandLine" == true ]]; then
    printf 'Build settings from command line:\n    CODE_SIGN_IDENTITY = %s\n\n' "$identity"
  fi
  cat <<SETTINGS
Build settings for action build and target alt-tab-macos:
    ARCHS = $architecture
    CODE_SIGN_IDENTITY = $identity
    DEVELOPMENT_TEAM = $teamId
    FULL_PRODUCT_NAME = AlTab.app
    PRODUCT_BUNDLE_IDENTIFIER = $bundleId
    TARGET_BUILD_DIR = $derivedDataPath/Build/Products/Release
SETTINGS
  exit 0
fi
[[ "$build" == true ]] || exit 92
printf '%s\n' "$@" >"$stateRoot/build-arguments.log"
printf '%s\n' "$architecture" >"$stateRoot/architecture"
printf '%s\n' "$identity" >"$stateRoot/identity"
printf '%s\n' "$teamId" >"$stateRoot/team-id"
appPath="$derivedDataPath/Build/Products/Release/AlTab.app"
mkdir -p "$appPath/Contents/MacOS" "$appPath/Contents/Resources"
cat >"$appPath/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AlTab</string>
<key>CFBundleIdentifier</key><string>$bundleId</string>
</dict></plist>
PLIST
printf '%s\n' 'mock AlTab executable' >"$appPath/Contents/MacOS/AlTab"
chmod +x "$appPath/Contents/MacOS/AlTab"
EOF
  cat >"$testRoot/bin/lipo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 && "$2" == "-archs" ]] || exit 93
cat "${LOCAL_BUILD_TEST_ROOT:?}/state/architecture"
EOF
  cat >"$testRoot/bin/codesign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --verify) exit 0 ;;
  --display)
    identity="$(<"${LOCAL_BUILD_TEST_ROOT:?}/state/identity")"
    teamId="$(<"${LOCAL_BUILD_TEST_ROOT:?}/state/team-id")"
    if [[ "$identity" == "-" ]]; then
      echo "Signature=adhoc" >&2
      echo "TeamIdentifier=not set" >&2
    else
      echo "Authority=$identity" >&2
      echo "TeamIdentifier=${teamId:-not set}" >&2
    fi
    ;;
  *) exit 94 ;;
esac
EOF
  chmod +x "$testRoot/bin/"*
}

run_build() {
  local output="$1"
  shift
  env "${cleanEnvironment[@]}" LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh" "$@" >"$output" 2>&1
}

expect_failure() {
  local description="$1"
  shift
  if "$@"; then fail "$description unexpectedly succeeded"; fi
}

check_bundle_guard_coverage() {
  local appPath="$testRoot/Bundle Guard Fixture.app"
  local resourcesPath="$appPath/Contents/Resources"
  mkdir -p "$appPath/Contents/MacOS" "$resourcesPath"
  cp /usr/bin/true "$appPath/Contents/MacOS/AlTab"
  cat >"$appPath/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AlTab</string>
<key>CFBundleIdentifier</key><string>dev.salasebas.AlTab</string>
</dict></plist>
PLIST
  cat >"$resourcesPath/Included.strings" <<'STRINGS'
"App Icons" = "App Icons";
"Titles" = "Titles";
"Auto" = "Auto";
"Search" = "Search";
"Shortcut" = "Shortcut";
"Ordering & Grouping" = "Ordering & Grouping";
STRINGS
  local platformPath="/usr/bin:/bin:/usr/sbin:/sbin"
  PATH="$platformPath" "$repoRoot/scripts/check_service_isolation.sh" --bundle-only "$appPath" >/dev/null
  PATH="$platformPath" "$repoRoot/scripts/check_unrestricted_features.sh" --bundle-only "$appPath" >/dev/null
  printf '%s\n' '{"message":"Check for updates"}' >"$resourcesPath/service.json"
  expect_failure "service marker in a non-strings resource" env PATH="$platformPath" "$repoRoot/scripts/check_service_isolation.sh" --bundle-only "$appPath"
  rm "$resourcesPath/service.json"
  printf '%s\n' '{"message":"AlTab Pro"}' >"$resourcesPath/paid.json"
  expect_failure "paid marker in a non-strings resource" env PATH="$platformPath" "$repoRoot/scripts/check_unrestricted_features.sh" --bundle-only "$appPath"
  rm "$resourcesPath/paid.json"
  printf '%s\n' 'not a valid strings file' >"$resourcesPath/Invalid.strings"
  expect_failure "invalid localized service resource" env PATH="$platformPath" "$repoRoot/scripts/check_service_isolation.sh" --bundle-only "$appPath"
  expect_failure "invalid localized feature resource" env PATH="$platformPath" "$repoRoot/scripts/check_unrestricted_features.sh" --bundle-only "$appPath"
}

[[ -x "$buildScript" ]] || fail "$buildScript is missing or not executable"
bash -n "$buildScript"
bash -n "$repoRoot/scripts/check_local_build.sh"
if rg -n '(^|[^A-Za-z0-9_])rg([^A-Za-z0-9_]|$)' "$buildScript"; then fail "$buildScript requires non-platform ripgrep"; fi
require_contains "$repoRoot/config/release.xcconfig" "CODE_SIGN_IDENTITY = -"
require_contains "$repoRoot/config/release.xcconfig" "CODE_SIGN_STYLE = Manual"
require_contains "$repoRoot/config/release.xcconfig" "DEVELOPMENT_TEAM ="
require_contains "$repoRoot/config/release.xcconfig" "OTHER_CODE_SIGN_FLAGS = --timestamp=none"
require_contains "$repoRoot/README.md" "scripts/build_local.sh"
require_contains "$repoRoot/README.md" "git clone https://github.com/salasebas/altab.git"
require_contains "$repoRoot/README.md" "DerivedData/Local/Build/Products/Release/AlTab.app"
require_contains "$repoRoot/README.md" "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
require_contains "$repoRoot/README.md" "git pull"
require_contains "$repoRoot/README.md" "Accessibility"
require_contains "$repoRoot/README.md" "Screen Recording"
require_contains "$repoRoot/README.md" "Local Self-Signed"
require_contains "$repoRoot/README.md" "scripts/package_release.sh"
require_contains "$repoRoot/README.md" "Do not disable Gatekeeper"
require_contains "$repoRoot/docs/contributing.md" "ALTAB_CODE_SIGN_IDENTITY"
require_contains "$repoRoot/docs/contributing.md" "ALTAB_TEAM_ID"
require_contains "$repoRoot/docs/contributing.md" "ALTAB_BUNDLE_ID"
require_contains "$repoRoot/docs/contributing.md" "README.md"
require_contains "$repoRoot/FORK.md" "scripts/build_local.sh"
check_bundle_guard_coverage

write_fixture
write_mock_tools
cleanEnvironment=(
  -u ALTAB_CODE_SIGN_IDENTITY
  -u ALTAB_TEAM_ID
  -u ALTAB_BUNDLE_ID
  -u LOCAL_BUILD_TEST_HOST_ARCH
  -u LOCAL_BUILD_TEST_FAIL_GUARD
)

defaultOutput="$testRoot/default-output.log"
run_build "$defaultOutput"
defaultApp="$fixtureRoot/DerivedData/Local/Build/Products/Release/AlTab.app"
printf -v escapedDefaultApp '%q' "$defaultApp"
require_output "$defaultOutput" "Architecture: arm64 (native)"
require_output "$defaultOutput" "Signature: ad hoc"
require_output "$defaultOutput" "Bundle ID: dev.salasebas.AlTab"
require_output "$defaultOutput" "App: $defaultApp"
require_output "$defaultOutput" "Launch: open $escapedDefaultApp"
require_contains "$testRoot/state/build-arguments.log" "ARCHS=arm64"
require_contains "$testRoot/state/build-arguments.log" "ONLY_ACTIVE_ARCH=YES"
if rg -q '^CODE_SIGN_IDENTITY=' "$testRoot/state/build-arguments.log"; then fail "default build overrides tracked ad-hoc signing"; fi
[[ "$(wc -l <"$testRoot/state/guards.log" | tr -d ' ')" == "3" ]] || fail "default build did not run all three bundle guards"

: >"$testRoot/state/guards.log"
x86Output="$testRoot/x86-output.log"
env "${cleanEnvironment[@]}" LOCAL_BUILD_TEST_HOST_ARCH=x86_64 LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh" >"$x86Output" 2>&1
require_output "$x86Output" "Architecture: x86_64 (native)"
require_contains "$testRoot/state/build-arguments.log" "ARCHS=x86_64"
require_contains "$testRoot/state/build-arguments.log" "ONLY_ACTIVE_ARCH=YES"

: >"$testRoot/state/guards.log"
customOutput="$testRoot/custom-output.log"
env "${cleanEnvironment[@]}" ALTAB_CODE_SIGN_IDENTITY="Local Self-Signed" ALTAB_TEAM_ID="A1B2C3D4E5" ALTAB_BUNDLE_ID="org.example.AlTab" LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh" --universal >"$customOutput" 2>&1
customApp="$fixtureRoot/DerivedData/Local/Build/Products/Release/AlTab.app"
require_output "$customOutput" "Architecture: arm64 x86_64 (universal)"
require_output "$customOutput" "Signature: identity (Local Self-Signed)"
require_output "$customOutput" "Team ID: A1B2C3D4E5"
require_output "$customOutput" "Bundle ID: org.example.AlTab"
require_contains "$testRoot/state/build-arguments.log" "ARCHS=arm64 x86_64"
require_contains "$testRoot/state/build-arguments.log" "ONLY_ACTIVE_ARCH=NO"
require_contains "$testRoot/state/build-arguments.log" "CODE_SIGN_IDENTITY=Local Self-Signed"
require_contains "$testRoot/state/build-arguments.log" "DEVELOPMENT_TEAM=A1B2C3D4E5"
require_contains "$testRoot/state/build-arguments.log" "PRODUCT_BUNDLE_IDENTIFIER=org.example.AlTab"
[[ "$(wc -l <"$testRoot/state/guards.log" | tr -d ' ')" == "3" ]] || fail "custom build did not run all three bundle guards"

expect_failure "unknown option" run_build "$testRoot/unknown-option.log" --publish
expect_failure "invalid host architecture" env "${cleanEnvironment[@]}" LOCAL_BUILD_TEST_HOST_ARCH=i386 LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh"
expect_failure "empty identity" env "${cleanEnvironment[@]}" ALTAB_CODE_SIGN_IDENTITY= LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh"
expect_failure "invalid team ID" env "${cleanEnvironment[@]}" ALTAB_TEAM_ID=bad-team LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh"
expect_failure "invalid bundle ID" env "${cleanEnvironment[@]}" ALTAB_BUNDLE_ID=not_a_bundle LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh"
expect_failure "failed guard" env "${cleanEnvironment[@]}" LOCAL_BUILD_TEST_FAIL_GUARD=unrestricted_features LOCAL_BUILD_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" "$fixtureRoot/scripts/build_local.sh"

echo "local-build check passed"
