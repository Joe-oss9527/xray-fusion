#!/usr/bin/env bash
# Core utils: strict-mode (only via init), logging, retry

core::init() {
  set -euo pipefail -E
  export XRF_JSON="${XRF_JSON:-false}"
  export XRF_DEBUG="${XRF_DEBUG:-false}"
  for a in "$@"; do
    case "$a" in
      --json) XRF_JSON=true ;;
      --debug) XRF_DEBUG=true ;;
      *) ;;
    esac
  done
  trap 'core::error_handler "$?" "$LINENO" "$BASH_COMMAND"' ERR
}

core::error_handler() {
  local rc="$1" ln="$2" cmd="$3"
  core::log error "trap" "$(printf '{"rc":%d,"line":%d,"cmd":"%s"}' "$rc" "$ln" "${cmd//\"/\\\"}")"
  exit "$rc"
}

core::ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

core::log() {
  local lvl="$1"; shift
  local msg="$1"; shift || true
  local ctx="${1-{} }"
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' "$(core::ts)" "$lvl" "$msg" "$ctx"
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "$lvl" "$msg" "$ctx"
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

core::with_flock() {
  local lock="$1"
  shift || true
  [[ $# -gt 0 ]] || { core::log error "with_flock missing command" "$(printf '{"lock":"%s"}' "${lock//\"/\\\"}")"; return 2; }
  local dir
  dir="$(dirname "$lock")"
  if ! mkdir -p "$dir" 2>/dev/null; then
    core::log warn "mkdir fallback sudo" "$(printf '{"dir":"%s"}' "${dir//\"/\\\"}")"
    sudo mkdir -p "$dir"
  fi
  if ! touch "$lock" 2>/dev/null; then
    core::log warn "touch needs sudo" "$(printf '{"file":"%s"}' "${lock//\"/\\\"}")"
    sudo touch "$lock"
    sudo chown "$(id -u):$(id -g)" "$lock" 2>/dev/null || true
  fi
  if ! chmod 0644 "$lock" 2>/dev/null; then
    sudo chmod 0644 "$lock" 2>/dev/null || true
  fi
  (
    exec 200>>"$lock"
    flock 200
    "$@"
  )
}
