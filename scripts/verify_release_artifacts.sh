#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "release-artifact verification failed: $1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain: $text"
}

[[ $# -eq 3 ]] || fail "usage: scripts/verify_release_artifacts.sh <artifact-directory> <commit> <label>"
artifactRoot="$(cd "$1" && pwd)"
expectedCommit="$2"
label="$3"
sourcePrefix="AlTab-$label-source"
sourceFilename="$sourcePrefix.tar.gz"
packageName="AlTab-$label-macOS-unsigned"
binaryFilename="$packageName.zip"
manifestFilename="AlTab-$label-BUILD-MANIFEST.md"
notesFilename="AlTab-$label-RELEASE-NOTES.md"
for dependency in codesign cmp git gzip lipo rg shasum tar unzip xcrun; do
  command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"
done
for artifact in "$binaryFilename" "$sourceFilename" "$manifestFilename" "$notesFilename" SHA256SUMS; do
  [[ -f "$artifactRoot/$artifact" ]] || fail "missing artifact: $artifact"
done
[[ "$(wc -l < "$artifactRoot/SHA256SUMS" | tr -d ' ')" == "4" ]] || fail "SHA256SUMS must cover every published artifact except itself"
if rg -n '^([0-9a-f]{64})  /' "$artifactRoot/SHA256SUMS"; then
  fail "SHA256SUMS contains absolute paths"
fi
(
  cd "$artifactRoot"
  shasum -a 256 --check SHA256SUMS
)

archivedCommit="$(
  set +o pipefail
  gzip -dc "$artifactRoot/$sourceFilename" | git get-tar-commit-id
)"
[[ "$archivedCommit" == "$expectedCommit" ]] || fail "source archive commit is $archivedCommit, expected $expectedCommit"
sourceEntries="$(tar -tzf "$artifactRoot/$sourceFilename")"
for requiredPath in ai/build.sh scripts/package_release.sh scripts/verify_release_artifacts.sh LICENCE.md NOTICE.md docs/acknowledgments.md docs/contributors.md docs/brand/ALTAB-BRAND-LICENSE.txt scripts/licenses/createicns-LICENSE.txt scripts/licenses/xcbeautify-LICENSE.txt vendor/ShortcutRecorder/LICENSE.txt; do
  rg -q -F "$sourcePrefix/$requiredPath" <<< "$sourceEntries" || fail "source archive is missing $requiredPath"
done
for forbiddenPath in config/local.xcconfig codesign.conf codesign.crt codesign.key codesign.p12; do
  [[ ! -e "$repoRoot/$forbiddenPath" ]] || fail "source archive contains local credential material: $forbiddenPath"
done
if find "$repoRoot" -path "$repoRoot/DerivedData" -prune -o -type f \( -name '*.key' -o -name '*.p12' -o -name '*.mobileprovision' \) -print | rg .; then
  fail "source archive contains a credential file"
fi
if rg -n --hidden --glob '!DerivedData/**' --glob '!scripts/package_release.sh' --glob '!scripts/verify_release_artifacts.sh' '(-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})' "$repoRoot"; then
  fail "source archive contains a private key or access token"
fi

verifyRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-release-verify.XXXXXX")"
trap 'rm -rf "$verifyRoot"' EXIT
unzip -q "$artifactRoot/$binaryFilename" -d "$verifyRoot"
appPath="$verifyRoot/$packageName/AlTab.app"
dSYMPath="$verifyRoot/$packageName/AlTab.app.dSYM"
appBinary="$appPath/Contents/MacOS/AlTab"
dSYMBinary="$dSYMPath/Contents/Resources/DWARF/AlTab"
[[ -d "$appPath" ]] || fail "packaged app is missing"
[[ -f "$dSYMBinary" ]] || fail "packaged dSYM is missing"
lipo "$appBinary" -verify_arch arm64 x86_64
lipo "$dSYMBinary" -verify_arch arm64 x86_64
appUUIDs="$(xcrun dwarfdump --uuid "$appBinary" | sed -E 's/^UUID: ([0-9A-F-]+) \(([^)]+)\).*/\2 \1/' | LC_ALL=C sort)"
dSYMUUIDs="$(xcrun dwarfdump --uuid "$dSYMPath" | sed -E 's/^UUID: ([0-9A-F-]+) \(([^)]+)\).*/\2 \1/' | LC_ALL=C sort)"
[[ "$appUUIDs" == "$dSYMUUIDs" ]] || fail "packaged dSYM UUIDs do not match the app"
scripts/check_service_isolation.sh "$appPath"
scripts/check_unrestricted_features.sh "$appPath"
signatureDetails="$verifyRoot/codesign-details.txt"
if codesign --display --verbose=4 "$appPath" >/dev/null 2>"$signatureDetails"; then
  rg -q '^Signature=adhoc$' "$signatureDetails" || fail "packaged app has a non-ad-hoc signature"
  if rg -q '^Authority=' "$signatureDetails"; then
    fail "packaged app has a signing authority"
  fi
  teamIdentifier="$(sed -n 's/^TeamIdentifier=//p' "$signatureDetails")"
  [[ -z "$teamIdentifier" || "$teamIdentifier" == "not set" ]] || fail "packaged app has TeamIdentifier $teamIdentifier"
fi
if rg -a -n -i 'Louis Pontoise|QXD7GW8FHY|api\.appcenter\.ms|in\.appcenter\.ms|appcast[^[:space:]]*\.xml|LemonSqueezy|/v1/license|/my-account|AppCenterSecret|SPARKLE_PRIVATE_KEY|NOTARY_PASSWORD|APPLE_ID_PASSWORD' "$appPath"; then
  fail "packaged app contains an upstream identity, service, credential, or release secret"
fi

manifest="$artifactRoot/$manifestFilename"
notes="$artifactRoot/$notesFilename"
require_text "$manifest" "Git commit: \`$expectedCommit\`"
for field in 'Git tag' 'Xcode' 'Swift' 'macOS SDK' 'Build architectures' 'Build command' 'Signing status: **unsigned**' 'Notarization status: **not notarized**' 'Service-isolation guard: **passed against the packaged app**' 'Unrestricted-feature guard: **passed against the packaged app**'; do
  require_text "$manifest" "$field"
done
require_text "$notes" 'Signing status: **unsigned**'
require_text "$notes" 'Notarization status: **not notarized**'
require_text "$notes" "$expectedCommit"
if rg -n '\{\{[^}]+\}\}' "$manifest" "$notes"; then
  fail "release metadata contains unresolved template values"
fi
cmp "$manifest" "$verifyRoot/$packageName/BUILD-MANIFEST.md" >/dev/null || fail "packaged manifest differs from the published manifest"
cmp "$notes" "$verifyRoot/$packageName/RELEASE-NOTES.md" >/dev/null || fail "packaged release notes differ from the published release notes"
require_text "$verifyRoot/$packageName/SOURCE.md" "$sourceFilename"
require_text "$verifyRoot/$packageName/SOURCE.md" "$expectedCommit"
for packagedNotice in LICENSE-GPL-3.0.md NOTICE.md THIRD-PARTY-NOTICES.md CONTRIBUTORS.md licenses/ALTAB-BRAND-LICENSE.txt licenses/createicns-LICENSE.txt licenses/xcbeautify-LICENSE.txt licenses/ShortcutRecorder-LICENSE.txt; do
  [[ -f "$verifyRoot/$packageName/$packagedNotice" ]] || fail "packaged notice is missing: $packagedNotice"
done
echo "release-artifact verification passed"
