#!/usr/bin/env bash

set -euo pipefail

identityName="Local Self-Signed"
scriptDirectory="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repoRoot="$(cd -P "$scriptDirectory/../.." && pwd -P)"
temporaryRoot="${TMPDIR:-/tmp}"
temporaryDirectory=""
activeChildPid=""
importAttempted=false
userKeychain=""
certificateSha1=""
certificateSha256=""
setupComplete=false

fail() {
  echo "Local code-signing setup failed: $1" >&2
  exit 1
}

stop_active_child() {
  [[ -n "$activeChildPid" ]] || return 0
  kill -TERM "$activeChildPid" 2>/dev/null || true
  local _
  for _ in {1..20}; do
    kill -0 "$activeChildPid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$activeChildPid" 2>/dev/null; then
    kill -KILL "$activeChildPid" 2>/dev/null || true
  fi
  wait "$activeChildPid" 2>/dev/null || true
  activeChildPid=""
}

handle_signal() {
  local exitStatus="$1"
  trap - HUP INT TERM
  stop_active_child
  exit "$exitStatus"
}

run_child() {
  "$@" &
  activeChildPid=$!
  local childStatus=0
  wait "$activeChildPid" || childStatus=$?
  activeChildPid=""
  return "$childStatus"
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
    "$temporaryRoot"/altab-local-codesign.*) rm -rf -- "$temporaryDirectory" ;;
    *) return 1 ;;
  esac
}

cleanup() {
  local exitStatus=$?
  local rollbackSucceeded=false
  trap - EXIT HUP INT TERM
  if [[ -n "$temporaryDirectory" && -d "$temporaryDirectory" ]]; then
    if ! remove_temporary_material; then
      echo "Warning: temporary certificate material could not be removed" >&2
      [[ "$exitStatus" -ne 0 ]] || exitStatus=1
    fi
  fi
  if [[ "$importAttempted" == true && "$setupComplete" != true && -n "$certificateSha256" && -n "$userKeychain" ]]; then
    local rollbackIdentities=""
    local rollbackCertificates=""
    local identityReadSucceeded=false
    local certificateReadSucceeded=false
    local rollbackCommandSucceeded=false
    if rollbackIdentities="$(security find-identity -p codesigning "$userKeychain" 2>/dev/null)"; then
      identityReadSucceeded=true
    fi
    if rollbackCertificates="$(security find-certificate -a -c "$identityName" -Z "$userKeychain" 2>/dev/null)"; then
      certificateReadSucceeded=true
    fi
    local rollbackIdentityCount
    local rollbackCertificateHashes
    rollbackIdentityCount="$(count_identity_matches "$rollbackIdentities")"
    rollbackCertificateHashes="$(exact_certificate_hashes "$rollbackCertificates")"
    if [[ "$identityReadSucceeded" == true && "$certificateReadSucceeded" == true ]]; then
      if [[ "$rollbackIdentityCount" -gt 0 ]]; then
        if security delete-identity -Z "$certificateSha256" -t "$userKeychain" >/dev/null 2>&1; then
          rollbackCommandSucceeded=true
        fi
      elif grep -Fxq "$certificateSha256" <<<"$rollbackCertificateHashes"; then
        if security delete-certificate -Z "$certificateSha256" -t "$userKeychain" >/dev/null 2>&1; then
          rollbackCommandSucceeded=true
        fi
      fi
      if rollbackIdentities="$(security find-identity -p codesigning "$userKeychain" 2>/dev/null)" && rollbackCertificates="$(security find-certificate -a -c "$identityName" -Z "$userKeychain" 2>/dev/null)"; then
        rollbackIdentityCount="$(count_identity_matches "$rollbackIdentities")"
        rollbackCertificateHashes="$(exact_certificate_hashes "$rollbackCertificates")"
        if [[ "$rollbackCommandSucceeded" == true && "$rollbackIdentityCount" -eq 0 ]] && ! grep -Fxq "$certificateSha256" <<<"$rollbackCertificateHashes"; then
          rollbackSucceeded=true
        fi
      fi
    fi
    if [[ "$rollbackSucceeded" != true ]]; then
      echo "Warning: the partial identity could not be rolled back or its absence could not be proven. Run $scriptDirectory/remove_local.sh before retrying, then inspect Local Self-Signed items in Keychain Access. Exact certificate hash: $certificateSha256." >&2
    fi
  fi
  exit "$exitStatus"
}

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

command -v openssl >/dev/null || fail "openssl is required"
command -v security >/dev/null || fail "the macOS security tool is required"

temporaryRoot="$(cd -P "$temporaryRoot" 2>/dev/null && pwd -P)" || fail "the temporary directory root could not be resolved"
case "$temporaryRoot/" in
  "$repoRoot/"*) fail "TMPDIR must point outside the repository checkout" ;;
esac

keychainOutput="$(security default-keychain -d user 2>/dev/null)" || fail "the default user Keychain could not be read"
userKeychain="$(trim_keychain_path "$keychainOutput")"
[[ -n "$userKeychain" ]] || fail "the default user Keychain path was empty"
userKeychainList="$(security list-keychains -d user 2>/dev/null)" || fail "the user Keychain search list could not be read"
userKeychainIsSearchable=false
while IFS= read -r listedKeychain; do
  if [[ "$(trim_keychain_path "$listedKeychain")" == "$userKeychain" ]]; then
    userKeychainIsSearchable=true
    break
  fi
