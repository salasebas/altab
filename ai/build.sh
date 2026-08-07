#!/bin/bash
set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=../scripts/codesign/preflight_local_signing.sh
ALTAB_REPO_ROOT="$repoRoot" source "$repoRoot/scripts/codesign/preflight_local_signing.sh"
preflight_local_signing

buildSettings=()
if [[ "${ALTAB_CODE_SIGN_IDENTITY+x}" == "x" ]]; then
  buildSettings+=("CODE_SIGN_IDENTITY=$ALTAB_CODE_SIGN_IDENTITY")
fi

cd "$repoRoot"
xcodebuild \
  -project alt-tab-macos.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData \
  "${buildSettings[@]+"${buildSettings[@]}"}"
