#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

usage() {
  cat <<'EOF'
Usage:
  scripts/package_notarized_release.sh <tag-or-full-commit> [options]

Bring-your-own Developer ID path. Builds an exact tag or full 40-character
commit into a signed, notarized, stapled, verified redistribution package.

Required configuration (flags or environment variables; never paste secrets
into arguments when a Keychain profile or API key file is available):

  --identity VALUE              ALTAB_DEVELOPER_ID_IDENTITY
                                Full "Developer ID Application: …" identity
  --team-id VALUE               ALTAB_TEAM_ID
  --bundle-id VALUE             ALTAB_BUNDLE_ID
                                Stable distributor-owned bundle identifier

Notarization credentials (exactly one method):

  --notary-profile VALUE        ALTAB_NOTARY_KEYCHAIN_PROFILE
                                Keychain profile created with
                                `xcrun notarytool store-credentials`
  --notary-key PATH             ALTAB_NOTARY_API_KEY_PATH
  --notary-key-id VALUE         ALTAB_NOTARY_API_KEY_ID
  --notary-issuer VALUE         ALTAB_NOTARY_API_ISSUER_ID
                                App Store Connect API key (.p8 path + ids)

Optional:

  --output-directory PATH       Output root (default: dist/)
  --help

This path will never silently fall back to Local Self-Signed, ad-hoc, or unsigned output.
EOF
}

fail() {
  echo "notarized release packaging failed: $1" >&2
  exit 1
}

redact_and_fail() {
  local message="$1"
  local detailsFile="${2:-}"
  echo "notarized release packaging failed: $message" >&2
  if [[ -n "$detailsFile" && -f "$detailsFile" ]]; then
    release_print_safe_diagnostics "$detailsFile"
  fi
  exit 1
}

