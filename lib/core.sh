#!/usr/bin/env bash
# Core utils: strict mode, logging, retry, json flag
CORE_LOADED=1

core::init() {
  set -euo pipefail
  export XRF_JSON="${XRF_JSON:-false}"
  export XRF_DEBUG="${XRF_DEBUG:-false}"
  # parse global flags
  for a in "$@"; do
    case "$a" in --json) XRF_JSON=true ;; --debug) XRF_DEBUG=true ;; esac
  done
  trap 'code=$?; core::log error "trap" "{"rc":$code}"; exit $code' ERR
}

core::ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

core::log() {
  local level="$1"; shift
  local msg="$1"; shift || true
  local ctx="${1-{} }"
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' "$(core::ts)" "$level" "$msg" "$ctx"
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "$level" "$msg" "$ctx"
  fi
}

core::retry() {
  local n="${1:-3}"; shift
  local i=0
  until "$@"; do
    i=$((i+1)); [[ $i -ge $n ]] && return 1
    sleep $((i*i))
  done
}
