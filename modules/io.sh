#!/usr/bin/env bash
# Atomic write + safe install helpers
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/core.sh
. "${HERE}/lib/core.sh"

io::ensure_dir(){
  local d="${1}" m="${2:-0755}"
  [[ -d "${d}" ]] && { chmod "${m}" "${d}" || true; return 0; }
  mkdir -p "${d}" 2>/dev/null || { core::log warn "mkdir fallback sudo" "$(printf '{"dir":"%s"}' "${d}")"; sudo mkdir -p "${d}"; }
  chmod "${m}" "${d}" || true
}

io::writable(){ test -w "${1}" 2>/dev/null; }

io::atomic_write(){
  local dst="${1}" mode="${2:-0644}"
  local tmp; tmp="$(mktemp "${dst}.XXXX.tmp")" || return 1
  cat >"${tmp}"
  if io::writable "$(dirname "${dst}")"; then
    mv -f "${tmp}" "${dst}"
    chmod "${mode}" "${dst}" || true
  else
    core::log warn "write needs sudo" "$(printf '{"file":"%s"}' "${dst}")"
    sudo mv -f "${tmp}" "${dst}"
    sudo chmod "${mode}" "${dst}" || true
  fi
}

io::install_file(){
  local src="${1}" dst="${2}" mode="${3:-0755}"
  io::ensure_dir "$(dirname "${dst}")"
  if ! cp -f "${src}" "${dst}" 2>/dev/null; then
    core::log warn "copy needs sudo" "$(printf '{"file":"%s"}' "${dst}")"
    sudo cp -f "${src}" "${dst}"
  fi
  chmod "${mode}" "${dst}" || true
}
