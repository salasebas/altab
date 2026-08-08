#!/usr/bin/env bash
# Preflight for interactive Debug and routine local Release builds.
# Requires the canonical "Local Self-Signed" identity unless an explicit override is active.
# Source this file, then call preflight_local_signing with the intended identity name.
# Environment:
#   ALTAB_CODE_SIGN_IDENTITY  — when set, selects identity or "-" for ad-hoc
#   ALTAB_LOCAL_XCCONFIG      — optional path to ignored local.xcconfig (default: config/local.xcconfig)
#   ALTAB_SKIP_SIGNING_PREFLIGHT — when "1", skip (CI/tests only)

set -euo pipefail

CANONICAL_LOCAL_IDENTITY="Local Self-Signed"

preflight_local_signing_fail() {
  echo "local signing preflight failed: $1" >&2
  exit 1
}

preflight_local_signing_count_exact_identities() {
  local identities="$1"
  local name="$2"
  local matches
  matches="$(printf '%s\n' "$identities" | grep -F "\"$name\"" || true)"
  printf '%s\n' "$matches" | awk '{ print $2 }' | sort -u | grep -c . || true
}

preflight_local_signing_read_local_xcconfig_identity() {
  local path="${ALTAB_LOCAL_XCCONFIG:-}"
  if [[ -z "$path" ]]; then
    local repoRoot="${ALTAB_REPO_ROOT:-}"
    if [[ -z "$repoRoot" ]]; then
      repoRoot="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
    fi
    path="$repoRoot/config/local.xcconfig"
  fi
  [[ -f "$path" ]] || return 0
  local line value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*// ]] && continue
    if [[ "$line" =~ ^[[:space:]]*CODE_SIGN_IDENTITY[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value%%//*}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      printf '%s' "$value"
      return 0
    fi
  done <"$path"
}

preflight_local_signing_remediation() {
  cat <<EOF >&2
Install the stable local identity once per Mac (shared by every clone and Git worktree for this user):

  scripts/codesign/setup_local.sh

The certificate and private key live in your Keychain, outside the repository. No per-worktree
config/local.xcconfig is required for the standard path.

Ad-hoc signing is an explicit escape hatch (not the default). Privacy grants (Accessibility,
Screen Recording) may not survive a rebuild when using ad-hoc signatures:

  ALTAB_CODE_SIGN_IDENTITY=- scripts/build_local.sh
  ALTAB_CODE_SIGN_IDENTITY=- bash ai/build.sh

Remove the local identity later with scripts/codesign/remove_local.sh.
Guide: docs/building-and-troubleshooting.md#example-2-repair-local-self-signed
EOF
}

# Resolves the effective identity the interactive local path will use.
# Prints the identity on stdout. Empty string is invalid.
preflight_local_signing_resolve_identity() {
  if [[ "${ALTAB_CODE_SIGN_IDENTITY+x}" == "x" ]]; then
    printf '%s' "$ALTAB_CODE_SIGN_IDENTITY"
    return 0
  fi
  local localIdentity
  localIdentity="$(preflight_local_signing_read_local_xcconfig_identity || true)"
  if [[ -n "${localIdentity:-}" ]]; then
    printf '%s' "$localIdentity"
    return 0
  fi
  printf '%s' "$CANONICAL_LOCAL_IDENTITY"
}

preflight_local_signing() {
  if [[ "${ALTAB_SKIP_SIGNING_PREFLIGHT:-}" == "1" ]]; then
    return 0
  fi
  local identity
  identity="$(preflight_local_signing_resolve_identity)"
  if [[ -z "$identity" ]]; then
    preflight_local_signing_fail "CODE_SIGN_IDENTITY resolved to an empty value"
  fi
  if [[ "$identity" == "-" ]]; then
    cat <<EOF >&2
warning: using explicit ad-hoc signing (CODE_SIGN_IDENTITY=-).
macOS privacy grants (Accessibility, Screen Recording) use a designated requirement that can change
when the executable is rebuilt, so permissions may need to be re-granted after each rebuild.
Prefer the once-per-Mac identity from scripts/codesign/setup_local.sh for routine local work.
EOF
    return 0
  fi
  if [[ "$identity" != "$CANONICAL_LOCAL_IDENTITY" ]]; then
    # Advanced override (Apple Development / Developer ID / custom). Never auto-pick; user chose it.
    local allIdentities validIdentities validCount allCount
    validIdentities="$(security find-identity -v -p codesigning 2>/dev/null)" \
      || preflight_local_signing_fail "code-signing identities could not be read"
    allIdentities="$(security find-identity -p codesigning 2>/dev/null)" \
      || preflight_local_signing_fail "code-signing identities could not be read"
    validCount="$(preflight_local_signing_count_exact_identities "$validIdentities" "$identity")"
    allCount="$(preflight_local_signing_count_exact_identities "$allIdentities" "$identity")"
    if [[ "$validCount" -eq 1 ]]; then
      return 0
    fi
    if [[ "$allCount" -gt 0 ]]; then
      preflight_local_signing_fail "identity \"$identity\" exists but is not valid for code signing"
    fi
    preflight_local_signing_fail "identity \"$identity\" was not found in the Keychain"
  fi
  local validIdentities allIdentities validCount allCount
  validIdentities="$(security find-identity -v -p codesigning 2>/dev/null)" \
    || preflight_local_signing_fail "code-signing identities could not be read"
  allIdentities="$(security find-identity -p codesigning 2>/dev/null)" \
    || preflight_local_signing_fail "code-signing identities could not be read"
  validCount="$(preflight_local_signing_count_exact_identities "$validIdentities" "$CANONICAL_LOCAL_IDENTITY")"
  allCount="$(preflight_local_signing_count_exact_identities "$allIdentities" "$CANONICAL_LOCAL_IDENTITY")"
  if [[ "$validCount" -eq 1 && "$allCount" -eq 1 ]]; then
    return 0
  fi
  if [[ "$validCount" -gt 1 || "$allCount" -gt 1 ]]; then
    echo "local signing preflight failed: multiple \"$CANONICAL_LOCAL_IDENTITY\" identities exist; remove duplicates with scripts/codesign/remove_local.sh or Keychain Access" >&2
    preflight_local_signing_remediation
    exit 1
  fi
  if [[ "$allCount" -gt 0 ]]; then
    echo "local signing preflight failed: an incomplete or invalid \"$CANONICAL_LOCAL_IDENTITY\" identity exists" >&2
    preflight_local_signing_remediation
    exit 1
  fi
  echo "local signing preflight failed: missing \"$CANONICAL_LOCAL_IDENTITY\" code-signing identity" >&2
  preflight_local_signing_remediation
  exit 1
}

# When executed directly (not sourced), run the preflight.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  preflight_local_signing
fi
