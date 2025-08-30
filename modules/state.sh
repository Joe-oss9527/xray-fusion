#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/modules/io.sh"

state::dir()  { echo "${XRF_VAR:-/var/lib/xray-fusion}"; }
state::path() { echo "$(state::dir)/state.json"; }

state::save() {
  local json="$1"
  io::ensure_dir "$(state::dir)" 0755
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "$json" | sed -n '1,80p'
    return 0
  fi
  io::atomic_write "$(state::path)" 0644 <<<"$json"
}

state::load() {
  local p; p="$(state::path)"
  if [[ -f "$p" ]]; then cat "$p"; else echo "{}"; fi
}
