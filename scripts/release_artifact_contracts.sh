#!/usr/bin/env bash

releaseContractsRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$releaseContractsRoot/forbidden_service_contracts.sh"
releaseArtifactContractsVersion=1
releaseRequiredSourcePaths=(
  ai/build.sh
  scripts/package_release.sh
  scripts/package_notarized_release.sh
  scripts/publish_release_artifacts.sh
  scripts/verify_release_artifacts.sh
  scripts/check_release_packaging.sh
  scripts/check_notarized_release.sh
  scripts/check_source_compliance.sh
  scripts/forbidden_service_contracts.sh
  scripts/release_artifact_contracts.sh
  scripts/check_service_isolation.sh
  scripts/check_symbol_assets.sh
  scripts/check_unrestricted_features.sh
  .github/RELEASE_NOTES_TEMPLATE.md
  .github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md
  package.json
  Info.plist
  LICENCE.md
  NOTICE.md
  docs/acknowledgments.md
  docs/contributors.md
  docs/brand/README.md
  docs/brand/ALTAB-BRAND-LICENSE.txt
  scripts/licenses/Tabler-Icons-LICENSE.txt
  scripts/licenses/createicns-LICENSE.txt
  scripts/licenses/xcbeautify-LICENSE.txt
  scripts/symbol-assets.sha256
  vendor/ShortcutRecorder/LICENSE.txt
  vendor/ShortcutRecorder/UPSTREAM
  vendor/scripts/update_shortcut_recorder.sh
)
releaseForbiddenSourcePaths=(
  config/local.xcconfig
  codesign.conf
  codesign.crt
  codesign.key
  codesign.p12
)
releaseRequiredArchitectures=(arm64 x86_64)
releaseManifestFieldsCommon=(
  'Git tag'
  'Xcode'
  'Swift'
  'macOS SDK'
  'Build architectures'
  'Build command'
  'Service-isolation guard: **passed against the packaged app**'
  'Symbol-asset compliance guard: **passed against the packaged app**'
  'Unrestricted-feature guard: **passed against the packaged app**'
)
releaseManifestFields=(
  "${releaseManifestFieldsCommon[@]}"
  'Signing status: **unsigned**'
  'Notarization status: **not notarized**'
)
releaseNotarizedManifestFields=(
  "${releaseManifestFieldsCommon[@]}"
  'Signing status: **Developer ID Application**'
  'Notarization status: **notarized and stapled**'
  'Developer ID identity'
  'Team ID'
  'Unsigned rebuild command'
)
releasePackagedNotices=(
  LICENSE-GPL-3.0.md
  NOTICE.md
  THIRD-PARTY-NOTICES.md
  CONTRIBUTORS.md
  licenses/ALTAB-BRAND-LICENSE.txt
  licenses/Tabler-Icons-LICENSE.txt
  licenses/createicns-LICENSE.txt
  licenses/xcbeautify-LICENSE.txt
  licenses/ShortcutRecorder-LICENSE.txt
)
releaseCredentialPattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'
releaseForbiddenBundlePattern="$forbiddenServiceIdentityPattern"
releaseUpstreamTeamId='QXD7GW8FHY'
releaseUpstreamBundleIdPrefix='com.lwouis.'
releaseLocalSelfSignedIdentity='Local Self-Signed'
releaseForbiddenIdentityPattern='Local Self-Signed|Apple Development|Apple Distribution|Louis Pontoise'

release_package_name() {
  local label="$1"
  local mode="$2"
  case "$mode" in
    unsigned) printf 'AlTab-%s-macOS-unsigned' "$label" ;;
    notarized) printf 'AlTab-%s-macOS' "$label" ;;
    *) fail "unknown release package mode: $mode" ;;
  esac
}

release_detect_package_mode() {
  local binaryFilename="$1"
  case "$binaryFilename" in
    *-macOS-unsigned.zip) printf 'unsigned' ;;
    *-macOS.zip) printf 'notarized' ;;
    *) fail "cannot detect release package mode from binary artifact name: $binaryFilename" ;;
  esac
}

