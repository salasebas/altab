#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd -P "$(dirname "$0")/.." && pwd -P)"
setupScript="$repoRoot/scripts/codesign/setup_local.sh"
removeScript="$repoRoot/scripts/codesign/remove_local.sh"
testRoot="$(mktemp -d "${TMPDIR:-/tmp}/altab-codesign-check.XXXXXX")"
testRoot="$(cd -P "$testRoot" && pwd -P)"
baselineStatus="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"
privateKeyCanary="PRIVATE_KEY_CANARY_ISSUE_16"
certificateCanary="CERTIFICATE_CANARY_ISSUE_16"

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
  echo "local-codesign check failed: $1" >&2
  exit 1
}

require_contains() {
  local path="$1"
  local expected="$2"
  rg -q -F -- "$expected" "$path" || fail "$path does not contain: $expected"
}

require_absent() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "$path was not removed"
}

write_mock_tools() {
  mkdir -p "$testRoot/bin" "$testRoot/state"
  cat >"$testRoot/bin/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 && "$1" == "-d" ]] || { echo "unexpected mktemp arguments" >&2; exit 97; }
case "$2" in
  "${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.XXXXXX") materialRoot="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock" ;;
  "${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign-remove.XXXXXX") materialRoot="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign-remove.mock" ;;
  *) echo "unexpected mktemp template" >&2; exit 98 ;;
esac
mkdir -p "$materialRoot"
printf '%s\n' "$materialRoot" >"${LOCAL_CODESIGN_TEST_ROOT:?}/state/material-path"
printf '%s\n' "$materialRoot"
EOF
  cat >"$testRoot/bin/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 && "$1" == "-rf" && "$2" == "--" ]] || { echo "unexpected rm arguments" >&2; exit 117; }
case "$3" in
  "${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock"|"${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign-remove.mock") ;;
  *) echo "refusing unsafe mock removal target" >&2; exit 118 ;;
esac
if [[ "${LOCAL_CODESIGN_TEST_MODE:-}" == "cleanup-denied" && "$3" == *"altab-local-codesign.mock" ]] || [[ "${LOCAL_CODESIGN_TEST_MODE:-}" == "removal-cleanup-denied" && "$3" == *"altab-local-codesign-remove.mock" ]]; then
  echo "mock cleanup denial" >&2
  exit 88
fi
exec /bin/rm "$@"
EOF
  cat >"$testRoot/bin/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
