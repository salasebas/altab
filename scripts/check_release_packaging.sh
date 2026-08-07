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
for path in scripts/package_release.sh scripts/verify_release_artifacts.sh scripts/check_release_packaging.sh scripts/check_source_compliance.sh scripts/check_service_isolation.sh scripts/check_unrestricted_features.sh; do
  [[ -x "$path" ]] || fail "$path is not executable"
  bash -n "$path"
done
bash -n scripts/release_artifact_contracts.sh
bash -n scripts/forbidden_service_contracts.sh

for field in "${releaseManifestFields[@]}"; do require_text scripts/package_release.sh "$field"; done
for placeholder in RELEASE TAG COMMIT BINARY_ARTIFACT SOURCE_ARTIFACT MANIFEST; do
  require_text .github/RELEASE_NOTES_TEMPLATE.md "{{$placeholder}}"
done
require_text scripts/package_release.sh 'scripts/verify_release_artifacts.sh'
require_text scripts/package_release.sh 'scripts/check_service_isolation.sh'
require_text scripts/package_release.sh 'scripts/check_unrestricted_features.sh'
echo "release-packaging check passed"
