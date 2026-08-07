#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "release-artifact verification failed: $1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain: $text"
}

validate_archive_entries() {
  local entries="$1"
  local expectedRoot="$2"
  local description="$3"
  local entry
  [[ -n "$entries" ]] || fail "$description is empty"
  while IFS= read -r entry; do
    case "$entry" in
      "$expectedRoot"|"$expectedRoot/"|"$expectedRoot/"*) ;;
      *) fail "$description contains an entry outside $expectedRoot: $entry" ;;
    esac
    [[ "$entry" != /* && "$entry" != ../* && "$entry" != *'/../'* && "$entry" != *'/..' && "$entry" != *'/./'* && "$entry" != *'/.' ]] || fail "$description contains an unsafe path: $entry"
  done <<< "$entries"
  local duplicates
  duplicates="$(printf '%s\n' "$entries" | LC_ALL=C sort | uniq -d)"
  [[ -z "$duplicates" ]] || fail "$description contains duplicate paths: $duplicates"
}

[[ $# -eq 3 ]] || fail "usage: scripts/verify_release_artifacts.sh <artifact-directory> <commit> <label>"
artifactRoot="$(cd "$1" && pwd)"
expectedCommit="$2"
label="$3"
[[ "$expectedCommit" =~ ^[0-9a-fA-F]{40}$ ]] || fail "expected commit must be a full 40-character SHA"
expectedCommit="$(printf '%s' "$expectedCommit" | tr '[:upper:]' '[:lower:]')"
[[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "release label is unsafe for artifact names: $label"

sourcePrefix="AlTab-$label-source"
sourceFilename="$sourcePrefix.tar.gz"
packageName="AlTab-$label-macOS-unsigned"
binaryFilename="$packageName.zip"
manifestFilename="AlTab-$label-BUILD-MANIFEST.md"
notesFilename="AlTab-$label-RELEASE-NOTES.md"
publishedArtifacts=("$binaryFilename" "$sourceFilename" "$manifestFilename" "$notesFilename")
for dependency in codesign cmp git gzip lipo otool plutil rg shasum strings tar unzip xcrun; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done
for artifact in "${publishedArtifacts[@]}" SHA256SUMS; do
  [[ -f "$artifactRoot/$artifact" && ! -L "$artifactRoot/$artifact" ]] || fail "missing regular artifact: $artifact"
done

checksumPattern='^[0-9a-f]{64}  ([A-Za-z0-9._-]+)$'
actualChecksumFiles=""
checksumCount=0
while IFS= read -r checksumLine || [[ -n "$checksumLine" ]]; do
  [[ "$checksumLine" =~ $checksumPattern ]] || fail "SHA256SUMS contains an unsafe or malformed entry"
  actualChecksumFiles+="${BASH_REMATCH[1]}"$'\n'
  checksumCount=$((checksumCount + 1))
done < "$artifactRoot/SHA256SUMS"
[[ $checksumCount -eq ${#publishedArtifacts[@]} ]] || fail "SHA256SUMS must cover every published artifact except itself"
expectedChecksumFiles="$(printf '%s\n' "${publishedArtifacts[@]}" | LC_ALL=C sort)"
actualChecksumFiles="$(printf '%s' "$actualChecksumFiles" | LC_ALL=C sort)"
[[ "$actualChecksumFiles" == "$expectedChecksumFiles" ]] || fail "SHA256SUMS does not cover the exact published artifact set"
(
  cd "$artifactRoot"
  shasum -a 256 --check SHA256SUMS
)

archivedCommit="$(
  set +o pipefail
  gzip -dc "$artifactRoot/$sourceFilename" | git get-tar-commit-id
)"
[[ "$archivedCommit" == "$expectedCommit" ]] || fail "source archive commit is $archivedCommit, expected $expectedCommit"

verifyRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-release-verify.XXXXXX")"
trap 'rm -rf "$verifyRoot"' EXIT
sourceEntries="$(tar -tzf "$artifactRoot/$sourceFilename")"
validate_archive_entries "$sourceEntries" "$sourcePrefix" "source archive"
unsafeSourceTypes="$(tar -tvzf "$artifactRoot/$sourceFilename" | awk 'substr($1, 1, 1) != "-" && substr($1, 1, 1) != "d"')"
[[ -z "$unsafeSourceTypes" ]] || fail "source archive contains a link or special entry: $unsafeSourceTypes"
bootstrapPath="$sourcePrefix/scripts/release_artifact_contracts.sh"
rg -q -F -x "$bootstrapPath" <<< "$sourceEntries" || fail "source archive is missing release artifact contracts"
sourceExtractRoot="$verifyRoot/source"
binaryExtractRoot="$verifyRoot/binary"
mkdir -p "$sourceExtractRoot" "$binaryExtractRoot"
tar -xzf "$artifactRoot/$sourceFilename" -C "$sourceExtractRoot"
sourceRoot="$sourceExtractRoot/$sourcePrefix"
contractsPath="$sourceRoot/scripts/release_artifact_contracts.sh"
[[ -f "$contractsPath" && ! -L "$contractsPath" ]] || fail "source archive release artifact contracts are not a regular file"
source "$contractsPath"
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "source archive contains an incompatible release artifact contracts version"
release_validate_source_tree "$sourceRoot"
"$sourceRoot/scripts/check_source_compliance.sh"

binaryEntries="$(unzip -Z1 "$artifactRoot/$binaryFilename")"
validate_archive_entries "$binaryEntries" "$packageName" "binary archive"
unsafeBinaryTypes="$(unzip -Z -l "$artifactRoot/$binaryFilename" | awk 'length($1) == 10 && $1 ~ /^[bcdlps-]/ && substr($1, 1, 1) != "-" && substr($1, 1, 1) != "d"')"
[[ -z "$unsafeBinaryTypes" ]] || fail "binary archive contains a link or special entry: $unsafeBinaryTypes"
unzip -q "$artifactRoot/$binaryFilename" -d "$binaryExtractRoot"
packageRoot="$binaryExtractRoot/$packageName"
appPath="$packageRoot/AlTab.app"
dSYMPath="$packageRoot/AlTab.app.dSYM"
appBinary="$appPath/Contents/MacOS/AlTab"
dSYMBinary="$dSYMPath/Contents/Resources/DWARF/AlTab"
[[ -d "$appPath" && ! -L "$appPath" ]] || fail "packaged app is missing or is a symbolic link"
[[ -d "$dSYMPath" && ! -L "$dSYMPath" ]] || fail "packaged dSYM is missing or is a symbolic link"
release_validate_binaries "$appBinary" "$dSYMPath" "$dSYMBinary"
(
  cd "$sourceRoot"
  scripts/check_service_isolation.sh "$appPath"
  scripts/check_unrestricted_features.sh "$appPath"
)
signatureDetails="$verifyRoot/codesign-details.txt"
release_validate_unsigned_app "$appPath" "$signatureDetails"
release_validate_forbidden_bundle_content "$appPath"

manifest="$artifactRoot/$manifestFilename"
notes="$artifactRoot/$notesFilename"
require_text "$manifest" "Git commit: \`$expectedCommit\`"
for field in "${releaseManifestFields[@]}"; do require_text "$manifest" "$field"; done
require_text "$notes" 'Signing status: **unsigned**'
require_text "$notes" 'Notarization status: **not notarized**'
require_text "$notes" "$expectedCommit"
if rg -n '\{\{[^}]+\}\}' "$manifest" "$notes"; then fail "release metadata contains unresolved template values"; fi
cmp "$manifest" "$packageRoot/BUILD-MANIFEST.md" >/dev/null || fail "packaged manifest differs from the published manifest"
cmp "$notes" "$packageRoot/RELEASE-NOTES.md" >/dev/null || fail "packaged release notes differ from the published release notes"
require_text "$packageRoot/SOURCE.md" "$sourceFilename"
require_text "$packageRoot/SOURCE.md" "$expectedCommit"
for packagedNotice in "${releasePackagedNotices[@]}"; do
  [[ -f "$packageRoot/$packagedNotice" && ! -L "$packageRoot/$packagedNotice" ]] || fail "packaged notice is missing: $packagedNotice"
done
echo "release-artifact verification passed"
