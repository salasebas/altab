#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

fail() {
  echo "release-readiness check failed: $1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing $1"
}

require_executable() {
  [[ -x "$1" ]] || fail "$1 is not executable"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q -F -- "$text" "$path" || fail "$path does not contain: $text"
}

require_text package.json '"license": "GPL-3.0-only"'
require_file NOTICE.md
require_file LICENCE.md
require_file vendor/ShortcutRecorder/LICENSE.txt
require_file scripts/licenses/createicns-LICENSE.txt
require_file scripts/licenses/xcbeautify-LICENSE.txt
require_text vendor/scripts/update_shortcut_recorder.sh 'cp "$TMP/src/LICENSE.txt" "$DEST/LICENSE.txt"'
require_file scripts/package_release.sh
require_executable scripts/package_release.sh
require_file scripts/verify_release_artifacts.sh
require_executable scripts/verify_release_artifacts.sh
require_file docs/releasing.md
require_file .github/RELEASE_NOTES_TEMPLATE.md

for contract in \
  'Git commit' \
  'Git tag' \
  'Xcode' \
  'Swift' \
  'macOS SDK' \
  'Build architectures' \
  'Build command' \
  'Signing status' \
  'Notarization status' \
  'AlTab.app.dSYM' \
  'git archive' \
  'shasum -a 256' \
  'scripts/check_service_isolation.sh' \
  'scripts/check_unrestricted_features.sh'; do
  require_text scripts/package_release.sh "$contract"
done

require_text docs/releasing.md 'scripts/package_release.sh <tag-or-commit>'
require_text docs/releasing.md 'unsigned and not notarized'
require_text .github/RELEASE_NOTES_TEMPLATE.md 'Signing status:'
require_text .github/RELEASE_NOTES_TEMPLATE.md 'Notarization status:'
require_text README.md 'scripts/package_release.sh'
require_text FORK.md '- [x] Correct all root metadata so it consistently declares the GPL license.'
require_text FORK.md '- [x] Keep corresponding source, build scripts, copyright notices, Git history, and third-party licenses available with every binary distribution.'
require_text FORK.md '- [x] Publish checksums and describe exactly how each release artifact was built.'

echo "release-readiness check passed"
