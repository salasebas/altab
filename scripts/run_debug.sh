#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
sourceApp="${ALTAB_DEBUG_SOURCE_APP:-$repoRoot/DerivedData/Build/Products/Debug/AlTab Dev.app}"
applicationsDir="${ALTAB_DEBUG_APPLICATIONS_DIR:-/Applications}"
destinationApp="$applicationsDir/AlTab Dev.app"
expectedBundleId="dev.salasebas.AlTabDev"
stagingRoot=""
backupRoot=""
lockDir=""
lockAcquired=false
destinationExisted=false
installedNew=false
committed=false

usage() {
  echo "Usage: scripts/run_debug.sh [--no-build] [--no-open]"
  echo "Builds, safely installs, and opens /Applications/AlTab Dev.app."
}

fail() {
  echo "AlTab Dev install failed: $1" >&2
  exit 1
}

removeTemporaryTree() {
  local path="$1"
  [[ -z "$path" || ! -e "$path" ]] && return
  [[ "$path" == "$applicationsDir/.altab-dev-"* ]] || fail "refusing to remove unexpected temporary path: $path"
  rm -rf -- "$path"
}

cleanup() {
  if [[ "$committed" != true && "$installedNew" == true && -e "$destinationApp" ]]; then
    rm -rf -- "$destinationApp"
  fi
  if [[ "$committed" != true && "$destinationExisted" == true && -n "$backupRoot" && -e "$backupRoot/AlTab Dev.app" && ! -e "$destinationApp" ]]; then
    mv "$backupRoot/AlTab Dev.app" "$destinationApp"
  fi
  removeTemporaryTree "$stagingRoot"
  removeTemporaryTree "$backupRoot"
  releaseInstallLock
}

releaseInstallLock() {
  if [[ "$lockAcquired" == true && -d "$lockDir" && ! -L "$lockDir" ]]; then
    rm -f -- "$lockDir/pid"
    rmdir "$lockDir" 2>/dev/null || true
  fi
  lockAcquired=false
}

readBundleId() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null
}

readRequirement() {
  codesign -d -r- "$1" 2>&1 | sed -n '/^designated => /p'
}

validateStableApp() {
  local app="$1"
  [[ -d "$app" && ! -L "$app" ]] || fail "app bundle is missing or unsafe: $app"
  [[ "$(readBundleId "$app")" == "$expectedBundleId" ]] || fail "unexpected bundle identifier in $app"
  codesign --verify --deep --strict "$app" || fail "invalid signature in $app"
  local signatureDetails
  signatureDetails="$(codesign -d --verbose=4 "$app" 2>&1)" || fail "could not inspect signature in $app"
  ! grep -q '^Signature=adhoc$' <<<"$signatureDetails" || fail "ad-hoc builds cannot provide stable permissions; run scripts/codesign/setup_local.sh"
  grep -q '^Authority=' <<<"$signatureDetails" || fail "the app has no signing authority: $app"
  local requirement
  requirement="$(readRequirement "$app")"
  [[ "$requirement" == *'identifier "'* ]] || fail "the app requirement does not bind its bundle identifier: $app"
  [[ "$requirement" == *certificate* || "$requirement" == *'anchor apple'* ]] || fail "the app requirement is not certificate-based: $app"
}

validateExistingDestination() {
  [[ "$(readBundleId "$destinationApp")" == "$expectedBundleId" ]] || fail "existing destination has an unexpected bundle identifier: $destinationApp"
  codesign --verify --deep --strict "$destinationApp" || fail "existing destination has an invalid signature: $destinationApp"
  local signatureDetails
  signatureDetails="$(codesign -d --verbose=4 "$destinationApp" 2>&1)" || fail "could not inspect existing destination signature"
  if grep -q '^Signature=adhoc$' <<<"$signatureDetails"; then return; fi
  local existingRequirement sourceRequirement
  existingRequirement="$(readRequirement "$destinationApp")"
  sourceRequirement="$(readRequirement "$sourceApp")"
  [[ "$existingRequirement" == "$sourceRequirement" ]] || fail "existing AlTab Dev uses a different signing identity; remove it manually before intentionally changing identities"
}

