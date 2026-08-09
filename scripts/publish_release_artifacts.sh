#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "release publication failed: $1" >&2
  exit 1
}

[[ $# -eq 5 ]] || fail "usage: scripts/publish_release_artifacts.sh <revision> <commit-sha> <unsigned|notarized> <artifact-root> <draft-true-or-false>"
revision="$1"
commitSha="$2"
mode="$3"
artifactRoot="$4"
createDraft="$5"
[[ "$commitSha" =~ ^[0-9a-fA-F]{40}$ ]] || fail "commit SHA must contain exactly 40 hexadecimal characters"
commitSha="$(printf '%s' "$commitSha" | tr '[:upper:]' '[:lower:]')"
[[ "$mode" == "unsigned" || "$mode" == "notarized" ]] || fail "mode must be unsigned or notarized"
[[ "$createDraft" == "true" || "$createDraft" == "false" ]] || fail "draft value must be true or false"
[[ -d "$artifactRoot" ]] || fail "artifact root does not exist: $artifactRoot"
for dependency in gh git; do command -v "$dependency" >/dev/null || fail "missing required dependency: $dependency"; done

scriptRoot="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=release_artifact_contracts.sh
source "$scriptRoot/release_artifact_contracts.sh"
[[ "${releaseArtifactContractsVersion:-}" == "1" ]] || fail "unsupported release artifact contracts version"

artifactDirectories=()
while IFS= read -r artifactDirectory; do
  artifactDirectories+=("$artifactDirectory")
done < <(find "$artifactRoot" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
[[ ${#artifactDirectories[@]} -eq 1 ]] || fail "expected exactly one artifact directory, found ${#artifactDirectories[@]}"
artifactDirectory="${artifactDirectories[0]}"
notesFiles=()
while IFS= read -r notesFile; do
  notesFiles+=("$notesFile")
done < <(find "$artifactDirectory" -mindepth 1 -maxdepth 1 -type f -name 'AlTab-*-RELEASE-NOTES.md' -print | LC_ALL=C sort)
[[ ${#notesFiles[@]} -eq 1 ]] || fail "expected exactly one release-notes file, found ${#notesFiles[@]}"
notesFile="${notesFiles[0]}"
artifacts=()
while IFS= read -r artifact; do
  artifacts+=("$artifact")
done < <(find "$artifactDirectory" -mindepth 1 -maxdepth 1 -type f ! -type l -print | LC_ALL=C sort)
[[ ${#artifacts[@]} -gt 0 ]] || fail "artifact directory is empty"
localAssetNames=()
for artifact in "${artifacts[@]}"; do
  [[ -f "$artifact" && ! -L "$artifact" ]] || fail "release artifact is not a regular file: $artifact"
  localAssetNames+=("$(basename "$artifact")")
done
release_audit_published_asset_names "${localAssetNames[@]}"
if ! printf '%s\n' "${localAssetNames[@]}" | rg -q 'AlTab-.*-macOS(-unsigned)?\.zip'; then
  fail "publish requires a packaged binary ZIP (unsigned or notarized) plus corresponding source set"
fi

tagName="$revision"
if [[ "$revision" =~ ^[0-9a-fA-F]{40}$ ]]; then
  tagName="preview-${revision:0:12}-$mode"
fi
resolve_remote_tag_commit() {
  local remoteRefs
  local directSha
  local peeledSha
  remoteRefs="$(git ls-remote --tags origin "refs/tags/$tagName" "refs/tags/$tagName^{}")" || fail "could not inspect remote tag $tagName"
  directSha="$(printf '%s\n' "$remoteRefs" | awk -v ref="refs/tags/$tagName" '$2 == ref { print $1; exit }')"
  peeledSha="$(printf '%s\n' "$remoteRefs" | awk -v ref="refs/tags/$tagName^{}" '$2 == ref { print $1; exit }')"
  if [[ -n "$peeledSha" ]]; then
    printf '%s' "$peeledSha" | tr '[:upper:]' '[:lower:]'
  elif [[ -n "$directSha" ]]; then
    printf '%s' "$directSha" | tr '[:upper:]' '[:lower:]'
  fi
}

list_remote_release_asset_names() {
  local releaseTag="$1"
  local assetsJson
  assetsJson="$(gh release view "$releaseTag" --json assets)" || fail "could not read assets for release $releaseTag"
  python3 -c 'import json,sys; data=json.load(sys.stdin); print("\n".join(asset.get("name","") for asset in data.get("assets",[]) if asset.get("name")))' <<<"$assetsJson"
}

audit_remote_release() {
  local releaseTag="$1"
  local remoteNames=()
  local remoteName
  while IFS= read -r remoteName; do
    [[ -n "$remoteName" ]] || continue
    remoteNames+=("$remoteName")
  done < <(list_remote_release_asset_names "$releaseTag")
  [[ ${#remoteNames[@]} -gt 0 ]] || fail "remote release $releaseTag has no assets after publication"
  local expectedName
  for expectedName in "${localAssetNames[@]}"; do
    printf '%s\n' "${remoteNames[@]}" | rg -qx "$expectedName" || fail "remote release $releaseTag is missing published asset $expectedName"
  done
  release_audit_published_asset_names "${remoteNames[@]}"
}

preflight_existing_assets() {
  local releaseTag="$1"
  local remoteNames=()
  local remoteName
  local overlap=()
  while IFS= read -r remoteName; do
    [[ -n "$remoteName" ]] || continue
    remoteNames+=("$remoteName")
  done < <(list_remote_release_asset_names "$releaseTag")
  local localName
  for localName in "${localAssetNames[@]}"; do
    if printf '%s\n' "${remoteNames[@]}" | rg -qx "$localName"; then
      overlap+=("$localName")
    fi
  done
  [[ ${#overlap[@]} -eq 0 ]] && return 0
  if [[ "${ALTAB_RELEASE_REPLACE_ASSETS:-}" == "1" ]]; then
    echo "replacing existing release assets on $releaseTag (ALTAB_RELEASE_REPLACE_ASSETS=1): ${overlap[*]}" >&2
    return 0
  fi
  fail "release $releaseTag already has assets with the same name (${overlap[*]}); refuse to upload duplicates. Set ALTAB_RELEASE_REPLACE_ASSETS=1 to replace explicitly"
}

remoteTagCommitSha="$(resolve_remote_tag_commit)"
if [[ -n "$remoteTagCommitSha" ]]; then
  [[ "$remoteTagCommitSha" =~ ^[0-9a-f]{40}$ ]] || fail "remote tag $tagName has an invalid object ID"
  [[ "$remoteTagCommitSha" == "$commitSha" ]] || fail "remote tag $tagName points to $remoteTagCommitSha instead of $commitSha"
elif [[ ! "$revision" =~ ^[0-9a-fA-F]{40}$ ]]; then
  fail "release tag is missing from origin: $tagName"
fi

if releaseViewOutput="$(gh release view "$tagName" --json tagName 2>&1)"; then
  releaseViewStatus=0
else
  releaseViewStatus=$?
fi
if [[ $releaseViewStatus -eq 0 ]]; then
  remoteTagCommitSha="$(resolve_remote_tag_commit)"
  [[ -n "$remoteTagCommitSha" ]] || fail "release $tagName exists but its tag is missing from origin"
  [[ "$remoteTagCommitSha" == "$commitSha" ]] || fail "remote tag $tagName changed to $remoteTagCommitSha before upload"
  preflight_existing_assets "$tagName"
  uploadArguments=("$tagName")
  if [[ "${ALTAB_RELEASE_REPLACE_ASSETS:-}" == "1" ]]; then
    uploadArguments+=(--clobber)
  fi
  uploadArguments+=("${artifacts[@]}")
  gh release upload "${uploadArguments[@]}"
  audit_remote_release "$tagName"
  exit 0
fi
case "$releaseViewOutput" in
  *"release not found"*|*"HTTP 404"*|*"Not Found"*) ;;
  *)
    printf '%s\n' "$releaseViewOutput" >&2
    fail "could not determine whether release $tagName exists"
    ;;
esac

if [[ -z "$remoteTagCommitSha" ]]; then
  gh api --method POST 'repos/{owner}/{repo}/git/refs' \
    -f "ref=refs/tags/$tagName" \
    -f "sha=$commitSha" >/dev/null || fail "could not create remote tag $tagName at $commitSha"
fi
remoteTagCommitSha="$(resolve_remote_tag_commit)"
[[ "$remoteTagCommitSha" == "$commitSha" ]] || fail "remote tag $tagName does not resolve to $commitSha before release creation"

draftArguments=()
if [[ "$createDraft" == "true" ]]; then
  draftArguments+=(--draft)
fi
gh release create "$tagName" \
  "${draftArguments[@]}" \
  --verify-tag \
  --target "$commitSha" \
  --title "AlTab $tagName ($mode)" \
  --notes-file "$notesFile" \
  "${artifacts[@]}"
audit_remote_release "$tagName"
