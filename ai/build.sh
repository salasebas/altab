#!/bin/bash
set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
if ! xcodeVersion="$(xcodebuild -version 2>&1)"; then
  printf '%s\n' "$xcodeVersion" >&2
  echo "Debug build failed: full Xcode is unavailable; select it with DEVELOPER_DIR or xcode-select." >&2
  echo "Guide: docs/building-and-troubleshooting.md#1-select-full-xcode" >&2
  exit 1
fi
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
