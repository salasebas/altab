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
if rg -n -i --hidden \
  --glob '!scripts/forbidden_service_contracts.sh' \
  --glob '!scripts/check_source_compliance.sh' \
  --glob '!scripts/check_service_isolation.sh' \
  --glob '!scripts/check_unrestricted_features.sh' \
  --glob '!scripts/release_artifact_contracts.sh' \
  --glob '!scripts/check_notarized_release.sh' \
  --glob '!scripts/package_notarized_release.sh' \
  --glob '!scripts/verify_release_artifacts.sh' \
  --glob '!scripts/check_release_packaging.sh' \
  "$forbiddenServiceIdentityPattern" "${operationalPaths[@]}"; then
  fail "operational source contains an upstream service, licensing identity, credential, or release secret"
else
  scanStatus=$?
  [[ $scanStatus -eq 1 ]] || fail "could not scan operational source for forbidden identities"
fi
# Credential-free validation CI must stay free of packaging/signing/publication.
# Optional release packaging lives only in .github/workflows/release.yml.
workflowMutationPattern='scripts/package_release\.sh|scripts/package_notarized_release\.sh|codesign|notarytool|CODE_SIGN|DEVELOPMENT_TEAM|xcodebuild[[:space:]]+archive|gh[[:space:]]+(release|api)|create-release|action-gh-release|uploads\.github\.com|api\.github\.com/repos/.*/releases|secrets(\.|\[)'
if [[ -f .github/workflows/ci.yml ]]; then
  if rg -n -i "$workflowMutationPattern" .github/workflows/ci.yml; then
    fail "normal CI contains signing, packaging, release publication, or secret access"
  else
    scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan normal CI for signing or publication behavior"
  fi
fi
if [[ -f .github/workflows/release.yml ]]; then
  require_text .github/workflows/release.yml 'workflow_dispatch'
  require_text .github/workflows/release.yml 'distribution_mode'
  require_text .github/workflows/release.yml 'scripts/package_release.sh'
  require_text .github/workflows/release.yml 'scripts/package_notarized_release.sh'
  if rg -n -- '-----BEGIN |MI[IL][A-Za-z0-9+/]{40,}' .github/workflows/release.yml; then
    fail "release workflow appears to hardcode credential material"
  else
    scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan release workflow for hardcoded credentials"
  fi
fi
# Source-only changelog bot (semantic-release): may use GITHUB_TOKEN to commit
# changelog/package.json, tag altab-v*, and open notes-only GitHub Releases.
# Must never package, sign, notarize, or touch appcast/AppCenter/Sparkle.
if [[ -f .github/workflows/release-notes.yml ]]; then
  require_text .github/workflows/release-notes.yml 'semantic-release'
  require_text .github/workflows/release-notes.yml 'pnpm exec semantic-release'
  # Ignore comment-only lines so the file can document what it deliberately omits.
  if rg -n -i \
    'scripts/package_release\.sh|scripts/package_notarized_release\.sh|codesign|notarytool|CODE_SIGN|DEVELOPMENT_TEAM|xcodebuild[[:space:]]+archive|action-gh-release|appcast|AppCenter|Sparkle|APPLE_|SPARKLE_|NOTARY_' \
    .github/workflows/release-notes.yml \
    | rg -v '^[0-9]+:\s*#'; then
    fail "release-notes workflow must stay source-only (no packaging, signing, or inherited services)"
  fi
fi
# No other workflows may perform release packaging or secret-backed publication.
otherWorkflows=()
while IFS= read -r workflowPath; do
  [[ -n "$workflowPath" ]] || continue
  otherWorkflows+=("$workflowPath")
done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) ! -name 'ci.yml' ! -name 'release.yml' ! -name 'release-notes.yml' -print | LC_ALL=C sort)
if [[ ${#otherWorkflows[@]} -gt 0 ]]; then
  if rg -n -i "$workflowMutationPattern" "${otherWorkflows[@]}"; then
    fail "unexpected workflow performs signing, packaging, or secret-backed publication"
  else
    scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan unexpected workflows for release behavior"
  fi
fi

scripts/check_service_isolation.sh
scripts/check_unrestricted_features.sh
scripts/check_symbol_assets.sh
echo "source-compliance check passed"
