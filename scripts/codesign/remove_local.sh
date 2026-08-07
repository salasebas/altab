#!/usr/bin/env bash

set -euo pipefail

identityName="Local Self-Signed"
scriptDirectory="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repoRoot="$(cd -P "$scriptDirectory/../.." && pwd -P)"
temporaryRoot="${TMPDIR:-/tmp}"
temporaryDirectory=""
removeLegacyAdminTrust=false

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--include-legacy-admin-trust" ) ]]; then
  echo "usage: remove_local.sh [--include-legacy-admin-trust]" >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  removeLegacyAdminTrust=true
fi

fail() {
  echo "Local code-signing removal failed: $1" >&2
  exit 1
}

trim_keychain_path() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s\n' "$value"
}

count_identity_matches() {
  local identities="$1"
  local matches
  matches="$(printf '%s\n' "$identities" | grep -F "\"$identityName\"" || true)"
  printf '%s\n' "$matches" | awk '{ print $2 }' | sort -u | grep -c . || true
}

exact_certificate_hashes() {
  local certificates="$1"
  awk -v name="$identityName" '
    /^SHA-256 hash: / { hash = $3 }
    $0 == "    \"alis\"<blob>=\"" name "\"" && hash != "" { print hash }
  ' <<<"$certificates" | sort -u
}

remove_temporary_material() {
  [[ -n "$temporaryDirectory" && -d "$temporaryDirectory" ]] || return 0
  case "$temporaryDirectory" in
    "$temporaryRoot"/altab-local-codesign-remove.*) rm -rf -- "$temporaryDirectory" ;;
    *) return 1 ;;
  esac
}

cleanup() {
  local exitStatus=$?
  trap - EXIT HUP INT TERM
  if [[ -n "$temporaryDirectory" && -d "$temporaryDirectory" ]]; then
    if ! remove_temporary_material; then
      echo "Warning: temporary certificate material could not be removed" >&2
      [[ "$exitStatus" -ne 0 ]] || exitStatus=1
    fi
  fi
  exit "$exitStatus"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

command -v security >/dev/null || fail "the macOS security tool is required"

temporaryRoot="$(cd -P "$temporaryRoot" 2>/dev/null && pwd -P)" || fail "the temporary directory root could not be resolved"
case "$temporaryRoot/" in
  "$repoRoot/"*) fail "TMPDIR must point outside the repository checkout" ;;
esac

keychainOutput="$(security default-keychain -d user 2>/dev/null)" || fail "the default user Keychain could not be read"
userKeychain="$(trim_keychain_path "$keychainOutput")"
[[ -n "$userKeychain" ]] || fail "the default user Keychain path was empty"
searchIdentities="$(security find-identity -p codesigning 2>/dev/null)" || fail "code-signing identities could not be read"
defaultIdentities="$(security find-identity -p codesigning "$userKeychain" 2>/dev/null)" || fail "the default user Keychain identities could not be read"
identities="$searchIdentities
$defaultIdentities"
identityCount="$(count_identity_matches "$identities")"
searchIdentityCount="$(count_identity_matches "$searchIdentities")"
searchCertificateMatches="$(security find-certificate -a -c "$identityName" -Z 2>/dev/null)" || fail "certificates could not be read"
defaultCertificateMatches="$(security find-certificate -a -c "$identityName" -Z "$userKeychain" 2>/dev/null)" || fail "the default user Keychain certificates could not be read"
certificateMatches="$searchCertificateMatches
$defaultCertificateMatches"
certificateHashes="$(exact_certificate_hashes "$certificateMatches")"
searchCertificateHashes="$(exact_certificate_hashes "$searchCertificateMatches")"
certificateCount="$(printf '%s\n' "$certificateHashes" | grep -c . || true)"

if [[ "$identityCount" -eq 0 && "$certificateCount" -eq 0 ]]; then
  echo "$identityName is not installed; no changes were made."
  exit 0
fi
if [[ "$identityCount" -gt 1 || "$certificateCount" -gt 1 ]]; then
  echo "$certificateMatches" >&2
  fail "multiple matching items exist; remove them individually by hash with security delete-identity -Z HASH -t"
fi
if [[ "$identityCount" -eq 1 && "$certificateCount" -ne 1 ]]; then
  fail "the identity does not have one exact matching certificate; inspect it with security find-certificate -a -c '$identityName' -Z"
fi
certificateSha256="$(printf '%s\n' "$certificateHashes" | head -n 1)"

