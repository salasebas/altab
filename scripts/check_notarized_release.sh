#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

testRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-notarized-release-check.XXXXXX")"
testRoot="$(cd "$testRoot" && pwd)"

cleanup() {
  local exitStatus=$?
  trap - EXIT HUP INT TERM
  rm -rf -- "$testRoot"
  exit "$exitStatus"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  echo "notarized-release check failed: $1" >&2
  exit 1
}

require_file() {
  [[ -s "$1" && ! -L "$1" ]] || fail "missing regular file $1"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain: $text"
}

require_executable() {
  [[ -x "$1" ]] || fail "$1 is not executable"
  bash -n "$1"
}

for path in \
  scripts/package_notarized_release.sh \
  scripts/check_notarized_release.sh \
  scripts/release_artifact_contracts.sh \
  scripts/verify_release_artifacts.sh \
  .github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md \
  docs/releasing.md; do
  require_file "$path"
done
require_executable scripts/package_notarized_release.sh
require_executable scripts/check_notarized_release.sh
require_executable scripts/verify_release_artifacts.sh
bash -n scripts/release_artifact_contracts.sh

for placeholder in RELEASE TAG COMMIT BINARY_ARTIFACT SOURCE_ARTIFACT MANIFEST BUNDLE_ID TEAM_ID IDENTITY; do
  require_text .github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md "{{$placeholder}}"
done
for text in \
  'scripts/package_notarized_release.sh' \
  'Developer ID Application' \
  'notarytool' \
  'ALTAB_DEVELOPER_ID_IDENTITY' \
  'ALTAB_TEAM_ID' \
  'ALTAB_NOTARY_KEYCHAIN_PROFILE' \
  'workflow_dispatch' \
  'never silently fall back'; do
  require_text docs/releasing.md "$text"
done
for text in \
  '--identity' \
  '--team-id' \
  '--bundle-id' \
  '--notary-profile' \
  '--notary-key' \
  'notarytool submit' \
  'stapler staple' \
  'verify_release_artifacts.sh' \
  'Developer ID Application' \
  'notarized and stapled' \
  'Unsigned rebuild command'; do
  require_text scripts/package_notarized_release.sh "$text"
done
require_text scripts/release_artifact_contracts.sh 'release_validate_notarized_app'
require_text scripts/release_artifact_contracts.sh 'release_validate_developer_id_inputs'
require_text scripts/package_notarized_release.sh 'never silently'
# Ensure passwords are not accepted as CLI flags.
if rg -n -- '--password|--apple-id-password|NOTARY_PASSWORD|APPLE_ID_PASSWORD' scripts/package_notarized_release.sh; then
  fail "notarized packager must not accept passwords as command arguments"
fi

write_mock_tools() {
  mkdir -p "$testRoot/bin" "$testRoot/state" "$testRoot/app/Contents/MacOS"
  printf 'mock-app\n' >"$testRoot/app/Contents/MacOS/AlTab"
  cat >"$testRoot/bin/security" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${NOTARY_TEST_IDENTITY_MODE:-one-match}"
if [[ $# -ge 3 && "$1" == "find-identity" && "$2" == "-v" && "$3" == "-p" ]]; then
  case "$mode" in
    one-match)
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example Distributor (ABCD123456)"'
      echo '     1 valid identities found'
      ;;
    missing)
      echo '     0 valid identities found'
      ;;
    ambiguous)
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example Distributor (ABCD123456)"'
      echo '  2) BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB "Developer ID Application: Example Distributor (ABCD123456)"'
      echo '     2 valid identities found'
      ;;
    *) exit 90 ;;
  esac
  exit 0
fi
exit 91
EOF
  cat >"$testRoot/bin/codesign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${NOTARY_TEST_CODESIGN_MODE:-valid}"
if [[ "$1" == "--verify" ]]; then
  case "$mode" in
    valid|wrong-team|adhoc) exit 0 ;;
    verify-fail) echo "verify failed" >&2; exit 1 ;;
    *) exit 92 ;;
  esac