release_validate_source_tree() {
  local sourceRoot="$1"
  local path
  for path in "${releaseRequiredSourcePaths[@]}"; do
    [[ -f "$sourceRoot/$path" && ! -L "$sourceRoot/$path" ]] || fail "source archive is missing regular file $path"
  done
  for path in "${releaseForbiddenSourcePaths[@]}"; do
    [[ ! -e "$sourceRoot/$path" && ! -L "$sourceRoot/$path" ]] || fail "source archive contains local credential material: $path"
  done
  local credentialFiles
  if ! credentialFiles="$(find "$sourceRoot" \( -type f -o -type l \) \( -name '*.key' -o -name '*.p12' -o -name '*.mobileprovision' \) -print)"; then
    fail "could not inspect source archive credential paths"
  fi
  [[ -z "$credentialFiles" ]] || { printf '%s\n' "$credentialFiles" >&2; fail "source archive contains a credential file"; }
  if rg -n --hidden --glob '!scripts/release_artifact_contracts.sh' "$releaseCredentialPattern" "$sourceRoot"; then
    fail "source archive contains a private key or access token"
  else
    local scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan source archive for private keys or access tokens"
  fi
}

release_validate_binaries() {
  local appBinary="$1"
  local dSYMPath="$2"
  local dSYMBinary="$3"
  local architecture
  [[ -f "$appBinary" && ! -L "$appBinary" ]] || fail "app executable is missing or is a symbolic link"
  [[ -f "$dSYMBinary" && ! -L "$dSYMBinary" ]] || fail "dSYM executable is missing or is a symbolic link"
  for architecture in "${releaseRequiredArchitectures[@]}"; do
    lipo "$appBinary" -verify_arch "$architecture"
    lipo "$dSYMBinary" -verify_arch "$architecture"
  done
  local appUUIDs
  local dSYMUUIDs
  appUUIDs="$(xcrun dwarfdump --uuid "$appBinary" | sed -E 's/^UUID: ([0-9A-F-]+) \(([^)]+)\).*/\2 \1/' | LC_ALL=C sort)"
  dSYMUUIDs="$(xcrun dwarfdump --uuid "$dSYMPath" | sed -E 's/^UUID: ([0-9A-F-]+) \(([^)]+)\).*/\2 \1/' | LC_ALL=C sort)"
  [[ -n "$appUUIDs" && "$appUUIDs" == "$dSYMUUIDs" ]] || fail "app and dSYM UUIDs do not match"
}

release_validate_unsigned_app() {
  local appPath="$1"
  local signatureDetails="$2"
  if codesign --display --verbose=4 "$appPath" >/dev/null 2>"$signatureDetails"; then
    rg -q '^Signature=adhoc$' "$signatureDetails" || fail "app has a non-ad-hoc signature"
    if rg -q '^Authority=' "$signatureDetails"; then
      fail "app has a signing authority"
    else
      local authorityStatus=$?
      [[ $authorityStatus -eq 1 ]] || fail "could not inspect app signing authority"
    fi
    local teamIdentifier
    teamIdentifier="$(sed -n 's/^TeamIdentifier=//p' "$signatureDetails")"
    [[ -z "$teamIdentifier" || "$teamIdentifier" == "not set" ]] || fail "app has TeamIdentifier $teamIdentifier"
    local verificationDetails="$signatureDetails.verify"
    if ! codesign --verify --deep --strict "$appPath" 2>"$verificationDetails"; then
      rg -q 'code object is not signed at all' "$verificationDetails" || fail "app signature integrity validation failed"
    fi
  else
    rg -q 'code object is not signed at all' "$signatureDetails" || fail "codesign could not establish that the app is unsigned"
  fi
}

