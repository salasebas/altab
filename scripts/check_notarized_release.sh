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
  scripts/publish_release_artifacts.sh \
  scripts/check_notarized_release.sh \
  scripts/release_artifact_contracts.sh \
  scripts/verify_release_artifacts.sh \
  .github/RELEASE_NOTES_NOTARIZED_TEMPLATE.md \
  docs/releasing.md; do
  require_file "$path"
done
require_executable scripts/package_notarized_release.sh
require_executable scripts/publish_release_artifacts.sh
require_executable scripts/check_notarized_release.sh
require_executable scripts/verify_release_artifacts.sh
bash -n scripts/release_artifact_contracts.sh
source scripts/release_artifact_contracts.sh
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "unsupported release artifact contracts version"

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
  'release_require_accepted_notarization' \
  'stapler staple' \
  'verify_release_artifacts.sh' \
  'Developer ID Application' \
  'notarized and stapled' \
  'Unsigned rebuild command'; do
  require_text scripts/package_notarized_release.sh "$text"
done
unsignedRebuildBlock="$(sed -n '/^unsignedRebuildCommand=(/,/^)/p' scripts/package_notarized_release.sh)"
printf '%s\n' "$unsignedRebuildBlock" | rg -q -F '"PRODUCT_BUNDLE_IDENTIFIER=$bundleId"' || fail "unsigned rebuild command must preserve the distributor bundle ID"
require_text scripts/package_notarized_release.sh 'bundle ID is required'
if rg -n -F 'config/base.xcconfig' scripts/package_notarized_release.sh; then
  fail "notarized packager must not read release configuration from the invoking checkout"
fi
require_text scripts/release_artifact_contracts.sh 'release_validate_notarized_app'
require_text scripts/release_artifact_contracts.sh 'release_validate_developer_id_inputs'
require_text scripts/release_artifact_contracts.sh 'notarytool submit'
require_text scripts/package_notarized_release.sh 'never silently'
# Ensure passwords are not accepted as CLI flags.
if rg -n -- '--password|--apple-id-password|NOTARY_PASSWORD|APPLE_ID_PASSWORD' scripts/package_notarized_release.sh; then
  fail "notarized packager must not accept passwords as command arguments"
fi

if env -u ALTAB_BUNDLE_ID scripts/package_notarized_release.sh 0000000000000000000000000000000000000000 \
  --identity 'Developer ID Application: Example Distributor (ABCD123456)' \
  --team-id ABCD123456 \
  --notary-profile TestProfile >"$testRoot/missing-bundle-id.log" 2>&1; then
  fail "notarized packager must require an explicit bundle ID"
fi
rg -q 'bundle ID is required' "$testRoot/missing-bundle-id.log" || fail "missing bundle ID message is incorrect"

[[ "$(release_package_name test unsigned)" == "AlTab-test-macOS-unsigned" ]] || fail "unsigned package-name helper is incorrect"
[[ "$(release_package_name test notarized)" == "AlTab-test-macOS" ]] || fail "notarized package-name helper is incorrect"
[[ "$(release_detect_package_mode AlTab-test-macOS-unsigned.zip)" == "unsigned" ]] || fail "unsigned package-mode detection is incorrect"
[[ "$(release_detect_package_mode AlTab-test-macOS.zip)" == "notarized" ]] || fail "notarized package-mode detection is incorrect"
if (release_package_name test unknown) >"$testRoot/bad-package-mode.log" 2>&1; then fail "unknown package mode must fail"; fi
if (release_detect_package_mode unknown.zip) >"$testRoot/bad-package-name.log" 2>&1; then fail "unknown package filename must fail"; fi

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
    quoted)
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example "Quoted" Distributor (ABCD123456)"'
      echo '     1 valid identities found'
      ;;
    quoted-prefix)
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Victim (ABCD123456)" Extra Distributor (ZZZZZZZZZZ)"'
      echo '     1 valid identities found'
      ;;
    multiline)
      echo '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Victim (ABCD123456)"'
      echo 'injected continuation'
      echo '"'
      echo '     1 valid identities found'
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
architecture="native"
previous=""
for argument in "$@"; do
  if [[ "$previous" == "--architecture" ]]; then architecture="$argument"; fi
  previous="$argument"