acquireInstallLock() {
  lockDir="$applicationsDir/.altab-dev-install.lock"
  if ! mkdir "$lockDir" 2>/dev/null; then
    [[ -d "$lockDir" && ! -L "$lockDir" ]] || fail "unsafe installer lock: $lockDir"
    local ownerPid
    ownerPid="$(sed -n '1p' "$lockDir/pid" 2>/dev/null || true)"
    if [[ "$ownerPid" =~ ^[0-9]+$ ]] && kill -0 "$ownerPid" 2>/dev/null; then
      fail "another AlTab Dev installation is already running"
    fi
    rm -rf -- "$lockDir"
    mkdir "$lockDir" 2>/dev/null || fail "could not acquire the AlTab Dev installer lock"
  fi
  lockAcquired=true
  printf '%s\n' "$$" >"$lockDir/pid"
}

quitRunningApp() {
  local processPattern='/AlTab Dev[.]app/Contents/MacOS/AlTab Dev($| )'
  if ! pgrep -f "$processPattern" >/dev/null; then return; fi
  osascript -e 'tell application id "dev.salasebas.AlTabDev" to quit' >/dev/null 2>&1 || true
  for _ in {1..50}; do
    if ! pgrep -f "$processPattern" >/dev/null; then return; fi
    sleep 0.1
  done
  fail "AlTab Dev is still running; quit it and retry"
}

installApp() {
  validateStableApp "$sourceApp"
  [[ "$applicationsDir" == /* && -d "$applicationsDir" && ! -L "$applicationsDir" ]] || fail "Applications directory is missing or unsafe: $applicationsDir"
  [[ -w "$applicationsDir" ]] || fail "$applicationsDir is not writable; install manually or fix its permissions"
  acquireInstallLock
  if [[ -e "$destinationApp" ]]; then
    [[ -d "$destinationApp" && ! -L "$destinationApp" ]] || fail "destination is not a regular app bundle: $destinationApp"
    validateExistingDestination
  fi
  quitRunningApp
  stagingRoot="$(mktemp -d "$applicationsDir/.altab-dev-install.XXXXXX")"
  ditto "$sourceApp" "$stagingRoot/AlTab Dev.app"
  validateStableApp "$stagingRoot/AlTab Dev.app"
  [[ "$(readRequirement "$sourceApp")" == "$(readRequirement "$stagingRoot/AlTab Dev.app")" ]] || fail "staged app changed signing identity"
  backupRoot="$(mktemp -d "$applicationsDir/.altab-dev-backup.XXXXXX")"
  if [[ -e "$destinationApp" ]]; then
    destinationExisted=true
    mv "$destinationApp" "$backupRoot/AlTab Dev.app"
  fi
  installedNew=true
  mv "$stagingRoot/AlTab Dev.app" "$destinationApp"
  validateStableApp "$destinationApp"
  [[ "$(readRequirement "$sourceApp")" == "$(readRequirement "$destinationApp")" ]] || fail "installed app changed signing identity"
  committed=true
  removeTemporaryTree "$stagingRoot"
  stagingRoot=""
  removeTemporaryTree "$backupRoot"
  backupRoot=""
}

build=true
openAfterInstall=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --no-build) build=false ;;
    --no-open) openAfterInstall=false ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

for dependency in codesign ditto mktemp open osascript pgrep sed; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "$build" == true ]]; then bash "$repoRoot/ai/build.sh"; fi
installApp
releaseInstallLock
trap - EXIT INT TERM
if [[ "$openAfterInstall" == true ]]; then open "$destinationApp"; fi
echo "Installed: $destinationApp"