release_validate_developer_id_inputs() {
  local identity="$1"
  local teamId="$2"
  local bundleId="$3"
  [[ -n "$identity" ]] || fail "Developer ID identity is required"
  [[ "$identity" != *$'\n'* && "$identity" != *$'\r'* ]] || fail "Developer ID identity must be one line"
  [[ "$identity" == "Developer ID Application:"* ]] || fail "identity must be a Developer ID Application identity"
  if printf '%s' "$identity" | rg -q -- "$releaseForbiddenIdentityPattern"; then
    fail "identity is not allowed for distributable notarized releases"
  fi
  [[ "$teamId" =~ ^[A-Z0-9]{10}$ ]] || fail "Team ID must be a 10-character Apple Team ID"
  [[ "$teamId" != "$releaseUpstreamTeamId" ]] || fail "upstream Team ID is forbidden"
  [[ "$bundleId" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]] || fail "bundle ID must be a reverse-DNS identifier"
  [[ "$bundleId" != "$releaseUpstreamBundleIdPrefix"* ]] || fail "upstream bundle ID prefix is forbidden"
  [[ "$bundleId" != "dev.salasebas.AlTabDev" ]] || fail "Debug bundle ID cannot be used for distribution"
}

release_resolve_codesigning_identity() {
  local identity="$1"
  local teamId="$2"
  local identitiesOutput
  local identityLine
  local commonName
  local matchingLines
  local matchCount
  local recordCount=0
  local reportedCount=""
  local identityRecordPattern='^[[:space:]]*[0-9]+\)[[:space:]]+[0-9A-Fa-f]{40}[[:space:]]+"(.*)"([[:space:]]+\([^)]*\))?[[:space:]]*$'
  local identityCountPattern='^[[:space:]]*([0-9]+)[[:space:]]+valid identities found[[:space:]]*$'
  identitiesOutput="$(security find-identity -v -p codesigning)" || fail "could not list codesigning identities"
  matchingLines=""
  while IFS= read -r identityLine; do
    if [[ "$identityLine" =~ $identityRecordPattern ]]; then
      commonName="${BASH_REMATCH[1]}"
      recordCount=$((recordCount + 1))
      if [[ "$commonName" == "$identity" ]]; then
        matchingLines+="$identityLine"$'\n'
      fi
    elif [[ "$identityLine" =~ $identityCountPattern ]]; then
      [[ -z "$reportedCount" ]] || fail "codesigning identity output contains multiple summary lines"
      reportedCount="${BASH_REMATCH[1]}"
    elif [[ -n "$identityLine" ]]; then
      fail "could not safely parse codesigning identity output"
    fi
  done <<< "$identitiesOutput"
  [[ -n "$reportedCount" ]] || fail "codesigning identity output is missing its summary"
  [[ "$recordCount" == "$reportedCount" ]] || fail "codesigning identity output count does not match its records"
  [[ -n "$matchingLines" ]] || fail "no codesigning identity matches the requested Developer ID identity"
  matchCount="$(printf '%s\n' "$matchingLines" | rg -c '.' || true)"
  [[ "$matchCount" == "1" ]] || fail "requested Developer ID identity is ambiguous ($matchCount matches)"
  if printf '%s\n' "$matchingLines" | rg -q 'CSSMERR_TP_CERT_REVOKED|CSSMERR_TP_NOT_TRUSTED|CSSMERR'; then
    fail "matched Developer ID identity is not trusted or is revoked"
  fi
  [[ "$identity" =~ \(([A-Z0-9]{10})\)$ ]] || fail "Developer ID identity must end with its 10-character Team ID"
  [[ "${BASH_REMATCH[1]}" == "$teamId" ]] || fail "Developer ID identity does not match requested Team ID $teamId"
}

release_plists_match() {
  python3 -I - "$1" "$2" <<'PY'
import plistlib
import sys

def strictly_equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(strictly_equal(left[key], right[key]) for key in left)
    if isinstance(left, (list, tuple)):
        return len(left) == len(right) and all(strictly_equal(a, b) for a, b in zip(left, right))
    return left == right

try:
    with open(sys.argv[1], "rb") as left_file, open(sys.argv[2], "rb") as right_file:
        left = plistlib.load(left_file)
        right = plistlib.load(right_file)
except Exception as error:
    print(f"could not compare property lists: {error}", file=sys.stderr)
    sys.exit(2)
sys.exit(0 if strictly_equal(left, right) else 1)
PY
}

