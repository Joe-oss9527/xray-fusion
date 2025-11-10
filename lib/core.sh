#!/usr/bin/env bash
# Core utils: strict-mode (only via init), logging, retry
# NOTE: This file is sourced. Strict mode (set -euo pipefail) is set by core::init()
#       which must be called by the main script.

core::init() {
  set -euo pipefail -E
  export XRF_JSON="${XRF_JSON:-false}"
  export XRF_DEBUG="${XRF_DEBUG:-false}"
  for arg in "${@}"; do
    case "${arg}" in
      --json) XRF_JSON=true ;;
      --debug) XRF_DEBUG=true ;;
      *) ;;
    esac
  done
  trap 'core::error_handler "${?}" "${LINENO}" "${BASH_COMMAND}"' ERR
}

core::error_handler() {
  local return_code="${1}" line_number="${2}" command="${3}"
  core::log error "trap" "$(printf '{"rc":%d,"line":%d,"cmd":"%s"}' "${return_code}" "${line_number}" "${command//\"/\\\"}")"
  exit "${return_code}"
}

core::ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

core::log() {
  local lvl="${1}"
  shift
  local msg="${1}"
  shift || true
  local ctx="${1-{} }"

  # Filter debug messages unless XRF_DEBUG is true
  if [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]]; then
    return 0
  fi

  # All logs go to stderr to avoid contaminating function outputs
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  fi
}

core::retry() {
  local max_attempts="${1:-3}"
  shift
  local attempt=0
  until "${@}"; do
    attempt=$((attempt + 1))
    [[ ${attempt} -ge ${max_attempts} ]] && return 1
    sleep $((attempt * attempt))
  done
}

core::with_flock() {
  local lock="${1}"
  shift || true
  [[ $# -gt 0 ]] || {
    core::log error "with_flock missing command" "$(printf '{"lock":"%s"}' "${lock//\"/\\\"}")"
    return 2
  }
  local dir
  dir="$(dirname "${lock}")"
  if ! mkdir -p "${dir}" 2> /dev/null; then
    core::log warn "mkdir fallback sudo" "$(printf '{"dir":"%s"}' "${dir//\"/\\\"}")"
    sudo mkdir -p "${dir}"
  fi

  # Security: Atomic lock file creation with correct ownership and permissions
  # Use install(1) instead of touch + chown to prevent TOCTOU window
  if ! test -f "${lock}" 2> /dev/null; then
    if ! install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${lock}" 2> /dev/null; then
      core::log warn "lock file creation needs sudo" "$(printf '{"file":"%s"}' "${lock//\"/\\\"}")"
      # Use install with sudo for atomic creation (single syscall, no TOCTOU)
      sudo install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${lock}" 2> /dev/null || true
    fi
  else
    # Lock file exists, ensure correct permissions
    if ! chmod 0644 "${lock}" 2> /dev/null; then
      sudo chmod 0644 "${lock}" 2> /dev/null || true
    fi
  fi

  (
    exec 200>> "${lock}"
    flock 200
    "${@}"
  )
}
