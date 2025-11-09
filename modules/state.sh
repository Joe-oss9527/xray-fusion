#!/usr/bin/env bash
# State management module
# NOTE: This file is sourced. Strict mode is set by core::init() from the calling script
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/modules/io.sh"

state::dir() { echo "${XRF_VAR:-/var/lib/xray-fusion}"; }
state::path() { echo "$(state::dir)/state.json"; }
state::digest() { echo "$(state::dir)/config.sha256"; }
state::lock() { echo "$(state::dir)/locks/configure.lock"; }

state::save() {
  local j="${1}"
  io::ensure_dir "$(state::dir)" 0755
  io::atomic_write "$(state::path)" 0644 <<< "${j}"
}
state::load() {
  local p
  p="$(state::path)"
  [[ -f "${p}" ]] && cat "${p}" || echo "{}"
}
