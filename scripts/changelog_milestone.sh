#!/usr/bin/env bash
# Thin wrapper around git-cliff for AlTab source milestones.
# Heavy lifting (conventional-commit parsing, grouping) is git-cliff; this only
# splices the Unreleased / versioned section into changelog.md and bumps
# package.json on an intentional cut.
#
# Commands:
#   update              Optional local preview: rewrite ## Unreleased from commits since last altab-v* tag
#   promote <X.Y.Z>     Write ## [X.Y.Z] from commits since last tag, clear Unreleased, set package.json version
#   notes <X.Y.Z>       Print release notes body for the given version (stdout)
# CI runs promote only on intentional workflow_dispatch; update is not run on merge to main.
set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repoRoot"

changelogFile="changelog.md"
cliffConfig="cliff.toml"
startMarker="<!-- altab-changelog:unreleased-start -->"
endMarker="<!-- altab-changelog:unreleased-end -->"

die() {
  echo "error: $*" >&2
  exit 1
}

require_git_cliff() {
  command -v git-cliff >/dev/null 2>&1 || die "git-cliff not found on PATH (https://git-cliff.org)"
  [[ -f "$cliffConfig" ]] || die "missing $cliffConfig"
  [[ -f "$changelogFile" ]] || die "missing $changelogFile"
}

validate_semver() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be MAJOR.MINOR.PATCH (got: $version)"
}

ensure_markers() {
  if grep -qF "$startMarker" "$changelogFile" && grep -qF "$endMarker" "$changelogFile"; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  awk -v start="$startMarker" -v end="$endMarker" '
    BEGIN { state = 0 }
    state == 0 && $0 ~ /^## Unreleased$/ {
      print start
      print
      state = 1
      next
    }
    state == 1 && $0 ~ /^## / {
      print end
      print ""
      print
      state = 2
      next
    }
    { print }
    END {
      if (state == 1) print end
      if (state == 0) exit 2
    }
  ' "$changelogFile" >"$tmp" || die "could not find ## Unreleased in $changelogFile to place markers"
  mv "$tmp" "$changelogFile"
}

# Replace everything between the Unreleased markers (exclusive of markers).
splice_between_markers() {
  local bodyFile="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v start="$startMarker" -v end="$endMarker" -v bodyFile="$bodyFile" '
    BEGIN { mode = 0 }
    $0 == start {
      print
      while ((getline line < bodyFile) > 0) print line
      close(bodyFile)
      mode = 1
      next
    }
    mode == 1 && $0 == end {
      print
      mode = 2
      next
    }
    mode != 1 { print }
    END {
      if (mode != 2) exit 3
    }
  ' "$changelogFile" >"$tmp" || die "failed to splice Unreleased section (markers missing or mismatched)"
  mv "$tmp" "$changelogFile"
}

# Insert a file immediately after the Unreleased end marker.
insert_after_unreleased() {
  local sectionFile="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v end="$endMarker" -v sectionFile="$sectionFile" '
    { print }
    $0 == end {
      print ""
      while ((getline line < sectionFile) > 0) print line
      close(sectionFile)
    }
  ' "$changelogFile" >"$tmp"
  mv "$tmp" "$changelogFile"
}

render_unreleased() {
  git cliff --config "$cliffConfig" --unreleased --strip all
}

render_versioned() {
  local version="$1"
  local tag="altab-v${version}"
  git cliff --config "$cliffConfig" --unreleased --tag "$tag" --strip all
}

set_package_version() {
  local version="$1"
  node -e '
    const fs = require("fs");
    const path = "package.json";
    const pkg = JSON.parse(fs.readFileSync(path, "utf8"));
    pkg.version = process.argv[1];
    fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + "\n");
  ' "$version"
}

cmd_update() {
  require_git_cliff
  ensure_markers
  local body
  body="$(mktemp)"
  render_unreleased >"$body"
  if ! grep -qE '^## ' "$body"; then
    printf '## Unreleased\n\n' >"$body"
  fi
  splice_between_markers "$body"
  rm -f "$body"
}

cmd_promote() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "usage: $0 promote <MAJOR.MINOR.PATCH>"
  validate_semver "$version"
  require_git_cliff
  ensure_markers

  local versioned empty
  versioned="$(mktemp)"
  empty="$(mktemp)"

  render_versioned "$version" >"$versioned"
  if ! grep -qE '^## ' "$versioned"; then
    printf '## [%s](https://github.com/salasebas/altab/releases/tag/altab-v%s) (%s)\n\n_No conventional commits since the previous milestone._\n' \
      "$version" "$version" "$(date -u +%Y-%m-%d)" >"$versioned"
  fi

  printf '## Unreleased\n\n' >"$empty"
  splice_between_markers "$empty"
  insert_after_unreleased "$versioned"
  rm -f "$versioned" "$empty"

  set_package_version "$version"
  echo "promoted Unreleased → $version (package.json + $changelogFile)"
}

cmd_notes() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "usage: $0 notes <MAJOR.MINOR.PATCH>"
  validate_semver "$version"
  require_git_cliff
  render_versioned "$version"
}

usage() {
  cat <<EOF
usage: $0 <command> [args]

  update              Rewrite ## Unreleased from commits since last altab-v* tag
  promote <X.Y.Z>     Promote Unreleased to version X.Y.Z and bump package.json
  notes <X.Y.Z>       Print git-cliff notes for X.Y.Z (for GitHub Release body)

Requires git-cliff on PATH and cliff.toml at the repo root.
See docs/releasing.md for the maintainer cut flow.
EOF
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    update) cmd_update "$@" ;;
    promote) cmd_promote "$@" ;;
    notes) cmd_notes "$@" ;;
    -h | --help | help) usage ;;
    "") usage; exit 1 ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