release_validate_notarized_slice() {
  local appPath="$1"
  local signatureDetails="$2"
  local expectedIdentity="$3"
  local expectedTeamId="$4"
  local expectedEntitlementsPath="$5"
  local architecture="$6"
  codesign --display --verbose=4 --architecture "$architecture" "$appPath" >/dev/null 2>"$signatureDetails" || fail "could not inspect Developer ID signature for $architecture"
  if rg -q '^Signature=adhoc$' "$signatureDetails"; then
    fail "notarized app has an ad-hoc signature"
  fi
  local authority
  authority="$(sed -n 's/^Authority=//p' "$signatureDetails" | sed -n '1p')"
  [[ -n "$authority" ]] || fail "notarized app has no signing authority"
  [[ "$authority" == "Developer ID Application:"* ]] || fail "notarized app authority is not Developer ID Application: $authority"
  if printf '%s' "$authority" | rg -q -- "$releaseForbiddenIdentityPattern"; then
    fail "notarized app uses a forbidden signing authority"
  fi
  [[ "$authority" == "$expectedIdentity" ]] || fail "signed authority '$authority' does not match requested identity"
  local teamIdentifier
  teamIdentifier="$(sed -n 's/^TeamIdentifier=//p' "$signatureDetails" | sed -n '1p')"
  [[ -n "$teamIdentifier" && "$teamIdentifier" != "not set" ]] || fail "notarized app is missing TeamIdentifier"
  [[ "$teamIdentifier" == "$expectedTeamId" ]] || fail "signed TeamIdentifier $teamIdentifier does not match requested Team ID $expectedTeamId"
  [[ "$teamIdentifier" != "$releaseUpstreamTeamId" ]] || fail "notarized app uses the forbidden upstream Team ID"
  local codeDirectory
  local codeDirectoryPattern='(^|[[:space:]])flags=0x[0-9A-Fa-f]+\(([A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*)\)([[:space:]]|$)'
  local runtimeFlags
  codeDirectory="$(sed -n '/^CodeDirectory /p' "$signatureDetails" | sed -n '1p')"
  [[ -n "$codeDirectory" ]] || fail "notarized app signature is missing CodeDirectory flags"
  [[ "$codeDirectory" =~ $codeDirectoryPattern ]] || fail "notarized app has unparseable CodeDirectory flags"
  runtimeFlags="${BASH_REMATCH[2]//[[:space:]]/}"
  [[ ",$runtimeFlags," == *,runtime,* ]] || fail "notarized app is missing Hardened Runtime"
  local actualEntitlementsPath="$signatureDetails.entitlements.plist"
  local entitlementsDetails="$signatureDetails.entitlements.log"
  local comparisonStatus
  codesign --display --xml --entitlements - --architecture "$architecture" "$appPath" >"$actualEntitlementsPath" 2>"$entitlementsDetails" || fail "could not inspect signed entitlements for $architecture"
  [[ -s "$actualEntitlementsPath" ]] || fail "signed app has no entitlements"
  plutil -lint "$actualEntitlementsPath" >/dev/null || fail "signed app entitlements are invalid"
  if release_plists_match "$expectedEntitlementsPath" "$actualEntitlementsPath"; then
    comparisonStatus=0
  else
    comparisonStatus=$?
    [[ $comparisonStatus -eq 1 ]] || fail "could not compare signed entitlements"
    fail "signed entitlements do not match expected entitlements"
  fi
}