stateRoot="${LOCAL_CODESIGN_TEST_ROOT:?}/state"
printf '%s\n' "$*" >>"$stateRoot/openssl.log"
[[ "${1:-}" != "rand" ]] || { echo "setup generated a password" >&2; exit 91; }
case "${1:-}" in
  genrsa)
    expectedKey="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock/codesign.key"
    [[ $# -eq 4 && "$2" == "-out" && "$3" == "$expectedKey" && "$4" == "2048" ]] || { echo "unexpected genrsa arguments" >&2; exit 119; }
    printf '%s\n' "PRIVATE_KEY_CANARY_ISSUE_16" >"$expectedKey"
    ;;
  req)
    certificatePrefix="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock/codesign"
    [[ $# -eq 15 && "$2" == "-x509" && "$3" == "-new" && "$4" == "-config" && "$5" == "$certificatePrefix.conf" && "$6" == "-nodes" && "$7" == "-key" && "$8" == "$certificatePrefix.key" && "$9" == "-extensions" && "${10}" == "extensions" && "${11}" == "-sha256" && "${12}" == "-days" && "${13}" == "3650" && "${14}" == "-out" && "${15}" == "$certificatePrefix.crt" ]] || { echo "unexpected certificate request arguments" >&2; exit 120; }
    grep -Fq 'CN = Local Self-Signed' "$certificatePrefix.conf" || { echo "certificate common name is missing" >&2; exit 121; }
    grep -Fq 'extendedKeyUsage=critical,1.3.6.1.5.5.7.3.3' "$certificatePrefix.conf" || { echo "code-signing EKU is missing" >&2; exit 122; }
    grep -Fq '1.2.840.113635.100.6.1.14=critical,DER:0500' "$certificatePrefix.conf" || { echo "Apple code-signing extension is missing" >&2; exit 123; }
    printf '%s\n' "CERTIFICATE_CANARY_ISSUE_16" >"$certificatePrefix.crt"
    ;;
  x509)
    [[ $# -eq 6 && "$2" == "-in" && "$4" == "-noout" && "$5" == "-fingerprint" ]] || { echo "unexpected x509 arguments" >&2; exit 124; }
    case "$3" in
      "${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock/codesign.crt"|"${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign-remove.mock/certificate.pem") ;;
      *) echo "unexpected x509 input" >&2; exit 125 ;;
    esac
    if [[ "$6" == "-sha256" ]]; then
      if [[ "$3" == *"altab-local-codesign-remove.mock/certificate.pem" && -f "$stateRoot/export-near-certificate" ]]; then
        echo "sha256 Fingerprint=CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC:CC"
      else
        echo "sha256 Fingerprint=BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB"
      fi
    elif [[ "$6" == "-sha1" ]]; then
      echo "sha1 Fingerprint=AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA"
    else
      echo "unexpected fingerprint algorithm" >&2
      exit 126
    fi
    ;;
  *) echo "unexpected openssl command" >&2; exit 127 ;;
esac
EOF
  cat >"$testRoot/bin/security" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
stateRoot="${LOCAL_CODESIGN_TEST_ROOT:?}/state"
mode="${LOCAL_CODESIGN_TEST_MODE:-success}"
commandName="${1:-}"
shift || true
{
  printf '%s' "$commandName"
  printf '\t%s' "$@"
  printf '\n'
} >>"$stateRoot/security.log"
require_explanation() {
  grep -Fq 'This optional setup will add' "${LOCAL_CODESIGN_TEST_OUTPUT:?}" || { echo "setup did not explain the change first" >&2; exit 96; }
}
case "$commandName" in
  default-keychain)
    [[ $# -eq 2 && "$1" == "-d" && "$2" == "user" ]] || { echo "unexpected default-keychain arguments" >&2; exit 105; }
    echo "\"${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db\""
    ;;
  list-keychains)
    [[ $# -eq 2 && "$1" == "-d" && "$2" == "user" ]] || { echo "unexpected list-keychains arguments" >&2; exit 115; }
    if [[ "$mode" == "unsearchable-default" ]]; then
      echo "\"${LOCAL_CODESIGN_TEST_ROOT:?}/other.keychain-db\""
    else
      echo "\"${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db\""
    fi
    ;;
  find-identity)
    identityIsVerbose=false
    identityHasExplicitKeychain=false
    if [[ $# -eq 3 && "$1" == "-v" && "$2" == "-p" && "$3" == "codesigning" ]]; then
      identityIsVerbose=true
    elif [[ $# -eq 2 && "$1" == "-p" && "$2" == "codesigning" ]]; then
      :
    elif [[ $# -eq 4 && "$1" == "-v" && "$2" == "-p" && "$3" == "codesigning" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]]; then
      identityIsVerbose=true
      identityHasExplicitKeychain=true
    elif [[ $# -eq 3 && "$1" == "-p" && "$2" == "codesigning" && "$3" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]]; then
      identityHasExplicitKeychain=true
    else
      echo "unexpected find-identity arguments" >&2
      exit 106
    fi
    identityVisible=true
    if [[ "$mode" == "unsearchable-removal" && "$identityHasExplicitKeychain" != true ]]; then
      identityVisible=false
    fi
    if [[ "$identityVisible" == true && "$identityIsVerbose" == true && -f "$stateRoot/valid-identity" ]] || [[ "$identityVisible" == true && "$identityIsVerbose" != true && -f "$stateRoot/private-key" && -f "$stateRoot/certificate" ]]; then
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Local Self-Signed"'
      echo '     1 valid identities found'
    elif [[ "$identityVisible" == true && -f "$stateRoot/substring-identity" ]]; then
      echo '  1) DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD "Company Local Self-Signed Development"'
      echo '     1 valid identities found'
    else
      echo '     0 valid identities found'
    fi
    ;;
  import)
    require_explanation
    expectedPem="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock/codesign.pem"
    expectedKeychain="${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db"
    [[ $# -eq 10 && "$1" == "$expectedPem" && "$2" == "-k" && "$3" == "$expectedKeychain" && "$4" == "-t" && "$5" == "agg" && "$6" == "-f" && "$7" == "pemseq" && "$8" == "-x" && "$9" == "-T" && "${10}" == "/usr/bin/codesign" ]] || { echo "unexpected import arguments" >&2; exit 99; }
    grep -Fq 'PRIVATE_KEY_CANARY_ISSUE_16' "$expectedPem" || { echo "PEM does not contain the private key" >&2; exit 107; }
    grep -Fq 'CERTIFICATE_CANARY_ISSUE_16' "$expectedPem" || { echo "PEM does not contain the certificate" >&2; exit 108; }
    certificateLine="$(rg -n -F 'CERTIFICATE_CANARY_ISSUE_16' "$expectedPem" | cut -d: -f1)"
    privateKeyLine="$(rg -n -F 'PRIVATE_KEY_CANARY_ISSUE_16' "$expectedPem" | cut -d: -f1)"
    [[ "$certificateLine" -lt "$privateKeyLine" ]] || { echo "PEM does not place the certificate before the private key" >&2; exit 116; }
    [[ "$(stat -f '%Lp' "$(dirname "$expectedPem")")" == "700" ]] || { echo "temporary directory is not private" >&2; exit 109; }
    [[ "$(stat -f '%Lp' "$expectedPem")" == "600" ]] || { echo "PEM is not private" >&2; exit 110; }
    [[ "$(stat -f '%Lp' "${expectedPem%.pem}.key")" == "600" ]] || { echo "private key is not private" >&2; exit 111; }
    touch "$stateRoot/imported" "$stateRoot/certificate"
    [[ "$mode" != "partial-import" ]] || { echo "partial import failure" >&2; exit 78; }
    if [[ "$mode" == "partial-private-key" ]]; then
      /bin/rm -f "$stateRoot/certificate"
      touch "$stateRoot/private-key"
      echo "private-key-only import failure" >&2
      exit 79
    fi
    touch "$stateRoot/private-key"
    ;;
  find-certificate)
    certificateHasExplicitKeychain=false
    certificateIsExport=false
    if [[ $# -eq 4 && "$1" == "-a" && "$2" == "-c" && "$3" == "Local Self-Signed" && "$4" == "-Z" ]]; then
      :
    elif [[ $# -eq 5 && "$1" == "-a" && "$2" == "-c" && "$3" == "Local Self-Signed" && "$4" == "-Z" && "$5" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]]; then
      certificateHasExplicitKeychain=true
    elif [[ $# -eq 3 && "$1" == "-c" && "$2" == "Local Self-Signed" && "$3" == "-p" ]]; then
      certificateIsExport=true
    elif [[ $# -eq 4 && "$1" == "-c" && "$2" == "Local Self-Signed" && "$3" == "-p" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]]; then
      certificateIsExport=true
      certificateHasExplicitKeychain=true
    else
      echo "unexpected find-certificate arguments" >&2
      exit 112
    fi
    certificateVisible=true
    if [[ "$mode" == "unsearchable-removal" && "$certificateHasExplicitKeychain" != true ]]; then
      certificateVisible=false
    fi
    if [[ "$certificateVisible" == true && ( -f "$stateRoot/certificate" || -f "$stateRoot/substring-certificate" ) ]]; then
      if [[ "$certificateIsExport" == true ]]; then
        echo '-----BEGIN CERTIFICATE-----'
        echo 'mock-certificate'
        echo '-----END CERTIFICATE-----'
      else
        if [[ -f "$stateRoot/certificate" ]]; then
          echo 'SHA-256 hash: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
          echo '    "alis"<blob>="Local Self-Signed"'
        fi
        if [[ -f "$stateRoot/duplicate-certificate" ]]; then
          echo 'SHA-256 hash: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
          echo '    "alis"<blob>="Local Self-Signed"'
        fi
        if [[ -f "$stateRoot/substring-certificate" ]]; then
          echo 'SHA-256 hash: CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
          echo '    "alis"<blob>="Company Local Self-Signed Development"'
        fi
      fi
    fi
    ;;
  add-trusted-cert)
    require_explanation
    expectedCertificate="${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign.mock/codesign.crt"
    expectedKeychain="${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db"
    [[ $# -eq 7 && "$1" == "-r" && "$2" == "trustRoot" && "$3" == "-p" && "$4" == "codeSign" && "$5" == "-k" && "$6" == "$expectedKeychain" && "$7" == "$expectedCertificate" ]] || { echo "unexpected trust arguments" >&2; exit 113; }
    case "$mode" in
      denied) echo "User interaction is not allowed" >&2; exit 77 ;;
      interrupted)
        setupPid="$(<"${LOCAL_CODESIGN_TEST_SETUP_PID_FILE:?}")"
        trap 'touch "$stateRoot/security-child-terminated"; exit 143' TERM
        kill -TERM "$setupPid"
        while true; do sleep 1; done
        ;;
      rollback-denied) echo "User interaction is not allowed" >&2; exit 77 ;;
      unverifiable) ;;
      *) touch "$stateRoot/valid-identity" ;;
    esac
    ;;
  delete-identity)
    if [[ -n "${LOCAL_CODESIGN_TEST_OUTPUT:-}" ]]; then
      [[ $# -eq 4 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]] || { echo "unexpected confined rollback arguments" >&2; exit 100; }
    elif [[ "$mode" == "unsearchable-removal" ]]; then
      [[ $# -eq 4 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]] || { echo "unexpected unsearchable removal arguments" >&2; exit 100; }
    else
      [[ $# -eq 3 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" ]] || { echo "unexpected removal arguments" >&2; exit 100; }
    fi
    [[ "$mode" != "rollback-denied" ]] || { echo "User interaction is not allowed" >&2; exit 77; }
    /bin/rm -f "$stateRoot/private-key" "$stateRoot/certificate" "$stateRoot/valid-identity"
    ;;
  delete-certificate)
    if [[ -n "${LOCAL_CODESIGN_TEST_OUTPUT:-}" ]]; then
      [[ $# -eq 4 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]] || { echo "unexpected confined certificate rollback arguments" >&2; exit 103; }
    elif [[ "$mode" == "unsearchable-removal" ]]; then
      [[ $# -eq 4 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" && "$4" == "${LOCAL_CODESIGN_TEST_ROOT:?}/login.keychain-db" ]] || { echo "unexpected unsearchable certificate removal arguments" >&2; exit 103; }
    else
      [[ $# -eq 3 && "$1" == "-Z" && "$2" == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" && "$3" == "-t" ]] || { echo "unexpected certificate removal arguments" >&2; exit 103; }
    fi
    [[ "$mode" != "rollback-denied" ]] || { echo "User interaction is not allowed" >&2; exit 77; }
    /bin/rm -f "$stateRoot/certificate" "$stateRoot/valid-identity"
    ;;
  remove-trusted-cert)
    [[ $# -eq 2 && "$1" == "-d" && "$2" == "${LOCAL_CODESIGN_TEST_ROOT:?}/altab-local-codesign-remove.mock/certificate.pem" ]] || { echo "unexpected remove-trusted-cert arguments" >&2; exit 114; }
    if [[ "$mode" == "removal-interrupted" ]]; then
      removalPid="$(<"${LOCAL_CODESIGN_TEST_REMOVE_PID_FILE:?}")"
      kill -TERM "$removalPid"
      sleep 1
      exit 143
    fi
    touch "$stateRoot/admin-trust-removed"
    /bin/rm -f "$stateRoot/duplicate-certificate"
    ;;
  *) echo "unexpected security command: $commandName" >&2; exit 95 ;;
esac
EOF
  cat >"$testRoot/bin/run-setup" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$$" >"${LOCAL_CODESIGN_TEST_SETUP_PID_FILE:?}"
exec bash "$1"
EOF
  cat >"$testRoot/bin/run-removal" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$$" >"${LOCAL_CODESIGN_TEST_REMOVE_PID_FILE:?}"
exec bash "$@"
EOF
  chmod +x "$testRoot/bin/mktemp" "$testRoot/bin/rm" "$testRoot/bin/openssl" "$testRoot/bin/security" "$testRoot/bin/run-setup" "$testRoot/bin/run-removal"
}

reset_state() {
  rm -rf -- "$testRoot/state" "$testRoot/altab-local-codesign.mock" "$testRoot/altab-local-codesign-remove.mock"
  mkdir -p "$testRoot/state"
}

run_setup() {
  local mode="$1"
  local output="$2"
  local input="${3:-y}"
  local temporaryRoot="${4:-$testRoot}"
  printf '%s\n' "$input" | env LOCAL_CODESIGN_TEST_MODE="$mode" LOCAL_CODESIGN_TEST_OUTPUT="$output" LOCAL_CODESIGN_TEST_ROOT="$testRoot" LOCAL_CODESIGN_TEST_SETUP_PID_FILE="$testRoot/state/setup-pid" PATH="$testRoot/bin:$PATH" TMPDIR="$temporaryRoot" "$testRoot/bin/run-setup" "$setupScript" >"$output" 2>&1
}

run_removal() {
  local mode="$1"
  local output="$2"
  shift 2
  printf 'y\n' | env LOCAL_CODESIGN_TEST_MODE="$mode" LOCAL_CODESIGN_TEST_ROOT="$testRoot" LOCAL_CODESIGN_TEST_REMOVE_PID_FILE="$testRoot/state/removal-pid" PATH="$testRoot/bin:$PATH" TMPDIR="$testRoot" "$testRoot/bin/run-removal" "$removeScript" "$@" >"$output" 2>&1
}

assert_material_removed() {
  local materialPath
  materialPath="$(<"$testRoot/state/material-path")"
  require_absent "$materialPath"
}

assert_output_sanitized() {
  local output="$1"
  ! rg -q -F -- "$privateKeyCanary" "$output" || fail "$output printed private key content"
  ! rg -q -F -- "$certificateCanary" "$output" || fail "$output printed certificate content"
  ! rg -q 'codesign\.(conf|key|crt|pem|p12)' "$output" || fail "$output printed a certificate material path"
  if [[ -e "$testRoot/state/material-path" ]]; then
    local materialPath
    materialPath="$(<"$testRoot/state/material-path")"
    ! rg -q -F -- "$materialPath" "$output" || fail "$output printed its temporary material path"
  fi
}

check_success_and_idempotency() {
  reset_state
  local output="$testRoot/success.log"
  run_setup success "$output" || fail "setup did not succeed"
  [[ -f "$testRoot/state/private-key" && -f "$testRoot/state/certificate" ]] || fail "setup did not create the identity"
  [[ -f "$testRoot/state/valid-identity" ]] || fail "setup did not validate the identity"
  [[ -f "$testRoot/state/imported" ]] || fail "setup did not import the identity"
  assert_material_removed
  assert_output_sanitized "$output"
  require_contains "$output" "installed and verified"
  local materialPath
  materialPath="$(<"$testRoot/state/material-path")"
  ! rg -q -F "$materialPath" "$output" || fail "temporary material path was printed"
  rm -f "$testRoot/state/material-path" "$testRoot/state/openssl.log" "$testRoot/state/imported"
  : >"$testRoot/state/security.log"
  env LOCAL_CODESIGN_TEST_MODE=success LOCAL_CODESIGN_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" TMPDIR="$testRoot" bash "$setupScript" </dev/null >"$testRoot/idempotent.log" 2>&1 || fail "idempotent setup did not succeed"
  [[ ! -e "$testRoot/state/material-path" ]] || fail "idempotent setup created temporary material"
  [[ ! -e "$testRoot/state/openssl.log" ]] || fail "idempotent setup regenerated the identity"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "idempotent setup mutated the Keychain"
  require_contains "$testRoot/idempotent.log" "already installed"
  assert_output_sanitized "$testRoot/idempotent.log"
  touch "$testRoot/state/duplicate-certificate"
  : >"$testRoot/state/security.log"
  env LOCAL_CODESIGN_TEST_MODE=success LOCAL_CODESIGN_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" TMPDIR="$testRoot" bash "$setupScript" </dev/null >"$testRoot/legacy-idempotent.log" 2>&1 || fail "setup did not reuse a legacy identity duplicated by administrative trust"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "legacy idempotent setup mutated the Keychain"
  require_contains "$testRoot/legacy-idempotent.log" "already installed"
  assert_output_sanitized "$testRoot/legacy-idempotent.log"
}

check_denied_cleanup() {
  reset_state
  local output="$testRoot/denied.log"
  if run_setup denied "$output"; then
    fail "setup succeeded after trust authorization was denied"
  fi
  assert_material_removed
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "denied setup left a partial identity"
  require_contains "$output" "Keychain or trust update was denied"
  assert_output_sanitized "$output"
}

check_partial_import_cleanup() {
  reset_state
  local output="$testRoot/partial-import.log"
  if run_setup partial-import "$output"; then
    fail "setup succeeded after a partial import failure"
  fi
  assert_material_removed
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "partial import failure left a Keychain item"
  require_contains "$output" "Keychain or trust update was denied"
  assert_output_sanitized "$output"
}

check_private_key_only_warning() {
  reset_state
  local output="$testRoot/partial-private-key.log"
  if run_setup partial-private-key "$output"; then
    fail "setup succeeded after a private-key-only import failure"
  fi
  assert_material_removed
  [[ -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "private-key-only scenario did not model an orphan key"
  require_contains "$output" "absence could not be proven"
  require_contains "$output" "inspect Local Self-Signed items in Keychain Access"
  assert_output_sanitized "$output"
}

check_interrupted_cleanup() {
  reset_state
  local output="$testRoot/interrupted.log"
  local exitStatus=0
  run_setup interrupted "$output" || exitStatus=$?
  if [[ "$exitStatus" -eq 0 ]]; then
    fail "setup succeeded after interruption"
  fi
  [[ "$exitStatus" -eq 143 ]] || fail "interrupted setup exited with $exitStatus instead of 143"
  [[ -f "$testRoot/state/security-child-terminated" ]] || fail "interrupted setup did not terminate the active security process"
  assert_material_removed
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "interrupted setup left a partial identity"
  assert_output_sanitized "$output"
}

check_verification_failure() {
  reset_state
  local output="$testRoot/unverifiable.log"
  if run_setup unverifiable "$output"; then
    fail "setup succeeded without a verifiable identity"
  fi
  assert_material_removed
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "unverifiable setup left a partial identity"
  require_contains "$output" "could not be verified"
  assert_output_sanitized "$output"
}

check_failed_rollback_warning() {
  reset_state
  local output="$testRoot/rollback-denied.log"
  if run_setup rollback-denied "$output"; then
    fail "setup succeeded after trust and rollback were denied"
  fi
  assert_material_removed
  [[ -e "$testRoot/state/private-key" && -e "$testRoot/state/certificate" ]] || fail "rollback-denied scenario did not preserve its partial identity"
  require_contains "$output" "partial identity could not be rolled back"
  require_contains "$output" "remove_local.sh before retrying"
  require_contains "$output" "Exact certificate hash: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
  assert_output_sanitized "$output"
}

check_cleanup_failure() {
  reset_state
  local output="$testRoot/cleanup-denied.log"
  if run_setup cleanup-denied "$output"; then
    fail "setup reported success after temporary cleanup failed"
  fi
  [[ -d "$testRoot/altab-local-codesign.mock" ]] || fail "cleanup-denied scenario did not preserve its temporary material"
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "cleanup-denied scenario did not roll back its identity"
  require_contains "$output" "temporary certificate material could not be removed"
  assert_output_sanitized "$output"
  /bin/rm -rf -- "$testRoot/altab-local-codesign.mock"
}

check_cancellation_and_temp_root() {
  reset_state
  run_setup success "$testRoot/cancelled.log" n || fail "cancelled setup did not exit cleanly"
  [[ ! -e "$testRoot/state/material-path" ]] || fail "cancelled setup created temporary material"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "cancelled setup mutated the Keychain"
  require_contains "$testRoot/cancelled.log" "Setup cancelled"
  reset_state
  if run_setup success "$testRoot/repository-temp.log" y "$repoRoot"; then
    fail "setup accepted a temporary root inside the repository"
  fi
  [[ ! -e "$testRoot/state/material-path" ]] || fail "rejected temporary root created material"
  require_contains "$testRoot/repository-temp.log" "TMPDIR must point outside the repository checkout"
  reset_state
  ln -s "$repoRoot" "$testRoot/repository-link"
  if run_setup success "$testRoot/repository-symlink-temp.log" y "$testRoot/repository-link"; then
    fail "setup accepted a temporary root symlinked into the repository"
  fi
  [[ ! -e "$testRoot/state/material-path" ]] || fail "rejected symlinked temporary root created material"
  require_contains "$testRoot/repository-symlink-temp.log" "TMPDIR must point outside the repository checkout"
  /bin/rm -f "$testRoot/repository-link"
  reset_state
  touch "$testRoot/state/substring-certificate"
  run_setup success "$testRoot/near-name-cancelled.log" n || fail "a near-name certificate blocked setup"
  require_contains "$testRoot/near-name-cancelled.log" "Setup cancelled"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "near-name cancellation mutated the Keychain"
  reset_state
  touch "$testRoot/state/substring-identity"
  run_setup success "$testRoot/near-identity-cancelled.log" n || fail "a near-name identity blocked setup"
  require_contains "$testRoot/near-identity-cancelled.log" "Setup cancelled"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "near-name identity cancellation mutated the Keychain"
  reset_state
  if run_setup unsearchable-default "$testRoot/unsearchable-default.log" n; then
    fail "setup accepted a default Keychain outside the user search list"
  fi
  require_contains "$testRoot/unsearchable-default.log" "default user Keychain is not in the user search list"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "unsearchable default Keychain triggered a mutation"
  reset_state
  touch "$testRoot/state/certificate"
  if run_setup success "$testRoot/certificate-only-setup.log" n; then
    fail "setup accepted an incomplete certificate-only installation"
  fi
  require_contains "$testRoot/certificate-only-setup.log" "incomplete or invalid"
  ! rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log" || fail "certificate-only setup check mutated the Keychain"
}

check_removal() {
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate"
  local output="$testRoot/removal.log"
  run_removal success "$output" || fail "removal did not succeed"
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "removal left the identity installed"
  require_contains "$testRoot/state/security.log" $'delete-identity\t-Z\tBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\t-t'
  require_contains "$output" "removed"
  assert_output_sanitized "$output"
  rm -f "$testRoot/state/security.log"
  env LOCAL_CODESIGN_TEST_MODE=success LOCAL_CODESIGN_TEST_ROOT="$testRoot" PATH="$testRoot/bin:$PATH" bash "$removeScript" </dev/null >"$testRoot/removal-idempotent.log" 2>&1 || fail "idempotent removal did not succeed"
  require_contains "$testRoot/removal-idempotent.log" "is not installed"
  if [[ -e "$testRoot/state/security.log" ]] && rg -q '^(import|add-trusted-cert|delete-|remove-trusted-cert)' "$testRoot/state/security.log"; then
    fail "idempotent removal mutated the Keychain"
  fi
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate" "$testRoot/state/duplicate-certificate"
  run_removal success "$testRoot/legacy-removal.log" --include-legacy-admin-trust || fail "legacy removal did not succeed"
  [[ -f "$testRoot/state/admin-trust-removed" ]] || fail "legacy administrative trust was not removed"
  assert_material_removed
  assert_output_sanitized "$testRoot/legacy-removal.log"
  reset_state
  touch "$testRoot/state/substring-certificate"
  run_removal success "$testRoot/certificate-collision.log" || fail "removal did not safely ignore a near-name certificate"
  ! rg -q '^delete-' "$testRoot/state/security.log" || fail "certificate-only collision triggered deletion"
  require_contains "$testRoot/certificate-collision.log" "is not installed"
  reset_state
  touch "$testRoot/state/certificate"
  run_removal success "$testRoot/certificate-only.log" || fail "certificate-only removal did not succeed"
  [[ ! -e "$testRoot/state/certificate" ]] || fail "certificate-only removal left the certificate installed"
  require_contains "$testRoot/state/security.log" $'delete-certificate\t-Z\tBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\t-t'
  assert_output_sanitized "$testRoot/certificate-only.log"
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate"
  run_removal unsearchable-removal "$testRoot/unsearchable-removal.log" || fail "removal did not find the identity in an unlisted default Keychain"
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "unsearchable removal left the identity installed"
  require_contains "$testRoot/state/security.log" $'delete-identity\t-Z\tBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\t-t\t'"$testRoot/login.keychain-db"
  assert_output_sanitized "$testRoot/unsearchable-removal.log"
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate"
  run_removal unsearchable-removal "$testRoot/unsearchable-legacy-removal.log" --include-legacy-admin-trust || fail "legacy removal did not export from an unlisted default Keychain"
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "unsearchable legacy removal left the identity installed"
  require_contains "$testRoot/state/security.log" $'find-certificate\t-c\tLocal Self-Signed\t-p\t'"$testRoot/login.keychain-db"
  assert_output_sanitized "$testRoot/unsearchable-legacy-removal.log"
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate" "$testRoot/state/export-near-certificate"
  if run_removal success "$testRoot/legacy-near-name.log" --include-legacy-admin-trust; then
    fail "legacy removal accepted a near-name certificate export"
  fi
  [[ ! -e "$testRoot/state/admin-trust-removed" ]] || fail "legacy near-name collision removed administrative trust"
  ! rg -q '^delete-' "$testRoot/state/security.log" || fail "legacy near-name collision deleted a Keychain item"
  require_contains "$testRoot/legacy-near-name.log" "exact legacy certificate could not be selected safely"
  assert_material_removed
  assert_output_sanitized "$testRoot/legacy-near-name.log"
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate"
  local interruptedStatus=0
  run_removal removal-interrupted "$testRoot/removal-interrupted.log" --include-legacy-admin-trust || interruptedStatus=$?
  [[ "$interruptedStatus" -eq 143 ]] || fail "interrupted removal exited with $interruptedStatus instead of 143"
  [[ -e "$testRoot/state/private-key" && -e "$testRoot/state/certificate" ]] || fail "interrupted removal unexpectedly deleted the identity"
  assert_material_removed
  assert_output_sanitized "$testRoot/removal-interrupted.log"
  reset_state
  touch "$testRoot/state/private-key" "$testRoot/state/certificate"
  if run_removal removal-cleanup-denied "$testRoot/removal-cleanup-denied.log" --include-legacy-admin-trust; then
    fail "removal reported success after temporary cleanup failed"
  fi
  [[ -d "$testRoot/altab-local-codesign-remove.mock" ]] || fail "removal cleanup failure did not preserve its temporary material"
  [[ ! -e "$testRoot/state/private-key" && ! -e "$testRoot/state/certificate" ]] || fail "removal cleanup failure left the identity installed"
  require_contains "$testRoot/removal-cleanup-denied.log" "temporary certificate material could not be removed"
  assert_output_sanitized "$testRoot/removal-cleanup-denied.log"
  /bin/rm -rf -- "$testRoot/altab-local-codesign-remove.mock"
}

check_documentation_and_syntax() {
  require_contains "$repoRoot/docs/contributing.md" "scripts/codesign/remove_local.sh"
  require_contains "$repoRoot/docs/contributing.md" "--include-legacy-admin-trust"
  require_contains "$repoRoot/docs/contributing.md" "ad-hoc signing by default"
  require_contains "$repoRoot/docs/contributing.md" "CODE_SIGN_IDENTITY = Local Self-Signed"
  for extension in conf key crt pem p12; do
    require_absent "$repoRoot/codesign.$extension"
  done
  local artifactPaths
  artifactPaths="$(find "$repoRoot" -path "$repoRoot/DerivedData" -prune -o -type f \( -name '*.conf' -o -name '*.key' -o -name '*.crt' -o -name '*.pem' -o -name '*.p12' \) -print)"
  [[ -z "$artifactPaths" ]] || fail "certificate material exists inside the repository"
  bash -n "$repoRoot"/scripts/codesign/*.sh "$repoRoot/scripts/check_local_codesign_setup.sh"
  local currentStatus
  currentStatus="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"
  [[ "$currentStatus" == "$baselineStatus" ]] || fail "the check changed the repository worktree"
}

write_mock_tools
check_success_and_idempotency
check_denied_cleanup
check_partial_import_cleanup
check_private_key_only_warning
check_interrupted_cleanup
check_verification_failure
check_failed_rollback_warning
check_cleanup_failure
check_cancellation_and_temp_root
check_removal
check_documentation_and_syntax
echo "local-codesign check passed"