echo "This will remove the $identityName certificate, private key, and user trust setting from your Keychain search list."
if [[ "$removeLegacyAdminTrust" == true ]]; then
  echo "It will also request administrator approval to remove trust created by the previous setup helper."
fi
printf 'Continue? [y/N] '
if ! IFS= read -r confirmation; then
  echo "Removal cancelled; no changes were made."
  exit 0
fi
case "$confirmation" in
  y|Y|yes|YES) ;;
  *) echo "Removal cancelled; no changes were made."; exit 0 ;;
esac

if [[ "$removeLegacyAdminTrust" == true ]]; then
  command -v openssl >/dev/null || fail "openssl is required for legacy trust removal"
  umask 077
  temporaryDirectory="$(mktemp -d "$temporaryRoot/altab-local-codesign-remove.XXXXXX")" || fail "a private temporary directory could not be created"
  temporaryDirectory="$(cd -P "$temporaryDirectory" 2>/dev/null && pwd -P)" || fail "the private temporary directory could not be resolved"
  case "$temporaryDirectory/" in
    "$repoRoot/"*) fail "temporary certificate material must remain outside the repository checkout" ;;
  esac
  certificateFile="$temporaryDirectory/certificate.pem"
  legacyRemovalLog="$temporaryDirectory/legacy-removal.log"
  if grep -Fxq "$certificateSha256" <<<"$searchCertificateHashes"; then
    security find-certificate -c "$identityName" -p >"$certificateFile" 2>"$legacyRemovalLog" || fail "the legacy certificate could not be exported"
  else
    security find-certificate -c "$identityName" -p "$userKeychain" >"$certificateFile" 2>"$legacyRemovalLog" || fail "the legacy certificate could not be exported from the default user Keychain"
  fi
  exportedSha256="$(openssl x509 -in "$certificateFile" -noout -fingerprint -sha256 2>>"$legacyRemovalLog" | sed 's/.*=//; s/://g' | tr '[:lower:]' '[:upper:]')" || fail "the legacy certificate fingerprint could not be read"
  if [[ "$exportedSha256" != "$certificateSha256" ]]; then
    fail "the exact legacy certificate could not be selected safely; remove near-name collisions first"
  fi
  if ! security remove-trusted-cert -d "$certificateFile" >>"$legacyRemovalLog" 2>&1; then
    fail "the legacy administrative trust update was denied or failed"
  fi
fi

if [[ "$identityCount" -eq 1 ]]; then
  if [[ "$searchIdentityCount" -eq 1 ]]; then
    security delete-identity -Z "$certificateSha256" -t >/dev/null || fail "the Keychain update was denied or failed"
  else
    security delete-identity -Z "$certificateSha256" -t "$userKeychain" >/dev/null || fail "the default user Keychain update was denied or failed"
  fi
else
  if grep -Fxq "$certificateSha256" <<<"$searchCertificateHashes"; then
    security delete-certificate -Z "$certificateSha256" -t >/dev/null || fail "the Keychain update was denied or failed"
  else
    security delete-certificate -Z "$certificateSha256" -t "$userKeychain" >/dev/null || fail "the default user Keychain update was denied or failed"
  fi
fi

remainingSearchIdentities="$(security find-identity -p codesigning 2>/dev/null)" || fail "identity removal could not be verified"
remainingDefaultIdentities="$(security find-identity -p codesigning "$userKeychain" 2>/dev/null)" || fail "default user Keychain identity removal could not be verified"
remainingIdentities="$remainingSearchIdentities
$remainingDefaultIdentities"
remainingSearchCertificates="$(security find-certificate -a -c "$identityName" -Z 2>/dev/null)" || fail "certificate removal could not be verified"
remainingDefaultCertificates="$(security find-certificate -a -c "$identityName" -Z "$userKeychain" 2>/dev/null)" || fail "default user Keychain certificate removal could not be verified"
remainingCertificates="$remainingSearchCertificates
$remainingDefaultCertificates"
remainingCertificateHashes="$(exact_certificate_hashes "$remainingCertificates")"
if [[ "$(count_identity_matches "$remainingIdentities")" -ne 0 || -n "$remainingCertificateHashes" ]]; then
  fail "$identityName could not be verified as removed"
fi
if ! remove_temporary_material; then
  fail "temporary certificate material could not be removed"
fi
temporaryDirectory=""
echo "$identityName was removed from the user Keychain and trust settings."