fi
if [[ "$1" == "--display" ]]; then
  case "$mode" in
    valid)
      echo "Executable=/tmp/app" >&2
      echo "Identifier=dev.example.AlTab" >&2
      echo "Format=app bundle with Mach-O universal" >&2
      echo "CodeDirectory v=20500 size=100 flags=0x10000(runtime) hashes=10+3 location=embedded" >&2
      echo "Signature size=100" >&2
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
      echo "Authority=Developer ID Certification Authority" >&2
      echo "Authority=Apple Root CA" >&2
      echo "Timestamp=1 Jan 2026" >&2
      echo "TeamIdentifier=ABCD123456" >&2
      ;;
    adhoc)
      echo "Signature=adhoc" >&2
      echo "TeamIdentifier=not set" >&2
      echo "CodeDirectory v=20500 size=100 flags=0x0 hashes=10+3 location=embedded" >&2
      ;;
    wrong-team)
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
      echo "TeamIdentifier=ZZZZZZZZZZ" >&2
      echo "CodeDirectory v=20500 size=100 flags=0x10000(runtime) hashes=10+3 location=embedded" >&2
      ;;
    *) exit 92 ;;
  esac
  exit 0
fi
exit 93
EOF
  cat >"$testRoot/bin/spctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${NOTARY_TEST_SPCTL_MODE:-accept}"
if [[ "$mode" == "accept" ]]; then
  echo "$3: accepted" >&2
  echo "source=Notarized Developer ID" >&2
  exit 0
fi
echo "$3: rejected" >&2
exit 1
EOF
  cat >"$testRoot/bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "stapler" && "$2" == "validate" ]]; then
  mode="${NOTARY_TEST_STAPLER_MODE:-ok}"
  if [[ "$mode" == "ok" ]]; then
    echo "Processing: $3"
    echo "The validate action worked!"
    exit 0
  fi
  echo "Processing: $3"
  echo "Error: The ticket is missing."
  exit 1
fi
exit 94
EOF
  chmod +x "$testRoot/bin/"*
}

run_contract_helpers() {
  local output="$1"
  shift
  env PATH="$testRoot/bin:$PATH" bash -c '
    set -euo pipefail
    fail() { echo "helper failed: $1" >&2; exit 1; }
    source scripts/release_artifact_contracts.sh
    '"$*" >"$output" 2>&1
}

write_mock_tools

# --- developer ID input validation ---
run_contract_helpers "$testRoot/ok-inputs.log" \
  'release_validate_developer_id_inputs "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "dev.example.AlTab"' \
  || fail "valid Developer ID inputs were rejected"

if run_contract_helpers "$testRoot/local-self-signed.log" \
  'release_validate_developer_id_inputs "Local Self-Signed" "ABCD123456" "dev.example.AlTab"'; then
  fail "Local Self-Signed identity must be rejected"
fi
rg -q 'not allowed|Developer ID Application' "$testRoot/local-self-signed.log" || fail "missing rejection for Local Self-Signed"

if run_contract_helpers "$testRoot/upstream-team.log" \
  'release_validate_developer_id_inputs "Developer ID Application: Example Distributor (QXD7GW8FHY)" "QXD7GW8FHY" "dev.example.AlTab"'; then
  fail "upstream Team ID must be rejected"
fi
rg -q 'upstream Team ID|forbidden' "$testRoot/upstream-team.log" || fail "missing rejection for upstream Team ID"

if run_contract_helpers "$testRoot/upstream-bundle.log" \
  'release_validate_developer_id_inputs "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "com.lwouis.alt-tab-macos"'; then
  fail "upstream bundle ID must be rejected"
fi
rg -q 'upstream bundle|forbidden' "$testRoot/upstream-bundle.log" || fail "missing rejection for upstream bundle ID"

if run_contract_helpers "$testRoot/bad-team-format.log" \
  'release_validate_developer_id_inputs "Developer ID Application: Example Distributor (ABCD123456)" "short" "dev.example.AlTab"'; then
  fail "malformed Team ID must be rejected"
fi

# --- identity resolution ---
NOTARY_TEST_IDENTITY_MODE=one-match run_contract_helpers "$testRoot/identity-ok.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"' \
  || fail "exact identity match was rejected"

if NOTARY_TEST_IDENTITY_MODE=missing run_contract_helpers "$testRoot/identity-missing.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "missing identity must be rejected"
fi
rg -q 'no codesigning identity matches' "$testRoot/identity-missing.log" || fail "missing-identity message incorrect"

