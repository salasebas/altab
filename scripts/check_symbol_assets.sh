#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "symbol-asset compliance check failed: $1" >&2
  exit 1
}

checksumManifest="scripts/symbol-assets.sha256"
[[ -f "$checksumManifest" ]] || fail "the audited symbol checksum manifest is missing"
expectedAssets=()
while read -r _ assetPath; do expectedAssets+=("${assetPath##*/}"); done < "$checksumManifest"

check_source() {
  local prohibitedFont
  prohibitedFont="$(find resources -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print -quit)" || fail "could not inspect source font assets"
  if [[ -n "$prohibitedFont" ]]; then
    fail "a redistributable build must not contain bundled fonts"
  fi
  if rg -n --hidden --glob '!scripts/check_symbol_assets.sh' 'SF-Pro-Text-Regular|NSFont\(name: "SF Pro Text"|ATSApplicationFontsPath|subset_font\.sh|convert_font_to_png\.sh|fonttools' src scripts Info.plist alt-tab-macos.xcodeproj .claude Pipfile Pipfile.lock; then
    fail "the removed proprietary-font pipeline is still referenced"
  fi
  if rg -n -P --glob '*.swift' --glob '*.sh' '[\x{E000}-\x{F8FE}\x{F0000}-\x{FFFFD}\x{100000}-\x{10FFFD}]' src scripts; then
    fail "source code contains a private-use glyph"
  fi
  [[ -f scripts/licenses/Tabler-Icons-LICENSE.txt ]] || fail "the Tabler Icons license is missing"
  local actualAssets
  local expectedAssetList
  actualAssets="$(find resources/icons/symbols -maxdepth 1 -type f -name '*.pdf' -exec basename {} \; | LC_ALL=C sort)"
  expectedAssetList="$(printf '%s\n' "${expectedAssets[@]}")"
  [[ "$actualAssets" == "$expectedAssetList" ]] || fail "the fallback asset inventory differs from the audited catalog"
  shasum -a 256 -c "$checksumManifest" >/dev/null || fail "a fallback asset differs from its audited checksum"
  for asset in "${expectedAssets[@]}"; do
    [[ "$(head -c 4 "resources/icons/symbols/$asset")" == "%PDF" ]] || fail "$asset is not a PDF"
  done
}

check_bundle() {
  local appPath="$1"
  local resourcesPath="$appPath/Contents/Resources"
  [[ -d "$resourcesPath/symbols" ]] || fail "$appPath does not bundle the fallback symbol directory"
  local prohibitedFont
  prohibitedFont="$(find "$resourcesPath" -type f \( -iname '*.otf' -o -iname '*.ttf' -o -iname '*SF-Pro*' \) -print -quit)" || fail "could not inspect bundle font assets"
  if [[ -n "$prohibitedFont" ]]; then
    fail "$appPath bundles a prohibited font artifact"
  fi
  for asset in "${expectedAssets[@]}"; do
    [[ -f "$resourcesPath/symbols/$asset" ]] || fail "$appPath is missing symbols/$asset"
    cmp "resources/icons/symbols/$asset" "$resourcesPath/symbols/$asset" >/dev/null || fail "$appPath contains an unexpected symbols/$asset"
  done
}

bundleOnly=false
if [[ "${1:-}" == "--bundle-only" ]]; then bundleOnly=true; shift; fi
if [[ "$bundleOnly" == false ]]; then check_source; else [[ $# -gt 0 ]] || fail "--bundle-only requires an app path"; fi
for appPath in "$@"; do check_bundle "$appPath"; done
echo "symbol-asset compliance check passed"
