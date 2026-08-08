#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
fixtureRoot="$(mktemp -d)"
trap 'rm -rf "$fixtureRoot"' EXIT
sourceApp="$fixtureRoot/source/AlTab Dev.app"
applicationsDir="$fixtureRoot/Applications"
mockBin="$fixtureRoot/bin"
mkdir -p "$sourceApp/Contents" "$applicationsDir" "$mockBin"
plutil -create xml1 "$sourceApp/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string dev.salasebas.AlTabDev "$sourceApp/Contents/Info.plist"
printf 'new build\n' >"$sourceApp/Contents/build-marker"

makeMock() {
  local name="$1"
  local body="$2"
  printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$body" >"$mockBin/$name"
  chmod +x "$mockBin/$name"
}

# Mock bodies expand only when the generated scripts run.
# shellcheck disable=SC1012,SC2016
makeMock codesign '
lastArgument="${!#}"
if [[ "$*" == *"--verify"* && -n "${MOCK_FAIL_APP:-}" && "$lastArgument" == "$MOCK_FAIL_APP" ]]; then
  count="$(cat "$MOCK_VERIFY_STATE" 2>/dev/null || echo 0)"
  count="$((count + 1))"
  printf '%s\n' "$count" >"$MOCK_VERIFY_STATE"
  if [[ "$count" -ge "${MOCK_FAIL_AFTER:-1}" ]]; then exit 1; fi
elif [[ "$*" == *"--verbose=4"* ]]; then
  if [[ "${MOCK_ADHOC:-false}" == true ]]; then echo "Signature=adhoc" >&2; else echo "Authority=Local Self-Signed" >&2; fi
elif [[ "$*" == *"-r-"* ]]; then
  certificate=fixture
  if [[ -n "${MOCK_DIFFERENT_REQUIREMENT_APP:-}" && "$lastArgument" == "$MOCK_DIFFERENT_REQUIREMENT_APP" ]]; then certificate=different; fi
  echo "designated => identifier \"dev.salasebas.AlTabDev\" and certificate leaf = H\"$certificate\"" >&2
fi'
# shellcheck disable=SC2016
makeMock ditto 'cp -R "$1" "$2"'
# shellcheck disable=SC2016
makeMock pgrep '
if [[ -n "${MOCK_PGREP_STATE:-}" && -f "$MOCK_PGREP_STATE" ]]; then
  remaining="$(cat "$MOCK_PGREP_STATE")"
  if [[ "$remaining" -gt 0 ]]; then printf "%s\n" "$((remaining - 1))" >"$MOCK_PGREP_STATE"; exit 0; fi
fi
exit 1'
# shellcheck disable=SC2016
makeMock osascript 'printf "%s\n" "$*" >>"$MOCK_OSASCRIPT_LOG"'
# shellcheck disable=SC2016
makeMock open 'printf "%s\n" "$1" >>"$MOCK_OPEN_LOG"'

runInstaller() {
  PATH="$mockBin:$PATH" \
    MOCK_OPEN_LOG="$fixtureRoot/open.log" \
    MOCK_OSASCRIPT_LOG="$fixtureRoot/osascript.log" \
    MOCK_PGREP_STATE="$fixtureRoot/pgrep-state" \
    ALTAB_DEBUG_SOURCE_APP="$sourceApp" \
    ALTAB_DEBUG_APPLICATIONS_DIR="$applicationsDir" \
    bash "$repoRoot/scripts/run_debug.sh" --no-build "$@"
}

printf '1\n' >"$fixtureRoot/pgrep-state"
runInstaller
destinationApp="$applicationsDir/AlTab Dev.app"
[[ -f "$destinationApp/Contents/build-marker" ]] || { echo "fresh install did not copy the app" >&2; exit 1; }
[[ -d "$sourceApp" ]] || { echo "installer removed the DerivedData source" >&2; exit 1; }
[[ "$(tail -n 1 "$fixtureRoot/open.log")" == "$destinationApp" ]] || { echo "installer opened the wrong path" >&2; exit 1; }
grep -q 'dev.salasebas.AlTabDev.*quit' "$fixtureRoot/osascript.log" || { echo "installer did not request a clean quit by bundle identifier" >&2; exit 1; }

lockDir="$applicationsDir/.altab-dev-install.lock"
mkdir "$lockDir"
printf '%s\n' "$$" >"$lockDir/pid"
if runInstaller --no-open 2>"$fixtureRoot/lock-error.log"; then
  echo "installer ignored a concurrent live lock" >&2
  exit 1
fi
grep -q 'another AlTab Dev installation is already running' "$fixtureRoot/lock-error.log"
rm -rf "$lockDir"

if PATH="$mockBin:$PATH" \
  MOCK_DIFFERENT_REQUIREMENT_APP="$destinationApp" \
  ALTAB_DEBUG_SOURCE_APP="$sourceApp" \
  ALTAB_DEBUG_APPLICATIONS_DIR="$applicationsDir" \
  bash "$repoRoot/scripts/run_debug.sh" --no-build --no-open 2>"$fixtureRoot/identity-error.log"; then
  echo "installer silently replaced a different stable signing identity" >&2
  exit 1
fi
grep -q 'different signing identity' "$fixtureRoot/identity-error.log"

printf 'stale\n' >"$destinationApp/Contents/stale-marker"
printf 'updated build\n' >"$sourceApp/Contents/build-marker"
runInstaller --no-open
[[ ! -e "$destinationApp/Contents/stale-marker" ]] || { echo "replacement left stale bundle contents" >&2; exit 1; }
[[ "$(cat "$destinationApp/Contents/build-marker")" == "updated build" ]] || { echo "replacement did not install the new build" >&2; exit 1; }

printf 'invalid replacement\n' >"$sourceApp/Contents/build-marker"
printf '0\n' >"$fixtureRoot/verify-state"
if PATH="$mockBin:$PATH" \
  MOCK_FAIL_APP="$destinationApp" \
  MOCK_FAIL_AFTER=2 \
  MOCK_VERIFY_STATE="$fixtureRoot/verify-state" \
  ALTAB_DEBUG_SOURCE_APP="$sourceApp" \
  ALTAB_DEBUG_APPLICATIONS_DIR="$applicationsDir" \
  bash "$repoRoot/scripts/run_debug.sh" --no-build --no-open 2>"$fixtureRoot/rollback-error.log"; then
  echo "installer accepted a final bundle that failed signature verification" >&2
  exit 1
fi
grep -q 'invalid signature' "$fixtureRoot/rollback-error.log"
[[ "$(cat "$destinationApp/Contents/build-marker")" == "updated build" ]] || { echo "failed replacement did not restore the previous app" >&2; exit 1; }

if PATH="$mockBin:$PATH" \
  MOCK_ADHOC=true \
  ALTAB_DEBUG_SOURCE_APP="$sourceApp" \
  ALTAB_DEBUG_APPLICATIONS_DIR="$applicationsDir" \
  bash "$repoRoot/scripts/run_debug.sh" --no-build --no-open 2>"$fixtureRoot/adhoc-error.log"; then
  echo "installer accepted an ad-hoc build" >&2
  exit 1
fi
grep -q 'ad-hoc builds cannot provide stable permissions' "$fixtureRoot/adhoc-error.log"
echo "Debug installer checks passed"
