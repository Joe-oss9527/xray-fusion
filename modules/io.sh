#!/usr/bin/env bash
# Atomic write + safe install helpers
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/core.sh
. "${HERE}/lib/core.sh"

io::ensure_dir() {
  local dir="${1}" mode="${2:-0755}"
  [[ -d "${dir}" ]] && {
    chmod "${mode}" "${dir}" || true
    return 0
  }
  mkdir -p "${dir}" 2> /dev/null || {
    core::log warn "mkdir fallback sudo" "$(printf '{"dir":"%s"}' "${dir}")"
    sudo mkdir -p "${dir}"
  }
  chmod "${mode}" "${dir}" || true
}

io::writable() { test -w "${1}" 2> /dev/null; }

io::atomic_write() {
  local dst="${1}" mode="${2:-0644}"
  local dstdir tmp
  dstdir="$(dirname "${dst}")"

  # Security: Create temp file in destination directory (same partition for atomic mv)
  # Use hidden prefix to prevent conflicts and mktemp XXXXXX for unpredictability
  tmp="$(mktemp -p "${dstdir}" .atomic-write.XXXXXX.tmp)" || return 1

  # Write content to temp file
  if ! cat > "${tmp}"; then
    rm -f "${tmp}" 2>/dev/null || true
    return 1
  fi

  # Move to final location
  if io::writable "${dstdir}"; then
    if ! mv -f "${tmp}" "${dst}"; then
      rm -f "${tmp}" 2>/dev/null || true
      return 1
    fi
    chmod "${mode}" "${dst}" || true
  else
    core::log warn "write needs sudo" "$(printf '{"file":"%s"}' "${dst}")"
    if ! sudo mv -f "${tmp}" "${dst}"; then
      rm -f "${tmp}" 2>/dev/null || true
      return 1
    fi
    sudo chmod "${mode}" "${dst}" || true
  fi

  # Success - temp file has been moved
  return 0
}

io::install_file() {
  local src="${1}" dst="${2}" mode="${3:-0755}"
  io::ensure_dir "$(dirname "${dst}")"
  if ! cp -f "${src}" "${dst}" 2> /dev/null; then
    core::log warn "copy needs sudo" "$(printf '{"file":"%s"}' "${dst}")"
    sudo cp -f "${src}" "${dst}"
  fi
  chmod "${mode}" "${dst}" || true
}
