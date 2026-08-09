#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "release-packaging check failed: $1" >&2
  exit 1
}

require_file() {
  [[ -s "$1" && ! -L "$1" ]] || fail "missing regular file $1"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain packaging contract: $text"
}

source scripts/release_artifact_contracts.sh
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "unsupported release artifact contracts version"
for path in "${releaseRequiredSourcePaths[@]}" docs/releasing.md; do require_file "$path"; done
for path in \
  scripts/package_release.sh \
  scripts/package_notarized_release.sh \
  scripts/publish_release_artifacts.sh \
  scripts/verify_release_artifacts.sh \
  scripts/check_release_packaging.sh \
  scripts/check_notarized_release.sh \
  scripts/check_source_compliance.sh \
  scripts/check_service_isolation.sh \
  scripts/check_symbol_assets.sh \
  scripts/check_unrestricted_features.sh; do
  [[ -x "$path" ]] || fail "$path is not executable"
  bash -n "$path"
done
bash -n scripts/release_artifact_contracts.sh
bash -n scripts/forbidden_service_contracts.sh

for field in "${releaseManifestFields[@]}"; do require_text scripts/package_release.sh "$field"; done
for field in "${releaseNotarizedManifestFields[@]}"; do require_text scripts/package_notarized_release.sh "$field"; done
for placeholder in RELEASE TAG COMMIT BINARY_ARTIFACT SOURCE_ARTIFACT MANIFEST; do
  require_text .github/RELEASE_NOTES_TEMPLATE.md "{{$placeholder}}"
done
for placeholder in RELEASE TAG COMMIT BINARY_ARTIFACT SOURCE_ARTIFACT MANIFEST BUNDLE_ID TEAM_ID IDENTITY; do
  require_text .github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md "{{$placeholder}}"
done
require_file .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md
for placeholder in VERSION TAG COMMIT CHANGES; do
  require_text .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md "{{$placeholder}}"
done
require_text .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md 'Local Self-Signed'
require_text .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md 'GPL-3.0-only'
require_text .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md 'App Sandbox'
if rg -n -i 'ad-hoc build|optional local self-signing|optional per-user self-signing' .github/SOURCE_MILESTONE_NOTES_TEMPLATE.md; then
  fail "SOURCE_MILESTONE notes must describe required Local Self-Signed, not ad-hoc/optional signing"
fi
require_text docs/releasing.md 'altab-vMAJOR.MINOR.PATCH'
require_text docs/releasing.md 'source-only'
require_text docs/releasing.md 'scripts/package_notarized_release.sh'
require_text docs/releasing.md 'App Sandbox'
require_text docs/releasing.md 'Mac App Store'
require_text docs/releasing.md 'AlTab-<release>-source.tar.gz'
require_text docs/releasing.md 'ALTAB_RELEASE_REPLACE_ASSETS'
require_text scripts/publish_release_artifacts.sh 'release_audit_published_asset_names'
require_text scripts/publish_release_artifacts.sh 'ALTAB_RELEASE_REPLACE_ASSETS'
require_text scripts/release_artifact_contracts.sh 'release_audit_published_asset_names'
require_text scripts/package_release.sh 'altab-v'
require_text scripts/package_release.sh 'scripts/verify_release_artifacts.sh'
require_text scripts/package_release.sh 'scripts/check_service_isolation.sh'
require_text scripts/package_release.sh 'scripts/check_symbol_assets.sh'
require_text scripts/package_release.sh 'scripts/check_unrestricted_features.sh'
require_text scripts/package_notarized_release.sh 'scripts/verify_release_artifacts.sh'
require_text scripts/package_notarized_release.sh 'notarytool'
require_text scripts/package_notarized_release.sh 'stapler'
require_text scripts/package_release.sh 'release_package_name'
require_text scripts/package_notarized_release.sh 'release_package_name'
require_text scripts/verify_release_artifacts.sh 'release_package_name'
require_text scripts/verify_release_artifacts.sh 'release_detect_package_mode'
require_text scripts/verify_release_artifacts.sh 'notarized'
require_text scripts/verify_release_artifacts.sh 'release_validate_notarized_app'
echo "release-packaging check passed"