release_validate_notarized_app() {
  local appPath="$1"
  local signatureDetails="$2"
  local expectedIdentity="$3"
  local expectedTeamId="$4"
  local expectedEntitlementsPath="$5"
  local verifyDetails="$signatureDetails.verify"
  local assessDetails="$signatureDetails.spctl"
  local stapleDetails="$signatureDetails.stapler"
  local architecture
  codesign --verify --deep --strict --verbose=2 "$appPath" 2>"$verifyDetails" || fail "Developer ID signature verification failed"
  [[ -f "$expectedEntitlementsPath" && ! -L "$expectedEntitlementsPath" ]] || fail "expected entitlements are missing or not a regular file"
  plutil -lint "$expectedEntitlementsPath" >/dev/null || fail "expected entitlements are invalid"
  for architecture in "${releaseRequiredArchitectures[@]}"; do
    release_validate_notarized_slice "$appPath" "$signatureDetails.$architecture" "$expectedIdentity" "$expectedTeamId" "$expectedEntitlementsPath" "$architecture"
  done
  spctl --assess --type execute -vv "$appPath" >"$assessDetails" 2>&1 || fail "Gatekeeper assessment failed for notarized app"
  rg -q 'accepted|source=Notarized Developer ID|Notarized Developer ID' "$assessDetails" || fail "Gatekeeper did not accept the app as notarized Developer ID"
  xcrun stapler validate "$appPath" >"$stapleDetails" 2>&1 || fail "notarization ticket validation failed"
  rg -q 'The validate action worked|worked!' "$stapleDetails" || fail "stapler did not confirm a valid notarization ticket"
}

release_print_safe_diagnostics() {
  local detailsFile="$1"
  if rg -n -i -- "$releaseCredentialPattern|password|passwd|api[_-]?key|issuer|authorization|bearer|BEGIN [A-Z ]*PRIVATE KEY" "$detailsFile" >/dev/null 2>&1; then
    echo "(notarization diagnostics suppressed because they may contain secrets; retrieve the notary log with notarytool log <submission-id> using your own credentials)" >&2
  else
    local inspectionStatus=$?
    if [[ $inspectionStatus -ne 1 ]]; then
      echo "(notarization diagnostics suppressed because the log could not be inspected safely)" >&2
      return
    fi
    sed -n '1,200p' "$detailsFile" >&2
  fi
}

releaseNotarizationFailureReason=""

release_submit_notarization() {
  local archivePath="$1"
  local logPath="$2"
  local notaryProfile="$3"
  local notaryKeyPath="$4"
  local notaryKeyId="$5"
  local notaryIssuer="$6"
  local notarySubmit=(xcrun notarytool submit "$archivePath" --wait --output-format json)
  local commandStatus
  local reportedStatus
  releaseNotarizationFailureReason=""
  if [[ -n "$notaryProfile" ]]; then
    notarySubmit+=(--keychain-profile "$notaryProfile")
  else
    notarySubmit+=(--key "$notaryKeyPath" --key-id "$notaryKeyId" --issuer "$notaryIssuer")
  fi
  if "${notarySubmit[@]}" >"$logPath" 2>&1; then
    commandStatus=0
  else
    commandStatus=$?
  fi
  if reportedStatus="$(plutil -extract status raw -o - "$logPath" 2>/dev/null)"; then
    :
  else
    reportedStatus=""
  fi
  case "$reportedStatus" in
    Accepted)
      if [[ $commandStatus -eq 0 ]]; then
        return 0
      fi
      releaseNotarizationFailureReason="notarytool submit failed"
      ;;
    Invalid|Rejected)
      releaseNotarizationFailureReason="Apple rejected notarization"
      ;;
    *)
      if [[ $commandStatus -ne 0 ]]; then
        releaseNotarizationFailureReason="notarytool submit failed"
      else
        releaseNotarizationFailureReason="notarization did not report Accepted"
      fi
      ;;
  esac
  return 1
}

release_require_accepted_notarization() {
  local archivePath="$1"
  local logPath="$2"
  local notaryProfile="$3"
  local notaryKeyPath="$4"
  local notaryKeyId="$5"
  local notaryIssuer="$6"
  if release_submit_notarization "$archivePath" "$logPath" "$notaryProfile" "$notaryKeyPath" "$notaryKeyId" "$notaryIssuer"; then
    return 0
  fi
  release_print_safe_diagnostics "$logPath"
  fail "$releaseNotarizationFailureReason"
}

release_validate_forbidden_bundle_content() {
  local appPath="$1"
  if rg -a -n -i --hidden "$releaseForbiddenBundlePattern" "$appPath"; then
    fail "packaged app contains an upstream identity, service, credential, or release secret"
  else
    local scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan packaged app for forbidden content"
  fi
}
