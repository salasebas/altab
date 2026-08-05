#!/usr/bin/env bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"
importer="src/preferences/LegacyPreferencesImporter.swift"

fail() {
  echo "legacy-preferences-import check failed: $1" >&2
  exit 1
}

if rg -n '(^|[^A-Za-z])(import[[:space:]]+Security|SecItem|SecKey|kSec[A-Z]|Keychain)' "$importer"; then
  fail "importer contains Security or Keychain access"
fi

if rg -n '(removePersistentDomain|addSuiteNamed|removeSuiteNamed)' "$importer"; then
  fail "importer can mutate or attach a source defaults domain"
fi

if rg -n 'UserDefaults\.standard\.(set|removeObject|setPersistentDomain|removePersistentDomain)' "$importer"; then
  fail "importer writes through the source-domain reader"
fi

domains="$(rg -N -o 'com\.[A-Za-z0-9.-]+' "$importer" | sort -u)"
expectedDomains=$'com.lwouis.alt-tab-macos\ncom.lwouis.alt-tab-macos.license'
[[ "$domains" == "$expectedDomains" ]] || fail "unexpected source domain literal(s): $domains"

echo "legacy-preferences-import check passed"