done <<<"$userKeychainList"
[[ "$userKeychainIsSearchable" == true ]] || fail "the default user Keychain is not in the user search list; restore it in Keychain Access before retrying"

for legacyArtifact in codesign.conf codesign.crt codesign.key codesign.pem codesign.p12; do
  [[ ! -e "$repoRoot/$legacyArtifact" ]] || fail "legacy certificate material exists at the repository root; remove $legacyArtifact manually before retrying"
done

validIdentities="$(security find-identity -v -p codesigning 2>/dev/null)" || fail "code-signing identities could not be read"
validIdentityCount="$(count_identity_matches "$validIdentities")"
allIdentities="$(security find-identity -p codesigning 2>/dev/null)" || fail "existing code-signing identities could not be read"
allIdentityCount="$(count_identity_matches "$allIdentities")"
certificateMatches="$(security find-certificate -a -c "$identityName" -Z 2>/dev/null)" || fail "existing certificates could not be read"
certificateHashes="$(exact_certificate_hashes "$certificateMatches")"
certificateCount="$(printf '%s\n' "$certificateHashes" | grep -c . || true)"
if [[ "$validIdentityCount" -eq 1 && "$allIdentityCount" -eq 1 && "$certificateCount" -eq 1 ]]; then
  echo "$identityName is already installed and valid; no changes were made."
  exit 0
fi
if [[ "$validIdentityCount" -gt 1 || "$allIdentityCount" -gt 1 || "$certificateCount" -gt 1 ]]; then
  fail "multiple $identityName items exist; inspect them with security find-certificate -a -c '$identityName' -Z and remove duplicates explicitly"
fi
if [[ "$allIdentityCount" -gt 0 || "$certificateCount" -gt 0 ]]; then
  fail "an incomplete or invalid $identityName item exists; inspect its exact hash with security find-certificate -a -c '$identityName' -Z before retrying"
fi

cat <<EOF
This once-per-Mac setup adds a "$identityName" identity to your default user Keychain and trusts it only for code signing.
Every clone and Git worktree for this user can then use the same stable signer (no per-worktree config/local.xcconfig).
macOS may request authentication. No system-wide Gatekeeper setting will be changed.
EOF
printf 'Continue? [y/N] '
if ! IFS= read -r confirmation; then
  echo "Setup cancelled; no changes were made."
  exit 0
fi
case "$confirmation" in
  y|Y|yes|YES) ;;
  *) echo "Setup cancelled; no changes were made."; exit 0 ;;
esac

umask 077
temporaryDirectory="$(mktemp -d "$temporaryRoot/altab-local-codesign.XXXXXX")" || fail "a private temporary directory could not be created"
temporaryDirectory="$(cd -P "$temporaryDirectory" 2>/dev/null && pwd -P)" || fail "the private temporary directory could not be resolved"
case "$temporaryDirectory/" in
  "$repoRoot/"*) fail "temporary certificate material must remain outside the repository checkout" ;;
esac
certificateFile="$temporaryDirectory/codesign"
generationLog="$temporaryDirectory/generation.log"
importLog="$temporaryDirectory/import.log"
verificationLog="$temporaryDirectory/verification.log"

if ! run_child "$scriptDirectory/generate_local_selfsigned_certificate.sh" "$certificateFile" >"$generationLog" 2>&1; then
  fail "temporary certificate generation failed"
fi
certificateSha1="$(openssl x509 -in "$certificateFile.crt" -noout -fingerprint -sha1 2>>"$generationLog" | sed 's/.*=//; s/://g' | tr '[:lower:]' '[:upper:]')" || fail "the generated certificate fingerprint could not be read"
certificateSha256="$(openssl x509 -in "$certificateFile.crt" -noout -fingerprint -sha256 2>>"$generationLog" | sed 's/.*=//; s/://g' | tr '[:lower:]' '[:upper:]')" || fail "the generated certificate fingerprint could not be read"
[[ "$certificateSha1" =~ ^[0-9A-F]{40}$ && "$certificateSha256" =~ ^[0-9A-F]{64}$ ]] || fail "the generated certificate fingerprint was invalid"

importAttempted=true
if ! run_child "$scriptDirectory/import_certificate_into_main_keychain.sh" "$certificateFile" "$userKeychain" >"$importLog" 2>&1; then
  fail "the Keychain or trust update was denied or failed; temporary material was removed"
fi
verifiedIdentities="$(security find-identity -v -p codesigning "$userKeychain" 2>"$verificationLog")" || fail "the imported identity could not be verified"
verifiedIdentity="$(printf '%s\n' "$verifiedIdentities" | grep -F "$certificateSha1" | grep -F "\"$identityName\"" || true)"
if [[ -z "$verifiedIdentity" ]]; then
  fail "the imported $identityName identity could not be verified"
fi

if ! remove_temporary_material; then
  fail "temporary certificate material could not be removed"
fi
temporaryDirectory=""
setupComplete=true
echo "$identityName was installed and verified for local code signing."
