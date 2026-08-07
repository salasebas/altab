#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "source-compliance check failed: $1" >&2
  exit 1
}

require_file() {
  [[ -s "$1" ]] || fail "missing or empty $1"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain required metadata: $text"
}

read_metadata() {
  local path="$1"
  local key="$2"
  local value
  value="$(plutil -extract "$key" raw "$path")" || fail "could not read $key from $path"
  printf '%s' "$value"
}

for dependency in plutil rg; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done

requiredPaths=(
  LICENCE.md
  NOTICE.md
  docs/acknowledgments.md
  docs/contributors.md
  docs/brand/README.md
  docs/brand/ALTAB-BRAND-LICENSE.txt
  scripts/check_symbol_assets.sh
  scripts/forbidden_service_contracts.sh
  scripts/licenses/Tabler-Icons-LICENSE.txt
  scripts/licenses/createicns-LICENSE.txt
  scripts/licenses/xcbeautify-LICENSE.txt
  scripts/symbol-assets.sha256
  vendor/ShortcutRecorder/LICENSE.txt
  vendor/ShortcutRecorder/UPSTREAM
  vendor/scripts/update_shortcut_recorder.sh
)
for path in "${requiredPaths[@]}"; do require_file "$path"; done

[[ "$(read_metadata package.json license)" == "GPL-3.0-only" ]] || fail "package.json does not declare GPL-3.0-only"
[[ "$(read_metadata Info.plist NSHumanReadableCopyright)" == *'GPL-3.0-only'* ]] || fail "Info.plist does not declare GPL-3.0-only"
require_text LICENCE.md 'GNU GENERAL PUBLIC LICENSE'
require_text LICENCE.md 'Version 3, 29 June 2007'
require_text vendor/scripts/update_shortcut_recorder.sh 'LICENSE.txt'

source scripts/forbidden_service_contracts.sh
operationalPaths=(package.json Info.plist config alt-tab-macos.xcodeproj/project.pbxproj .github/workflows ai scripts src resources/l10n)
if rg -n -i --hidden --glob '!scripts/forbidden_service_contracts.sh' --glob '!scripts/check_source_compliance.sh' --glob '!scripts/check_service_isolation.sh' --glob '!scripts/check_unrestricted_features.sh' "$forbiddenServiceIdentityPattern" "${operationalPaths[@]}"; then
  fail "operational source contains an upstream service, licensing identity, credential, or release secret"
else
  scanStatus=$?
  [[ $scanStatus -eq 1 ]] || fail "could not scan operational source for forbidden identities"
fi
workflowMutationPattern='scripts/package_release\.sh|codesign|notarytool|CODE_SIGN|DEVELOPMENT_TEAM|xcodebuild[[:space:]]+archive|gh[[:space:]]+(release|api)|create-release|action-gh-release|uploads\.github\.com|api\.github\.com/repos/.*/releases|secrets(\.|\[)'
if rg -n -i "$workflowMutationPattern" .github/workflows; then
  fail "normal CI contains signing, packaging, release publication, or secret access"
else
  scanStatus=$?
  [[ $scanStatus -eq 1 ]] || fail "could not scan normal CI for signing or publication behavior"
fi

scripts/check_service_isolation.sh
scripts/check_unrestricted_features.sh
scripts/check_symbol_assets.sh
echo "source-compliance check passed"