if NOTARY_TEST_IDENTITY_MODE=ambiguous run_contract_helpers "$testRoot/identity-ambiguous.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "ambiguous identity must be rejected"
fi
rg -q 'ambiguous' "$testRoot/identity-ambiguous.log" || fail "ambiguous-identity message incorrect"

# --- notarized app validation success + failures ---
NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/notarized-ok.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"' \
  || fail "valid notarized app validation failed"

if NOTARY_TEST_CODESIGN_MODE=wrong-team NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/wrong-team.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-wrong.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "wrong Team ID must be rejected"
fi
rg -q 'does not match requested Team ID' "$testRoot/wrong-team.log" || fail "wrong-team message incorrect"

if NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=reject NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/spctl-reject.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-spctl.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "Gatekeeper rejection must fail validation"
fi
rg -q 'Gatekeeper assessment failed' "$testRoot/spctl-reject.log" || fail "spctl failure message incorrect"

if NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=missing \
  run_contract_helpers "$testRoot/ticket-missing.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-ticket.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "missing notarization ticket must fail validation"
fi
rg -q 'ticket validation failed|stapler' "$testRoot/ticket-missing.log" || fail "missing-ticket message incorrect"

if NOTARY_TEST_CODESIGN_MODE=adhoc NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/adhoc.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-adhoc.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456"'; then
  fail "ad-hoc signature must be rejected for notarized path"
fi
rg -q 'ad-hoc' "$testRoot/adhoc.log" || fail "ad-hoc rejection message incorrect"

# --- secret redaction helper path (inline recreation of packager redaction) ---
cat >"$testRoot/state/leaky-notary.log" <<'EOF'
status: Invalid
auth header Bearer super-secret-token-value
password=hunter2
EOF
cat >"$testRoot/state/clean-notary.log" <<'EOF'
status: Invalid
The signature does not include a secure timestamp.
EOF
redact_check() {
  local detailsFile="$1"
  local releaseCredentialPattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'
  if rg -n -- "$releaseCredentialPattern|password|passwd|api[_-]?key|issuer|BEGIN [A-Z ]*PRIVATE KEY" "$detailsFile" >/dev/null 2>&1; then
    echo "SUPPRESSED"
  else
    sed -n '1,200p' "$detailsFile"
  fi
}
[[ "$(redact_check "$testRoot/state/leaky-notary.log")" == "SUPPRESSED" ]] || fail "secret-bearing notarization log was not suppressed"
redact_check "$testRoot/state/clean-notary.log" | rg -q 'secure timestamp' || fail "clean notarization diagnostics should still be shown"

# Rejected notarization wording must exist in the packager.
require_text scripts/package_notarized_release.sh 'Apple rejected notarization'
require_text scripts/package_notarized_release.sh 'diagnostics suppressed because they may contain secrets'

# Workflow safety contracts when present.
if [[ -f .github/workflows/release.yml ]]; then
  require_text .github/workflows/release.yml 'workflow_dispatch'
  require_text .github/workflows/release.yml 'distribution_mode'
  require_text .github/workflows/release.yml 'unsigned'
  require_text .github/workflows/release.yml 'notarized'
  require_text .github/workflows/release.yml 'create_github_release'
  require_text .github/workflows/release.yml 'contents:'
  require_text .github/workflows/release.yml 'package_notarized_release.sh'
  # Must not hardcode private key PEM material or p12 blobs.
  if rg -n -- '-----BEGIN|MI[I|L][A-Za-z0-9+/]{40,}' .github/workflows/release.yml; then
    fail "release workflow appears to hardcode credential material"
  fi
  # Silent fallback from notarized to unsigned is forbidden.
  if rg -n -i 'fallback|else.*unsigned|notarized.*\|\|.*unsigned' .github/workflows/release.yml >/dev/null; then
    # Allow documentation comments only if they say "never" / "no fallback".
    if ! rg -n -i 'never silently|no silent fallback|does not fall back' .github/workflows/release.yml >/dev/null; then
      fail "release workflow must not implement silent unsigned fallback"
    fi
  fi
fi

echo "notarized-release check passed"
