#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

usage() {
  echo "Usage: scripts/package_release.sh <tag-or-commit> [output-directory]"
  echo "The revision must be an exact tag or a full 40-character commit SHA."
}

fail() {
  echo "release packaging failed: $1" >&2
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 2; }
[[ "$1" != "--help" ]] || { usage; exit 0; }

revision="$1"
outputRoot="${2:-$repoRoot/dist}"
for dependency in codesign ditto file git gzip hdiutil lipo plutil rg shasum tar xcodebuild xcrun zip; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done
source "$repoRoot/scripts/release_artifact_contracts.sh"
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "unsupported release artifact contracts version"

gitTag="untagged"
if git show-ref --verify --quiet "refs/tags/$revision"; then
  revisionRef="refs/tags/$revision"
  gitTag="$revision"
elif [[ "$revision" =~ ^[0-9a-fA-F]{40}$ ]]; then
  revisionRef="$revision"
else
  fail "revision must be an exact tag or full 40-character commit SHA"
fi
commit="$(git rev-parse --verify "$revisionRef^{commit}")" || fail "cannot resolve revision: $revision"
if [[ "$gitTag" == "untagged" ]]; then
  exactTags="$(git tag --points-at "$commit" | LC_ALL=C sort)"
  [[ -z "$exactTags" ]] || gitTag="$(printf '%s\n' "$exactTags" | sed -n '1p')"
fi
label="$(release_artifact_label "$gitTag")"
[[ "$label" != "untagged" ]] || label="$(git rev-parse --short=12 "$commit")"
[[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "release label is unsafe for artifact names: $label"
releaseBundleVersion="0"
# Prefer AlTab milestone tags (altab-vN.N.N) so retained upstream v* tags never set the bundle version.
if [[ "$gitTag" =~ ^altab-v([0-9]+(\.[0-9]+){0,2})$ ]]; then
  releaseBundleVersion="${BASH_REMATCH[1]}"
elif [[ "$gitTag" =~ ^v([0-9]+(\.[0-9]+){0,2})$ ]]; then
  releaseBundleVersion="${BASH_REMATCH[1]}"
fi
if git ls-tree -r "$commit" | awk '$1 == "160000" { found = 1 } END { exit !found }'; then
  fail "revision contains gitlinks, which git archive cannot include"
fi
if git ls-tree -r "$commit" | awk '$1 == "120000" { found = 1 } END { exit !found }'; then
  fail "revision contains symbolic links, which the self-contained artifact verifier rejects"
fi

artifactDirectory="$outputRoot/AlTab-$label"
[[ ! -e "$artifactDirectory" ]] || fail "output already exists: $artifactDirectory"
workRoot="/tmp/altab-release-$commit"
mkdir "$workRoot" || fail "release work directory already exists: $workRoot"
trap 'rm -rf "$workRoot"' EXIT
publishRoot="$workRoot/publish"
sourceExtractRoot="$workRoot/source"
sourcePrefix="AlTab-$label-source"
sourceFilename="$sourcePrefix.tar.gz"
packageName="$(release_package_name "$label" unsigned)"
binaryFilename="$packageName.zip"
dmgFilename="$(release_light_dmg_name "$label")"
manifestFilename="AlTab-$label-BUILD-MANIFEST.md"
notesFilename="AlTab-$label-RELEASE-NOTES.md"
mkdir -p "$publishRoot" "$sourceExtractRoot"

git archive --format=tar --prefix="$sourcePrefix/" "$commit" | gzip -n -9 > "$publishRoot/$sourceFilename"
tar -xzf "$publishRoot/$sourceFilename" -C "$sourceExtractRoot"
sourceRoot="$sourceExtractRoot/$sourcePrefix"
contractsPath="$sourceRoot/scripts/release_artifact_contracts.sh"
[[ -f "$contractsPath" && ! -L "$contractsPath" ]] || fail "source archive is missing release artifact contracts"
source "$contractsPath"
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "source archive contains an incompatible release artifact contracts version"
release_validate_source_tree "$sourceRoot"
"$sourceRoot/scripts/check_release_packaging.sh"
"$sourceRoot/scripts/check_source_compliance.sh"

derivedDataArgument="DerivedData/ReleasePackaging"
derivedDataPath="$sourceRoot/$derivedDataArgument"
buildCommand=(
  xcodebuild
  -project alt-tab-macos.xcodeproj
  -scheme Release
  -configuration Release
  -derivedDataPath "$derivedDataArgument"
  "ARCHS=arm64 x86_64"
  ONLY_ACTIVE_ARCH=NO
  CODE_SIGNING_ALLOWED=YES
  CODE_SIGNING_REQUIRED=YES
  CODE_SIGN_IDENTITY=-
  DEVELOPMENT_TEAM=
  OTHER_CODE_SIGN_FLAGS=--timestamp=none
  "CURRENT_PROJECT_VERSION=$releaseBundleVersion"
  clean build
)
printf -v recordedBuildCommand '%q ' "${buildCommand[@]}"
recordedBuildCommand="${recordedBuildCommand% }"
(
  cd "$sourceRoot"
  set -o pipefail
  "${buildCommand[@]}" | scripts/xcbeautify
)

appPath="$derivedDataPath/Build/Products/Release/AlTab.app"
dSYMPath="$derivedDataPath/Build/Products/Release/AlTab.app.dSYM"
appBinary="$appPath/Contents/MacOS/AlTab"
dSYMBinary="$dSYMPath/Contents/Resources/DWARF/AlTab"
[[ -d "$appPath" ]] || fail "Release app was not produced"
[[ -d "$dSYMPath" ]] || fail "Release dSYM was not produced"
file "$appBinary"
release_validate_binaries "$appBinary" "$dSYMPath" "$dSYMBinary"
(
  cd "$sourceRoot"
  scripts/check_service_isolation.sh "$appPath"
  scripts/check_unrestricted_features.sh "$appPath"
  scripts/check_symbol_assets.sh "$appPath"
)
signatureDetails="$workRoot/codesign-details.txt"
release_validate_unsigned_app "$appPath" "$signatureDetails"
release_validate_forbidden_bundle_content "$appPath"

xcodeVersion="$(xcodebuild -version | paste -sd ';' -)"
swiftVersion="$(xcrun swift --version 2>&1 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
sdkVersion="$(xcrun --sdk macosx --show-sdk-version)"
sdkBuildVersion="$(xcrun --sdk macosx --show-sdk-build-version)"
macOSVersion="$(sw_vers -productVersion)"
macOSBuildVersion="$(sw_vers -buildVersion)"
hostArchitecture="$(uname -m)"
buildArchitectures="$(lipo -archs "$appBinary")"
bundleIdentifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$appPath/Contents/Info.plist")"
bundleVersion="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$appPath/Contents/Info.plist")"
deploymentTarget="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$appPath/Contents/Info.plist")"
commitTimestamp="$(git show -s --format=%cI "$commit")"