revision=""
outputRoot="$repoRoot/dist"
identity="${ALTAB_DEVELOPER_ID_IDENTITY:-}"
teamId="${ALTAB_TEAM_ID:-}"
bundleId="${ALTAB_BUNDLE_ID:-}"
notaryProfile="${ALTAB_NOTARY_KEYCHAIN_PROFILE:-}"
notaryKeyPath="${ALTAB_NOTARY_API_KEY_PATH:-}"
notaryKeyId="${ALTAB_NOTARY_API_KEY_ID:-}"
notaryIssuer="${ALTAB_NOTARY_API_ISSUER_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --identity)
      [[ $# -ge 2 ]] || fail "--identity requires a value"
      identity="$2"
      shift 2
      ;;
    --team-id)
      [[ $# -ge 2 ]] || fail "--team-id requires a value"
      teamId="$2"
      shift 2
      ;;
    --bundle-id)
      [[ $# -ge 2 ]] || fail "--bundle-id requires a value"
      bundleId="$2"
      shift 2
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || fail "--notary-profile requires a value"
      notaryProfile="$2"
      shift 2
      ;;
    --notary-key)
      [[ $# -ge 2 ]] || fail "--notary-key requires a value"
      notaryKeyPath="$2"
      shift 2
      ;;
    --notary-key-id)
      [[ $# -ge 2 ]] || fail "--notary-key-id requires a value"
      notaryKeyId="$2"
      shift 2
      ;;
    --notary-issuer)
      [[ $# -ge 2 ]] || fail "--notary-issuer requires a value"
      notaryIssuer="$2"
      shift 2
      ;;
    --output-directory)
      [[ $# -ge 2 ]] || fail "--output-directory requires a value"
      outputRoot="$2"
      shift 2
      ;;
    --*)
      usage >&2
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$revision" ]] || fail "revision already set"
      revision="$1"
      shift
      ;;
  esac
done

[[ -n "$revision" ]] || { usage >&2; exit 2; }

for dependency in codesign ditto file git gzip lipo plutil python3 rg security shasum spctl tar xcodebuild xcrun zip; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done

source "$repoRoot/scripts/release_artifact_contracts.sh"
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "unsupported release artifact contracts version"

[[ -n "$bundleId" ]] || fail "bundle ID is required (--bundle-id or ALTAB_BUNDLE_ID)"
release_validate_developer_id_inputs "$identity" "$teamId" "$bundleId"

usingProfile=false
usingApiKey=false
if [[ -n "$notaryProfile" ]]; then
  usingProfile=true
fi
if [[ -n "$notaryKeyPath" || -n "$notaryKeyId" || -n "$notaryIssuer" ]]; then
  usingApiKey=true
fi
if [[ "$usingProfile" == true && "$usingApiKey" == true ]]; then
  fail "provide either a notary Keychain profile or an App Store Connect API key, not both"
fi
if [[ "$usingProfile" == false && "$usingApiKey" == false ]]; then
  fail "notarization credentials are required (--notary-profile or --notary-key/--notary-key-id/--notary-issuer)"
fi
if [[ "$usingApiKey" == true ]]; then
  [[ -n "$notaryKeyPath" && -n "$notaryKeyId" && -n "$notaryIssuer" ]] || fail "API-key notarization requires --notary-key, --notary-key-id, and --notary-issuer"
  [[ -f "$notaryKeyPath" && ! -L "$notaryKeyPath" ]] || fail "notary API key path must be a regular file"
  [[ "$notaryKeyId" =~ ^[A-Z0-9]+$ ]] || fail "notary API key id looks invalid"
  [[ "$notaryIssuer" =~ ^[0-9a-fA-F-]{36}$ ]] || fail "notary issuer id must be a UUID"
fi

release_resolve_codesigning_identity "$identity" "$teamId"

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

artifactDirectory="$outputRoot/AlTab-$label-notarized"
[[ ! -e "$artifactDirectory" ]] || fail "output already exists: $artifactDirectory"
workRoot="/tmp/altab-notarized-release-$commit"
mkdir "$workRoot" || fail "release work directory already exists: $workRoot"
trap 'rm -rf "$workRoot"' EXIT
publishRoot="$workRoot/publish"
sourceExtractRoot="$workRoot/source"
sourcePrefix="AlTab-$label-source"
sourceFilename="$sourcePrefix.tar.gz"
packageName="$(release_package_name "$label" notarized)"
binaryFilename="$packageName.zip"
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

entitlementsPath="$sourceRoot/alt_tab_macos.entitlements"
[[ -f "$entitlementsPath" && ! -L "$entitlementsPath" ]] || fail "source archive is missing entitlements"
derivedDataArgument="DerivedData/NotarizedReleasePackaging"
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
  CODE_SIGN_STYLE=Manual
  "CODE_SIGN_IDENTITY=$identity"
  "DEVELOPMENT_TEAM=$teamId"
  "PRODUCT_BUNDLE_IDENTIFIER=$bundleId"
  "OTHER_CODE_SIGN_FLAGS=--timestamp"
  "CURRENT_PROJECT_VERSION=$releaseBundleVersion"
  clean build
)
unsignedRebuildCommand=(
  xcodebuild
  -project alt-tab-macos.xcodeproj
  -scheme Release
  -configuration Release
  -derivedDataPath DerivedData/ReleasePackaging
  "ARCHS=arm64 x86_64"
  ONLY_ACTIVE_ARCH=NO
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
  DEVELOPMENT_TEAM=
  "PRODUCT_BUNDLE_IDENTIFIER=$bundleId"
  "CURRENT_PROJECT_VERSION=$releaseBundleVersion"
  clean build
)
printf -v recordedBuildCommand '%q ' "${buildCommand[@]}"
recordedBuildCommand="${recordedBuildCommand% }"
printf -v recordedUnsignedRebuildCommand '%q ' "${unsignedRebuildCommand[@]}"
recordedUnsignedRebuildCommand="${recordedUnsignedRebuildCommand% }"
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

# Re-sign explicitly so nested code and the outer bundle use Hardened Runtime + timestamp.
codesign --force --options runtime --timestamp --entitlements "$entitlementsPath" --sign "$identity" "$appPath" \
  || fail "Developer ID codesign failed"
signatureDetails="$workRoot/codesign-details.txt"
codesign --verify --deep --strict --verbose=2 "$appPath" 2>"$signatureDetails.verify" || fail "signed app failed codesign verification"
codesign --display --verbose=4 "$appPath" >/dev/null 2>"$signatureDetails" || fail "could not inspect signed app"
signedAuthority="$(sed -n 's/^Authority=//p' "$signatureDetails" | sed -n '1p')"
signedTeam="$(sed -n 's/^TeamIdentifier=//p' "$signatureDetails" | sed -n '1p')"
[[ "$signedAuthority" == "Developer ID Application:"* ]] || fail "signed app is not Developer ID Application"
[[ "$signedTeam" == "$teamId" ]] || fail "signed TeamIdentifier $signedTeam does not match $teamId"
if rg -q '^Signature=adhoc$' "$signatureDetails"; then
  fail "Developer ID signing produced an ad-hoc signature"
fi

builtBundleId="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$appPath/Contents/Info.plist")"
[[ "$builtBundleId" == "$bundleId" ]] || fail "built bundle identifier $builtBundleId does not match $bundleId"
(
  cd "$sourceRoot"
  scripts/check_service_isolation.sh "$appPath"
  scripts/check_unrestricted_features.sh "$appPath"
  scripts/check_symbol_assets.sh "$appPath"
)
release_validate_forbidden_bundle_content "$appPath"

notaryZip="$workRoot/AlTab-notary-submit.zip"
rm -f "$notaryZip"
ditto -c -k --keepParent "$appPath" "$notaryZip" || fail "could not create notarization zip"
notaryLog="$workRoot/notarytool.log"
release_require_accepted_notarization "$notaryZip" "$notaryLog" "$notaryProfile" "$notaryKeyPath" "$notaryKeyId" "$notaryIssuer"

xcrun stapler staple "$appPath" >"$workRoot/stapler-staple.log" 2>&1 || redact_and_fail "stapler staple failed" "$workRoot/stapler-staple.log"
release_validate_notarized_app "$appPath" "$signatureDetails" "$identity" "$teamId" "$entitlementsPath"

xcodeVersion="$(xcodebuild -version | paste -sd ';' -)"
swiftVersion="$(xcrun swift --version 2>&1 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
sdkVersion="$(xcrun --sdk macosx --show-sdk-version)"
sdkBuildVersion="$(xcrun --sdk macosx --show-sdk-build-version)"
macOSVersion="$(sw_vers -productVersion)"
macOSBuildVersion="$(sw_vers -buildVersion)"
hostArchitecture="$(uname -m)"
buildArchitectures="$(lipo -archs "$appBinary")"
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
- Corresponding source artifact: \`$sourceFilename\`
- Xcode: \`$xcodeVersion\`
- Swift: \`$swiftVersion\`
- macOS SDK: \`$sdkVersion ($sdkBuildVersion)\`
- Build host macOS: \`$macOSVersion ($macOSBuildVersion)\`
- Host architecture: \`$hostArchitecture\`
- Build architectures: \`$buildArchitectures\`
- Bundle identifier: \`$builtBundleId\`
- Bundle version: \`$bundleVersion\`
- Deployment target: \`$deploymentTarget\`
- Developer ID identity: \`$identity\`
- Team ID: \`$teamId\`
- Build command: \`$recordedBuildCommand\`
- Unsigned rebuild command: \`$recordedUnsignedRebuildCommand\`
- Signing status: **Developer ID Application** (caller-owned identity; repository stores no certificate material)
- Notarization status: **notarized and stapled**
- Service-isolation guard: **passed against the packaged app**
- Unrestricted-feature guard: **passed against the packaged app**
- Symbol-asset compliance guard: **passed against the packaged app**
EOF

notesTemplate="$sourceRoot/.github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md"
[[ -f "$notesTemplate" && ! -L "$notesTemplate" ]] || fail "source archive is missing notarized release notes template"
notes="$(<"$notesTemplate")"
notes="${notes//\{\{RELEASE\}\}/$label}"
notes="${notes//\{\{TAG\}\}/$gitTag}"
notes="${notes//\{\{COMMIT\}\}/$commit}"
notes="${notes//\{\{BINARY_ARTIFACT\}\}/$binaryFilename}"
notes="${notes//\{\{SOURCE_ARTIFACT\}\}/$sourceFilename}"
notes="${notes//\{\{MANIFEST\}\}/$manifestFilename}"
notes="${notes//\{\{BUNDLE_ID\}\}/$builtBundleId}"
notes="${notes//\{\{TEAM_ID\}\}/$teamId}"
notes="${notes//\{\{IDENTITY\}\}/$identity}"
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

Signing used a distributor-owned Developer ID Application identity and Team ID. The repository never ships those credentials. Rebuild without that identity using the unsigned rebuild command recorded in \`BUILD-MANIFEST.md\`, or run \`scripts/package_release.sh\` for the unsigned redistribution path.
EOF

archiveTimestamp="$(date -r "$(git show -s --format=%ct "$commit")" '+%Y%m%d%H%M.%S')"
find "$workRoot/package" -exec touch -h -t "$archiveTimestamp" {} +
(
  cd "$workRoot/package"
  find "$packageName" -print | LC_ALL=C sort | zip -X -y -q "$publishRoot/$binaryFilename" -@
)
(
  cd "$publishRoot"
  for artifact in "$binaryFilename" "$sourceFilename" "$manifestFilename" "$notesFilename"; do
    shasum -a 256 "$artifact"
  done > SHA256SUMS
)

"$sourceRoot/scripts/verify_release_artifacts.sh" "$publishRoot" "$commit" "$label" notarized
mkdir -p "$outputRoot"
mv "$publishRoot" "$artifactDirectory"
trap - EXIT
rm -rf "$workRoot"
echo "Notarized release artifacts created in $artifactDirectory"
