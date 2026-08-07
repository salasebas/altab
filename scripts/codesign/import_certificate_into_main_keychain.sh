#!/usr/bin/env bash

set -euo pipefail

certificateFile="${1:?usage: import_certificate_into_main_keychain.sh certificate-prefix keychain}"
keychain="${2:?usage: import_certificate_into_main_keychain.sh certificate-prefix keychain}"
activeChildPid=""

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

run_security() {
  security "$@" &
  activeChildPid=$!
  local childStatus=0
  wait "$activeChildPid" || childStatus=$?
  activeChildPid=""
  return "$childStatus"
}

trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

run_security import "$certificateFile.pem" -k "$keychain" -t agg -f pemseq -x -T /usr/bin/codesign
run_security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$certificateFile.crt"