done
if [[ -n "${NOTARY_TEST_STATE_ROOT:-}" ]]; then printf '%s\n' "$*" >>"$NOTARY_TEST_STATE_ROOT/codesign-args.log"; fi
if [[ " $* " == *" --verify "* ]]; then
  case "$mode" in
    valid|wrong-team|adhoc|no-runtime|malformed-runtime|prefixed-flags|wrong-x86-runtime|wrong-entitlements|wrong-x86-entitlements|missing-entitlements|invalid-entitlements|type-collision) exit 0 ;;
    verify-fail) echo "verify failed" >&2; exit 1 ;;
    *) exit 92 ;;
  esac
fi
emit_valid_entitlements() {
  cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><false/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
PLIST
}
emit_wrong_entitlements() {
  cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><false/>
<key>com.apple.security.cs.disable-library-validation</key><false/>
</dict></plist>
PLIST
}
if [[ " $* " == *" --display "* && " $* " == *" --entitlements - "* ]]; then
  case "$mode" in
    valid|wrong-team|no-runtime|malformed-runtime|prefixed-flags|wrong-x86-runtime|adhoc) emit_valid_entitlements ;;
    wrong-entitlements) emit_wrong_entitlements ;;
    wrong-x86-entitlements)
      if [[ "$architecture" == "x86_64" ]]; then emit_wrong_entitlements; else emit_valid_entitlements; fi
      ;;
    missing-entitlements) ;;
    invalid-entitlements) printf 'not a property list\n' ;;
    type-collision)
      cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>numeric</key><real>1</real></dict></plist>
PLIST
      ;;
    *) exit 92 ;;
  esac
  exit 0
fi
if [[ " $* " == *" --display "* ]]; then
  case "$mode" in
    valid|wrong-entitlements|wrong-x86-entitlements|missing-entitlements|invalid-entitlements|type-collision)
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
    no-runtime)
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
      echo "TeamIdentifier=ABCD123456" >&2
      ;;
    malformed-runtime)
      echo "CodeDirectory v=20500 size=100 flags=0x10000(runtime,,garbage) hashes=10+3 location=embedded" >&2
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
      echo "TeamIdentifier=ABCD123456" >&2
      ;;
    prefixed-flags)
      echo "CodeDirectory v=20500 size=100 bogusflags=0x10000(runtime) hashes=10+3 location=embedded" >&2
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
      echo "TeamIdentifier=ABCD123456" >&2
      ;;
    wrong-x86-runtime)
      if [[ "$architecture" == "x86_64" ]]; then
        echo "CodeDirectory v=20500 size=100 flags=0x10000(runtime,,garbage) hashes=10+3 location=embedded" >&2
      else
        echo "CodeDirectory v=20500 size=100 flags=0x10000(runtime) hashes=10+3 location=embedded" >&2
      fi
      echo "Authority=Developer ID Application: Example Distributor (ABCD123456)" >&2
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
if [[ "$1" == "notarytool" && "$2" == "submit" ]]; then
  printf '%s\n' "$*" >>"${NOTARY_TEST_STATE_ROOT:?}/notarytool-args.log"
  case "${NOTARY_TEST_NOTARY_MODE:-accepted}" in
    accepted) echo '{"status":"Accepted"}' ;;
    rejected) echo '{"status":"Rejected","password":"hunter2"}' ;;
    invalid) echo '{"status":"Invalid"}' ;;
    in-progress) echo '{"status":"In Progress","message":"Successfully received submission info"}' ;;
    missing-status) echo '{"message":"Accepted"}' ;;
    text-status) echo 'status: Accepted' ;;
    command-fail) echo 'network unavailable'; exit 1 ;;
    *) exit 95 ;;
  esac
  exit 0
fi
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
  cat >"$testRoot/bin/plutil" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${NOTARY_TEST_PLUTIL_MODE:-normal}" == "partial-fail" && "$1" == "-extract" ]]; then
  printf 'Accepted\n'
  exit 1
