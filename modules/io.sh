#!/usr/bin/env bash
# IO helpers: atomic write, dir perms, safe install with sudo fallback
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/core.sh
. "${HERE}/lib/core.sh"

io::confirm_sudo() {
  local operation="$1"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan requires sudo" "$(printf '{"operation":"%s"}' "${operation}")"
    return 0
  fi
  if [[ "${XRF_AUTO_SUDO:-false}" != "true" ]]; then
    core::log warn "Operation requires administrative privileges" "$(printf '{"operation":"%s"}' "${operation}")"
    core::log info "Set XRF_AUTO_SUDO=true to skip confirmation" "{}"
  fi
}

io::ensure_dir() {
  local d="$1" mode="${2:-0755}"
  if [[ -d "${d}" ]]; then
    chmod "${mode}" "${d}" || true
    return 0
  fi
  if mkdir -p "${d}" 2>/dev/null; then
    chmod "${mode}" "${d}" || true
    return 0
  fi
  io::confirm_sudo "create directory ${d}"
  sudo mkdir -p "${d}"
  sudo chmod "${mode}" "${d}" || true
}

io::writable() { test -w "$1" 2>/dev/null; }

io::atomic_write() {
  local dst="$1" mode="${2:-0644}"
  local tmp
  tmp="$(mktemp "${dst}.XXXX.tmp")" || return 1
  # read from stdin to tmp
  cat > "${tmp}"
  if io::writable "$(dirname "${dst}")"; then
    mv -f "${tmp}" "${dst}"
    chmod "${mode}" "${dst}" || true
  else
    io::confirm_sudo "write file ${dst}"
    sudo mv -f "${tmp}" "${dst}"
    sudo chmod "${mode}" "${dst}" || true
  fi
}

io::install_file() {
  # io::install_file <src> <dst> [mode]
  local src="$1" dst="$2" mode="${3:-0755}"
  io::ensure_dir "$(dirname "${dst}")"
  if cp -f "${src}" "${dst}" 2>/dev/null; then
    chmod "${mode}" "${dst}" || true
    return 0
  fi
  io::confirm_sudo "install file ${dst}"
  sudo cp -f "${src}" "${dst}"
  sudo chmod "${mode}" "${dst}" || true
}
