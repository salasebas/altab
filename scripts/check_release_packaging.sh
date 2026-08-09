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
for placeholder in RELEASE TAG COMMIT BINARY_ARTIFACT DMG_ARTIFACT SOURCE_ARTIFACT MANIFEST; do
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
require_text scripts/package_release.sh 'release_light_dmg_name'
require_text scripts/package_release.sh 'release_create_light_unsigned_dmg'
require_text scripts/package_release.sh 'hdiutil'
require_text scripts/package_release.sh 'Light download artifact'
require_text scripts/package_notarized_release.sh 'release_package_name'
require_text scripts/verify_release_artifacts.sh 'release_package_name'
require_text scripts/verify_release_artifacts.sh 'release_detect_package_mode'
require_text scripts/verify_release_artifacts.sh 'release_validate_light_unsigned_dmg'
require_text scripts/verify_release_artifacts.sh 'notarized'
require_text scripts/verify_release_artifacts.sh 'release_validate_notarized_app'
require_text scripts/release_artifact_contracts.sh 'release_create_light_unsigned_dmg'
require_text scripts/release_artifact_contracts.sh 'release_validate_light_unsigned_dmg'
require_text scripts/release_artifact_contracts.sh 'release_light_dmg_name'
require_text scripts/release_artifact_contracts.sh 'macOS-unsigned.dmg'
require_text scripts/publish_release_artifacts.sh 'release_audit_published_asset_names'
require_text docs/releasing.md 'macOS-unsigned.dmg'
require_text docs/releasing.md 'drag-to-Applications'
require_text README.md 'macOS-unsigned.dmg'
# Publish audit: unsigned ZIP without the light DMG must fail (subshell so fail() cannot abort the check).
auditMissingDmgLog="$(mktemp "${TMPDIR:-/tmp}/altab-audit-missing-dmg.XXXXXX")"
if (release_audit_published_asset_names \
  AlTab-test-macOS-unsigned.zip \
  AlTab-test-source.tar.gz \
  AlTab-test-BUILD-MANIFEST.md \
  AlTab-test-RELEASE-NOTES.md \
  SHA256SUMS) >"$auditMissingDmgLog" 2>&1; then
  rm -f "$auditMissingDmgLog"
  fail "publish audit must require the light unsigned DMG beside an unsigned ZIP"
fi
rg -q 'macOS-unsigned.dmg' "$auditMissingDmgLog" || { rm -f "$auditMissingDmgLog"; fail "publish audit missing-DMG error is incorrect"; }
rm -f "$auditMissingDmgLog"
if ! (release_audit_published_asset_names \
  AlTab-test-macOS-unsigned.zip \
  AlTab-test-macOS-unsigned.dmg \
  AlTab-test-source.tar.gz \
  AlTab-test-BUILD-MANIFEST.md \
  AlTab-test-RELEASE-NOTES.md \
  SHA256SUMS); then
  fail "publish audit must accept a complete unsigned set including the light DMG"
fi

# Focused light-DMG unit check (no Xcode build): create, validate layout, reject junk.
testRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-light-dmg-check.XXXXXX")"
cleanup_light_dmg_check() {
  local exitStatus=$?
  rm -rf -- "$testRoot"
  exit "$exitStatus"
}
trap cleanup_light_dmg_check EXIT
fixtureApp="$testRoot/AlTab.app"
mkdir -p "$fixtureApp/Contents/MacOS"
printf 'fixture-altab-binary\n' >"$fixtureApp/Contents/MacOS/AlTab"
chmod +x "$fixtureApp/Contents/MacOS/AlTab"
cat >"$fixtureApp/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.salasebas.AlTab</string>
  <key>CFBundleName</key><string>AlTab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>AlTab</string>
</dict></plist>
PLIST
dmgPath="$testRoot/AlTab-test-macOS-unsigned.dmg"
[[ "$(release_light_dmg_name test)" == "AlTab-test-macOS-unsigned.dmg" ]] || fail "light DMG name helper is incorrect"
release_create_light_unsigned_dmg \
  "$fixtureApp" \
  "$dmgPath" \
  "AlTabTest" \
  "$testRoot/dmg-stage" \
  "$testRoot/dmg-create.log"
[[ -f "$dmgPath" ]] || fail "light DMG fixture was not created"
release_validate_light_unsigned_dmg \
  "$dmgPath" \
  "$testRoot/dmg-mount" \
  "$testRoot/dmg-codesign.txt" \
  "$fixtureApp"
# Reject a DMG that includes unexpected top-level content.
badStage="$testRoot/bad-stage"
mkdir -p "$badStage"
ditto "$fixtureApp" "$badStage/AlTab.app"
ln -s /Applications "$badStage/Applications"
printf 'junk\n' >"$badStage/README.txt"
badDmg="$testRoot/bad.dmg"
hdiutil create -volname AlTabBad -srcfolder "$badStage" -ov -format UDZO "$badDmg" >"$testRoot/bad-create.log" 2>&1 \
  || fail "could not create negative-case DMG fixture"
if release_validate_light_unsigned_dmg "$badDmg" "$testRoot/bad-mount" "$testRoot/bad-codesign.txt" >"$testRoot/bad-validate.log" 2>&1; then
  fail "light DMG validator must reject unexpected top-level entries"
fi
rg -q 'unexpected top-level entry' "$testRoot/bad-validate.log" || fail "light DMG validator did not report unexpected top-level entry"
trap - EXIT
rm -rf -- "$testRoot"
echo "release-packaging check passed"