cat > "$publishRoot/$manifestFilename" <<EOF
# AlTab build manifest

- Git commit: \`$commit\`
- Git tag: \`$gitTag\`
- Commit timestamp: \`$commitTimestamp\`
- Repository and retained Git history: https://github.com/salasebas/altab
- Binary artifact: \`$binaryFilename\`
- Light download artifact: \`$dmgFilename\` (\`AlTab.app\` only, drag-to-Applications layout; **ad-hoc signed, not Developer ID signed**)
- Corresponding source artifact: \`$sourceFilename\`
- Xcode: \`$xcodeVersion\`
- Swift: \`$swiftVersion\`
- macOS SDK: \`$sdkVersion ($sdkBuildVersion)\`
- Build host macOS: \`$macOSVersion ($macOSBuildVersion)\`
- Host architecture: \`$hostArchitecture\`
- Build architectures: \`$buildArchitectures\`
- Bundle identifier: \`$bundleIdentifier\`
- Bundle version: \`$bundleVersion\`
- Deployment target: \`$deploymentTarget\`
- Build command: \`$recordedBuildCommand\`
- Signing status: **ad hoc** (complete bundle seal, no Developer ID authority or Team ID; privacy grants are version-specific)
- Notarization status: **not notarized** (not requested)
- Service-isolation guard: **passed against the packaged app**
- Unrestricted-feature guard: **passed against the packaged app**
- Symbol-asset compliance guard: **passed against the packaged app**
EOF

notes="$(<"$sourceRoot/.github/RELEASE_NOTES_TEMPLATE.md")"
notes="${notes//\{\{RELEASE\}\}/$label}"
notes="${notes//\{\{TAG\}\}/$gitTag}"
notes="${notes//\{\{COMMIT\}\}/$commit}"
notes="${notes//\{\{BINARY_ARTIFACT\}\}/$binaryFilename}"
notes="${notes//\{\{DMG_ARTIFACT\}\}/$dmgFilename}"
notes="${notes//\{\{SOURCE_ARTIFACT\}\}/$sourceFilename}"
notes="${notes//\{\{MANIFEST\}\}/$manifestFilename}"
printf '%s\n' "$notes" > "$publishRoot/$notesFilename"
if rg -n '\{\{[^}]+\}\}' "$publishRoot/$notesFilename"; then
  fail "release notes contain unresolved template values"
fi

packageRoot="$workRoot/package/$packageName"
mkdir -p "$packageRoot/licenses"
ditto "$appPath" "$packageRoot/AlTab.app"
ditto "$dSYMPath" "$packageRoot/AlTab.app.dSYM"
cp "$sourceRoot/LICENCE.md" "$packageRoot/LICENSE-GPL-3.0.md"
cp "$sourceRoot/NOTICE.md" "$packageRoot/NOTICE.md"
cp "$sourceRoot/docs/acknowledgments.md" "$packageRoot/THIRD-PARTY-NOTICES.md"
cp "$sourceRoot/docs/contributors.md" "$packageRoot/CONTRIBUTORS.md"
cp "$sourceRoot/docs/brand/ALTAB-BRAND-LICENSE.txt" "$packageRoot/licenses/ALTAB-BRAND-LICENSE.txt"
cp "$sourceRoot/scripts/licenses/Tabler-Icons-LICENSE.txt" "$packageRoot/licenses/Tabler-Icons-LICENSE.txt"
cp "$sourceRoot/scripts/licenses/createicns-LICENSE.txt" "$packageRoot/licenses/createicns-LICENSE.txt"
cp "$sourceRoot/scripts/licenses/xcbeautify-LICENSE.txt" "$packageRoot/licenses/xcbeautify-LICENSE.txt"
cp "$sourceRoot/vendor/ShortcutRecorder/LICENSE.txt" "$packageRoot/licenses/ShortcutRecorder-LICENSE.txt"
cp "$publishRoot/$manifestFilename" "$packageRoot/BUILD-MANIFEST.md"
cp "$publishRoot/$notesFilename" "$packageRoot/RELEASE-NOTES.md"
cat > "$packageRoot/SOURCE.md" <<EOF
# Corresponding source and history

This binary was built from Git commit \`$commit\` (tag: \`$gitTag\`). Its complete corresponding source, including the build and packaging scripts, is published beside this package as \`$sourceFilename\`.

The retained Git history, upstream lineage, copyright notices, and ongoing source are available at https://github.com/salasebas/altab. The application is distributed under GPL-3.0-only; see \`LICENSE-GPL-3.0.md\`, \`NOTICE.md\`, and \`THIRD-PARTY-NOTICES.md\` in this package.
EOF

archiveTimestamp="$(date -r "$(git show -s --format=%ct "$commit")" '+%Y%m%d%H%M.%S')"
find "$workRoot/package" -exec touch -h -t "$archiveTimestamp" {} +
(
  cd "$workRoot/package"
  find "$packageName" -print | LC_ALL=C sort | zip -X -y -q "$publishRoot/$binaryFilename" -@
)
dmgStage="$workRoot/dmg-stage"
dmgCreateLog="$workRoot/dmg-create.log"
release_create_light_unsigned_dmg "$appPath" "$publishRoot/$dmgFilename" "AlTab" "$dmgStage" "$dmgCreateLog"
(
  cd "$publishRoot"
  # Casual download first, then full ZIP, then source + provenance (notes stay attached but secondary).
  for artifact in "$dmgFilename" "$binaryFilename" "$sourceFilename" "$manifestFilename" "$notesFilename"; do
    shasum -a 256 "$artifact"
  done > SHA256SUMS
)

"$sourceRoot/scripts/verify_release_artifacts.sh" "$publishRoot" "$commit" "$label"
mkdir -p "$outputRoot"
mv "$publishRoot" "$artifactDirectory"
trap - EXIT
rm -rf "$workRoot"
echo "Release artifacts created in $artifactDirectory"
