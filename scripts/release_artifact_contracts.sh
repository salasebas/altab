#!/usr/bin/env bash

releaseContractsRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$releaseContractsRoot/forbidden_service_contracts.sh"
releaseArtifactContractsVersion=1
releaseRequiredSourcePaths=(
  ai/build.sh
  scripts/package_release.sh
  scripts/package_notarized_release.sh
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
  local matchingLines
  local matchCount
  identitiesOutput="$(security find-identity -v -p codesigning)" || fail "could not list codesigning identities"
  matchingLines="$(printf '%s\n' "$identitiesOutput" | rg -F -- "$identity" || true)"
  [[ -n "$matchingLines" ]] || fail "no codesigning identity matches the requested Developer ID identity"
  matchCount="$(printf '%s\n' "$matchingLines" | rg -c '.' || true)"
  [[ "$matchCount" == "1" ]] || fail "requested Developer ID identity is ambiguous ($matchCount matches)"
  if printf '%s\n' "$matchingLines" | rg -q 'CSSMERR_TP_CERT_REVOKED|CSSMERR_TP_NOT_TRUSTED|CSSMERR'; then
    fail "matched Developer ID identity is not trusted or is revoked"
  fi
  if ! printf '%s\n' "$matchingLines" | rg -q '\([A-Z0-9]{10}\)'; then
    : # identity string may already include Team ID in parentheses or omit it
  fi
  if printf '%s' "$identity" | rg -q "\\($teamId\\)"; then
    return 0
  fi
  if printf '%s\n' "$matchingLines" | rg -q "\\($teamId\\)"; then
    return 0
  fi
  # Accept when the identity string is exact and the caller-supplied Team ID will be
  # verified against the signed app's TeamIdentifier after codesign.
  return 0
}

release_validate_notarized_app() {
  local appPath="$1"
  local signatureDetails="$2"
  local expectedIdentity="$3"
  local expectedTeamId="$4"
  local verifyDetails="$signatureDetails.verify"
  local assessDetails="$signatureDetails.spctl"
  local stapleDetails="$signatureDetails.stapler"
  codesign --verify --deep --strict --verbose=2 "$appPath" 2>"$verifyDetails" || fail "Developer ID signature verification failed"
  codesign --display --verbose=4 "$appPath" >/dev/null 2>"$signatureDetails" || fail "could not inspect Developer ID signature"
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
  if [[ -n "$expectedIdentity" && "$expectedIdentity" != "$authority" && "$expectedIdentity" != *"$authority"* && "$authority" != *"${expectedIdentity#Developer ID Application: }"* ]]; then
    # Require the selected identity text to match the leaf authority when both are full strings.
    if [[ "$expectedIdentity" == "Developer ID Application:"* && "$authority" != "$expectedIdentity" ]]; then
      fail "signed authority '$authority' does not match requested identity"
    fi
  fi
  local teamIdentifier
  teamIdentifier="$(sed -n 's/^TeamIdentifier=//p' "$signatureDetails" | sed -n '1p')"
  [[ -n "$teamIdentifier" && "$teamIdentifier" != "not set" ]] || fail "notarized app is missing TeamIdentifier"
  [[ "$teamIdentifier" == "$expectedTeamId" ]] || fail "signed TeamIdentifier $teamIdentifier does not match requested Team ID $expectedTeamId"
  [[ "$teamIdentifier" != "$releaseUpstreamTeamId" ]] || fail "notarized app uses the forbidden upstream Team ID"
  local runtimeFlags
  runtimeFlags="$(sed -n 's/^CodeDirectory.*flags=//p' "$signatureDetails" | sed -n '1p')"
  if [[ -n "$runtimeFlags" ]]; then
    printf '%s' "$runtimeFlags" | rg -q 'runtime' || fail "notarized app is missing Hardened Runtime"
  fi
  spctl --assess --type execute -vv "$appPath" >"$assessDetails" 2>&1 || fail "Gatekeeper assessment failed for notarized app"
  rg -q 'accepted|source=Notarized Developer ID|Notarized Developer ID' "$assessDetails" || fail "Gatekeeper did not accept the app as notarized Developer ID"
  xcrun stapler validate "$appPath" >"$stapleDetails" 2>&1 || fail "notarization ticket validation failed"
  rg -q 'The validate action worked|worked!' "$stapleDetails" || fail "stapler did not confirm a valid notarization ticket"
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
