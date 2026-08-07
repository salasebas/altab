#!/usr/bin/env bash

releaseContractsRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$releaseContractsRoot/forbidden_service_contracts.sh"
releaseArtifactContractsVersion=1
releaseRequiredSourcePaths=(
  ai/build.sh
  scripts/package_release.sh
  scripts/verify_release_artifacts.sh
  scripts/check_release_packaging.sh
  scripts/check_source_compliance.sh
  scripts/forbidden_service_contracts.sh
  scripts/release_artifact_contracts.sh
  scripts/check_service_isolation.sh
  scripts/check_symbol_assets.sh
  scripts/check_unrestricted_features.sh
  .github/RELEASE_NOTES_TEMPLATE.md
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
releaseManifestFields=(
  'Git tag'
  'Xcode'
  'Swift'
  'macOS SDK'
  'Build architectures'
  'Build command'
  'Signing status: **unsigned**'
  'Notarization status: **not notarized**'
  'Service-isolation guard: **passed against the packaged app**'
  'Symbol-asset compliance guard: **passed against the packaged app**'
  'Unrestricted-feature guard: **passed against the packaged app**'
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

release_validate_forbidden_bundle_content() {
  local appPath="$1"
  if rg -a -n -i --hidden "$releaseForbiddenBundlePattern" "$appPath"; then
    fail "packaged app contains an upstream identity, service, credential, or release secret"
  else
    local scanStatus=$?
    [[ $scanStatus -eq 1 ]] || fail "could not scan packaged app for forbidden content"
  fi
}