fi
exec /usr/bin/plutil "$@"
EOF
  cat >"$testRoot/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "ls-remote" && "$2" == "--tags" ]]; then
  [[ "${PUBLISH_TEST_REMOTE_TAG_MODE:-missing}" != "error" ]] || exit 96
  tagRef=""
  for argument in "$@"; do
    case "$argument" in refs/tags/*) [[ "$argument" == *'^{}' ]] || tagRef="$argument" ;; esac
  done
  if [[ -f "${PUBLISH_TEST_STATE_ROOT:?}/remote-tag-sha" ]]; then
    tagSha="$(<"$PUBLISH_TEST_STATE_ROOT/remote-tag-sha")"
  elif [[ "${PUBLISH_TEST_REMOTE_TAG_MODE:-missing}" == "present" ]]; then
    tagSha="${PUBLISH_TEST_REMOTE_TAG_SHA:?}"
  else
    exit 0
  fi
  printf '%s\t%s\n' "$tagSha" "$tagRef"
  exit 0
fi
exit 96
EOF
  cat >"$testRoot/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${PUBLISH_TEST_STATE_ROOT:?}/gh-args.log"
if [[ "$1" == "api" ]]; then
  sha=""
  for argument in "$@"; do case "$argument" in sha=*) sha="${argument#sha=}" ;; esac; done
  [[ "$sha" =~ ^[0-9a-fA-F]{40}$ ]] || exit 99
  printf '%s\n' "$sha" >"$PUBLISH_TEST_STATE_ROOT/remote-tag-sha"
  exit 0
fi
if [[ "$1" == "release" && "$2" == "view" ]]; then
  case "${PUBLISH_TEST_GH_MODE:-absent}" in
    absent) echo 'release not found' >&2; exit 1 ;;
    existing) echo '{"tagName":"preview"}'; exit 0 ;;
    error) echo 'network unavailable' >&2; exit 1 ;;
    *) exit 97 ;;
  esac
fi
if [[ "$1" == "release" && ( "$2" == "create" || "$2" == "upload" ) ]]; then
  exit 0
fi
exit 98
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
cat >"$testRoot/expected.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.cs.disable-library-validation</key><true/>
<key>com.apple.security.app-sandbox</key><false/>
</dict></plist>
EOF
plutil -lint "$testRoot/expected.entitlements" >/dev/null || fail "test entitlements are invalid"

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

if NOTARY_TEST_IDENTITY_MODE=one-match run_contract_helpers "$testRoot/identity-partial.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example" "ABCD123456"'; then
  fail "partial identity must be rejected"
fi
rg -q 'no codesigning identity matches' "$testRoot/identity-partial.log" || fail "partial-identity message incorrect"

if NOTARY_TEST_IDENTITY_MODE=one-match run_contract_helpers "$testRoot/identity-wrong-team.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example Distributor (ABCD123456)" "ZZZZZZZZZZ"'; then
  fail "identity Team ID mismatch must be rejected before signing"
fi
rg -q 'does not match requested Team ID' "$testRoot/identity-wrong-team.log" || fail "identity Team ID mismatch message incorrect"

NOTARY_TEST_IDENTITY_MODE=quoted run_contract_helpers "$testRoot/identity-quoted.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Example \"Quoted\" Distributor (ABCD123456)" "ABCD123456"' \
  || fail "exact identity with embedded quotes was rejected"

if NOTARY_TEST_IDENTITY_MODE=quoted-prefix run_contract_helpers "$testRoot/identity-quoted-prefix.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Victim (ABCD123456)" "ABCD123456"'; then
  fail "identity parser must not accept a prefix before an embedded quote"
fi
rg -q 'no codesigning identity matches' "$testRoot/identity-quoted-prefix.log" || fail "quoted identity prefix message incorrect"

if NOTARY_TEST_IDENTITY_MODE=multiline run_contract_helpers "$testRoot/identity-multiline.log" \
  'release_resolve_codesigning_identity "Developer ID Application: Victim (ABCD123456)" "ABCD123456"'; then
  fail "multiline codesigning identity output must fail closed"
fi
rg -q 'could not safely parse codesigning identity output' "$testRoot/identity-multiline.log" || fail "multiline identity message incorrect"

# --- notarized app validation success + failures ---
: >"$testRoot/state/codesign-args.log"
NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/notarized-ok.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"' \
  || fail "valid notarized app validation failed"
require_text "$testRoot/state/codesign-args.log" '--architecture arm64'
require_text "$testRoot/state/codesign-args.log" '--architecture x86_64'

if NOTARY_TEST_CODESIGN_MODE=wrong-team NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/wrong-team.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-wrong.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "wrong Team ID must be rejected"
fi
rg -q 'does not match requested Team ID' "$testRoot/wrong-team.log" || fail "wrong-team message incorrect"

if NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=reject NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/spctl-reject.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-spctl.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "Gatekeeper rejection must fail validation"
fi
rg -q 'Gatekeeper assessment failed' "$testRoot/spctl-reject.log" || fail "spctl failure message incorrect"

if NOTARY_TEST_CODESIGN_MODE=valid NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=missing \
  run_contract_helpers "$testRoot/ticket-missing.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-ticket.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "missing notarization ticket must fail validation"
fi
rg -q 'ticket validation failed|stapler' "$testRoot/ticket-missing.log" || fail "missing-ticket message incorrect"

if NOTARY_TEST_CODESIGN_MODE=adhoc NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/adhoc.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-adhoc.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "ad-hoc signature must be rejected for notarized path"
fi
rg -q 'ad-hoc' "$testRoot/adhoc.log" || fail "ad-hoc rejection message incorrect"

if NOTARY_TEST_CODESIGN_MODE=no-runtime NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/no-runtime.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-no-runtime.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "missing Hardened Runtime flags must be rejected"
fi
rg -q 'missing CodeDirectory flags' "$testRoot/no-runtime.log" || fail "missing runtime-flags message incorrect"

if NOTARY_TEST_CODESIGN_MODE=malformed-runtime NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/malformed-runtime.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-malformed-runtime.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "malformed Hardened Runtime flags must be rejected"
fi
rg -q 'unparseable CodeDirectory flags' "$testRoot/malformed-runtime.log" || fail "malformed runtime-flags message incorrect"

if NOTARY_TEST_CODESIGN_MODE=prefixed-flags NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/prefixed-flags.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-prefixed-flags.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "prefixed CodeDirectory flags field must be rejected"
fi
rg -q 'unparseable CodeDirectory flags' "$testRoot/prefixed-flags.log" || fail "prefixed runtime-flags message incorrect"

if NOTARY_TEST_CODESIGN_MODE=wrong-x86-runtime NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/wrong-x86-runtime.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-wrong-x86-runtime.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "invalid x86_64 Hardened Runtime flags must be rejected"
fi
rg -q 'unparseable CodeDirectory flags' "$testRoot/wrong-x86-runtime.log" || fail "x86_64 runtime-flags message incorrect"

if NOTARY_TEST_CODESIGN_MODE=wrong-entitlements NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/wrong-entitlements.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-wrong-entitlements.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "unexpected signed entitlements must be rejected"
fi
rg -q 'signed entitlements do not match' "$testRoot/wrong-entitlements.log" || fail "entitlement-mismatch message incorrect"

if NOTARY_TEST_CODESIGN_MODE=wrong-x86-entitlements NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/wrong-x86-entitlements.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-wrong-x86-entitlements.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "unexpected x86_64 entitlements must be rejected"
fi
rg -q 'signed entitlements do not match' "$testRoot/wrong-x86-entitlements.log" || fail "x86_64 entitlement-mismatch message incorrect"

if NOTARY_TEST_CODESIGN_MODE=missing-entitlements NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/missing-entitlements.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-missing-entitlements.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "missing signed entitlements must be rejected"
fi
rg -q 'could not inspect signed entitlements|has no entitlements' "$testRoot/missing-entitlements.log" || fail "missing-entitlements message incorrect"

if NOTARY_TEST_CODESIGN_MODE=invalid-entitlements NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/invalid-entitlements.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-invalid-entitlements.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected.entitlements"'; then
  fail "invalid signed entitlements plist must be rejected"
fi
rg -q 'signed app entitlements are invalid' "$testRoot/invalid-entitlements.log" || fail "invalid-entitlements message incorrect"

cat >"$testRoot/expected-number.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>numeric</key><integer>1</integer></dict></plist>
EOF
if NOTARY_TEST_CODESIGN_MODE=type-collision NOTARY_TEST_SPCTL_MODE=accept NOTARY_TEST_STAPLER_MODE=ok \
  run_contract_helpers "$testRoot/type-collision.log" \
  'release_validate_notarized_app "'"$testRoot"'/app" "'"$testRoot"'/state/sig-type-collision.txt" "Developer ID Application: Example Distributor (ABCD123456)" "ABCD123456" "'"$testRoot"'/expected-number.entitlements"'; then
  fail "integer and real entitlement values must not compare equal"
fi
rg -q 'signed entitlements do not match' "$testRoot/type-collision.log" || fail "type-preserving entitlement message incorrect"

# --- notarization submission and secret redaction ---
cat >"$testRoot/state/leaky-notary.log" <<'EOF'
status: Invalid
Authorization: Bearer super-secret-token-value
EOF
cat >"$testRoot/state/clean-notary.log" <<'EOF'
status: Invalid
The signature does not include a secure timestamp.
EOF
redactedOutput="$(release_print_safe_diagnostics "$testRoot/state/leaky-notary.log" 2>&1)"
[[ "$redactedOutput" == *'diagnostics suppressed because they may contain secrets'* ]] || fail "secret-bearing notarization log was not suppressed"
[[ "$redactedOutput" != *'super-secret-token-value'* ]] || fail "Bearer token leaked through notarization diagnostics"
cleanOutput="$(release_print_safe_diagnostics "$testRoot/state/clean-notary.log" 2>&1)"
[[ "$cleanOutput" == *'secure timestamp'* ]] || fail "clean notarization diagnostics should still be shown"

: >"$testRoot/state/notarytool-args.log"
NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_NOTARY_MODE=accepted \
  run_contract_helpers "$testRoot/notary-accepted-result.log" \
  'release_submit_notarization "'"$testRoot"'/notary.zip" "'"$testRoot"'/state/notary-accepted.log" "TestProfile" "" "" ""' \
  || fail "Accepted notarization result was rejected"
require_text "$testRoot/state/notarytool-args.log" 'notarytool submit'
require_text "$testRoot/state/notarytool-args.log" '--wait --output-format json'

NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_NOTARY_MODE=accepted \
  run_contract_helpers "$testRoot/notary-errexit-result.log" \
  'set +e; release_submit_notarization "'"$testRoot"'/notary.zip" "'"$testRoot"'/state/notary-errexit.log" "TestProfile" "" "" ""; result=$?; [[ $- != *e* ]] || exit 88; exit "$result"' \
  || fail "notarization helper changed the caller errexit state"

if env PATH="$testRoot/bin:$PATH" NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_NOTARY_MODE=rejected \
  bash -c '
    set -euo pipefail
    fail() { echo "helper failed: $1" >&2; exit 1; }
    source scripts/release_artifact_contracts.sh
    workRoot="$1/rejected-work"
    published="$1/published"
    mkdir -p "$workRoot"
    trap '\''rm -rf "$workRoot"'\'' EXIT
    release_require_accepted_notarization "$1/notary.zip" "$workRoot/notary-rejected.log" "TestProfile" "" "" ""
    mkdir -p "$published"
  ' _ "$testRoot" >"$testRoot/notary-rejected-result.log" 2>&1; then
  fail "Rejected notarization result must fail"
fi
require_text "$testRoot/notary-rejected-result.log" 'Apple rejected notarization'
require_text "$testRoot/notary-rejected-result.log" 'diagnostics suppressed because they may contain secrets'
[[ ! -e "$testRoot/published" ]] || fail "rejected notarization must not publish an artifact directory"
[[ ! -e "$testRoot/rejected-work" ]] || fail "rejected notarization must clean temporary work"

for notaryMode in invalid in-progress missing-status text-status; do
  if NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_NOTARY_MODE="$notaryMode" \
    run_contract_helpers "$testRoot/notary-$notaryMode-result.log" \
    'if release_submit_notarization "'"$testRoot"'/notary.zip" "'"$testRoot"'/state/notary-'"$notaryMode"'.log" "TestProfile" "" "" ""; then exit 99; fi; printf "%s\n" "$releaseNotarizationFailureReason"; exit 1'; then
    fail "$notaryMode notarization result must fail"
  fi
done
if NOTARY_TEST_STATE_ROOT="$testRoot/state" NOTARY_TEST_NOTARY_MODE=accepted NOTARY_TEST_PLUTIL_MODE=partial-fail \
  run_contract_helpers "$testRoot/notary-parser-failure-result.log" \
  'if release_submit_notarization "'"$testRoot"'/notary.zip" "'"$testRoot"'/state/notary-parser-failure.log" "TestProfile" "" "" ""; then exit 99; fi; printf "%s\n" "$releaseNotarizationFailureReason"; exit 1'; then
  fail "notarization parser failure with partial output must fail"
fi
require_text "$testRoot/notary-parser-failure-result.log" 'notarization did not report Accepted'
require_text "$testRoot/notary-invalid-result.log" 'Apple rejected notarization'
for notaryMode in in-progress missing-status text-status; do
  require_text "$testRoot/notary-$notaryMode-result.log" 'notarization did not report Accepted'
done

# --- GitHub Release publication behavior ---
publishRevision=1111111111111111111111111111111111111111
mkdir -p "$testRoot/publish/one"
printf 'notes\n' >"$testRoot/publish/one/AlTab-test-RELEASE-NOTES.md"
printf 'artifact\n' >"$testRoot/publish/one/AlTab-test.zip"
: >"$testRoot/state/gh-args.log"
rm -f "$testRoot/state/remote-tag-sha"
env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=absent PUBLISH_TEST_REMOTE_TAG_MODE=missing \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish" true \
  >"$testRoot/publish-create.log" 2>&1 || fail "new release publication failed"
require_text "$testRoot/state/gh-args.log" 'release create preview-111111111111-notarized'
require_text "$testRoot/state/gh-args.log" "--target $publishRevision"
require_text "$testRoot/state/gh-args.log" '--draft'
require_text "$testRoot/state/gh-args.log" '--verify-tag'
require_text "$testRoot/state/gh-args.log" 'api --method POST repos/{owner}/{repo}/git/refs'

: >"$testRoot/state/gh-args.log"
rm -f "$testRoot/state/remote-tag-sha"
env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=existing PUBLISH_TEST_REMOTE_TAG_MODE=present PUBLISH_TEST_REMOTE_TAG_SHA="$publishRevision" \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish" false \
  >"$testRoot/publish-upload.log" 2>&1 || fail "existing release upload failed"
require_text "$testRoot/state/gh-args.log" 'release upload preview-111111111111-notarized'
if rg -q -F 'release create' "$testRoot/state/gh-args.log"; then fail "existing release must not be recreated"; fi

: >"$testRoot/state/gh-args.log"
rm -f "$testRoot/state/remote-tag-sha"
env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=existing PUBLISH_TEST_REMOTE_TAG_MODE=present PUBLISH_TEST_REMOTE_TAG_SHA="$publishRevision" \
  scripts/publish_release_artifacts.sh altab-v1.2.3 "$publishRevision" notarized "$testRoot/publish" false \
  >"$testRoot/publish-tagged-upload.log" 2>&1 || fail "existing tagged source-only release upload failed"
require_text "$testRoot/state/gh-args.log" 'release upload altab-v1.2.3'

: >"$testRoot/state/gh-args.log"
rm -f "$testRoot/state/remote-tag-sha"
if env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=absent PUBLISH_TEST_REMOTE_TAG_MODE=present PUBLISH_TEST_REMOTE_TAG_SHA=2222222222222222222222222222222222222222 \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish" false \
  >"$testRoot/publish-tag-conflict.log" 2>&1; then
  fail "conflicting release tag must fail"
fi
require_text "$testRoot/publish-tag-conflict.log" 'instead of'
[[ ! -s "$testRoot/state/gh-args.log" ]] || fail "remote tag conflict must fail before calling gh"

: >"$testRoot/state/gh-args.log"
rm -f "$testRoot/state/remote-tag-sha"
if env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=error PUBLISH_TEST_REMOTE_TAG_MODE=present PUBLISH_TEST_REMOTE_TAG_SHA="$publishRevision" \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish" false \
  >"$testRoot/publish-lookup-error.log" 2>&1; then
  fail "release lookup error must fail closed"
fi
require_text "$testRoot/publish-lookup-error.log" 'could not determine whether release'
if rg -q -F 'release create' "$testRoot/state/gh-args.log"; then fail "lookup error must not create a release"; fi

mkdir -p "$testRoot/publish-empty" "$testRoot/publish-many/a" "$testRoot/publish-many/b"
for invalidRoot in publish-empty publish-many; do
  if env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=absent PUBLISH_TEST_TAG_MODE=missing \
    scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/$invalidRoot" false \
    >"$testRoot/$invalidRoot.log" 2>&1; then
    fail "$invalidRoot artifact layout must fail"
  fi
  require_text "$testRoot/$invalidRoot.log" 'expected exactly one artifact directory'
done

mkdir -p "$testRoot/publish-many-notes/one"
printf 'one\n' >"$testRoot/publish-many-notes/one/AlTab-one-RELEASE-NOTES.md"
printf 'two\n' >"$testRoot/publish-many-notes/one/AlTab-two-RELEASE-NOTES.md"
if env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=absent PUBLISH_TEST_TAG_MODE=missing \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish-many-notes" false \
  >"$testRoot/publish-many-notes.log" 2>&1; then
  fail "multiple release-notes files must fail"
fi
require_text "$testRoot/publish-many-notes.log" 'expected exactly one release-notes file'

mkdir -p "$testRoot/publish-no-notes/one"
printf 'artifact\n' >"$testRoot/publish-no-notes/one/AlTab-test.zip"
if env PATH="$testRoot/bin:$PATH" PUBLISH_TEST_STATE_ROOT="$testRoot/state" PUBLISH_TEST_GH_MODE=absent PUBLISH_TEST_REMOTE_TAG_MODE=missing \
  scripts/publish_release_artifacts.sh "$publishRevision" "$publishRevision" notarized "$testRoot/publish-no-notes" false \
  >"$testRoot/publish-no-notes.log" 2>&1; then
  fail "missing release-notes file must fail"
fi
require_text "$testRoot/publish-no-notes.log" 'expected exactly one release-notes file, found 0'

# Workflow safety contracts when present.
if [[ -f .github/workflows/release.yml ]]; then
  require_text .github/workflows/release.yml 'workflow_dispatch'
  require_text .github/workflows/release.yml 'distribution_mode'
  require_text .github/workflows/release.yml 'unsigned'
  require_text .github/workflows/release.yml 'notarized'
  require_text .github/workflows/release.yml 'create_github_release'
  require_text .github/workflows/release.yml 'contents: write'
  require_text .github/workflows/release.yml 'package_notarized_release.sh'
  require_text .github/workflows/release.yml 'publish_release_artifacts.sh'
  require_text .github/workflows/release.yml ': "${ALTAB_BUNDLE_ID:?missing secret ALTAB_BUNDLE_ID}"'
  require_text .github/workflows/release.yml '--bundle-id "$ALTAB_BUNDLE_ID"'
  require_text scripts/publish_release_artifacts.sh '--target "$commitSha"'
  require_text scripts/publish_release_artifacts.sh 'gh release upload'
  if rg -n 'contents:[[:space:]]*\$\{\{' .github/workflows/release.yml; then fail "release workflow permissions must be static"; fi
  if rg -n -F 'ALTAB_RELEASE_KEYCHAIN_PASSWORD' .github/workflows/release.yml; then fail "temporary keychain password must not be exported"; fi
  if rg -n 'git tag.*\|\| true' .github/workflows/release.yml scripts/publish_release_artifacts.sh; then fail "release publication must not ignore tag creation failures"; fi
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
  if command -v actionlint >/dev/null; then
    actionlint .github/workflows/release.yml
  fi
fi

echo "notarized-release check passed"
