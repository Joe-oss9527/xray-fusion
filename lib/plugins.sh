#!/usr/bin/env bash
# Lightweight plugin loader + event bus

plugins::base() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [[ -n "${XRF_PLUGINS:-}" ]] && { echo "${XRF_PLUGINS}"; return; }
  echo "${here}/plugins"
}
plugins::dir_available(){ echo "$(plugins::base)/available"; }
plugins::dir_enabled(){ echo "$(plugins::base)/enabled"; }
plugins::ensure_dirs(){ mkdir -p "$(plugins::dir_available)" "$(plugins::dir_enabled)"; }

# Load
declare -ag __PLUG_IDS=()
declare -Ag __PLUG_META=()

plugins::load_enabled() {
  __PLUG_IDS=()
  local d; d="$(plugins::dir_enabled)"
  [[ -d "${d}" ]] || return 0
  local f project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  for f in "${d}"/*.sh; do
    [[ -f "${f}" ]] || continue
    # shellcheck source=/dev/null
    if HERE="${project_root}" . "${f}" 2>/dev/null; then
      # Validate required plugin variables
      if [[ -n "${XRF_PLUGIN_ID:-}" ]]; then
        local id="${XRF_PLUGIN_ID}" ver="${XRF_PLUGIN_VERSION:-0.0.0}" desc="${XRF_PLUGIN_DESC:-}" hooks="${XRF_PLUGIN_HOOKS[*]:-}"
        __PLUG_IDS+=("${id}")
        __PLUG_META["${id}"]="${ver}|${desc}|${hooks}"
      else
        echo "Warning: Plugin $(basename "${f}") missing XRF_PLUGIN_ID" >&2
      fi
    else
      echo "Warning: Failed to load plugin $(basename "${f}")" >&2
    fi
    # Clear plugin variables for next iteration
    unset XRF_PLUGIN_ID XRF_PLUGIN_VERSION XRF_PLUGIN_DESC XRF_PLUGIN_HOOKS
  done
}

plugins::fn_prefix(){ echo "${1//-/_}"; }

plugins::emit() {
  local event="${1}"; shift || true
  local args=("${@}")
  local id meta hooks fn
  for id in "${__PLUG_IDS[@]}"; do
    meta="${__PLUG_META[${id}]}"
    hooks="${meta#*|}"; hooks="${hooks#*|}"
    case " ${hooks} " in *" ${event} "*) ;; *) continue ;; esac
    fn="$(plugins::fn_prefix "${id}")::${event}"
    if declare -F "${fn}" >/dev/null 2>&1; then "${fn}" "${args[@]}" || true; fi
  done
}

plugins::list(){
  local av en; av="$(plugins::dir_available)"; en="$(plugins::dir_enabled)"
  echo "Available:"
  local f
  for f in "${av}"/*/plugin.sh; do
    [[ -f "${f}" ]] || continue
    # shellcheck source=/dev/null
    . "${f}"
    printf "  - %-14s %s (v%s)\n" "${XRF_PLUGIN_ID}" "${XRF_PLUGIN_DESC:-}" "${XRF_PLUGIN_VERSION:-0.0.0}"
  done
  echo ""
  echo "Enabled:"
  for f in "${en}"/*.sh; do
    [[ -f "${f}" ]] || continue
    # shellcheck source=/dev/null
    . "${f}"
    echo "  - ${XRF_PLUGIN_ID}"
  done
}

plugins::enable(){ local id="${1:?id}"; local src="$(plugins::dir_available)/${id}/plugin.sh"; local dst="$(plugins::dir_enabled)/${id}.sh"; [[ -f "${src}" ]] || { echo "plugin not found: ${id}"; return 2; }; ln -sfn "../available/${id}/plugin.sh" "${dst}"; echo "enabled: ${id}"; }
plugins::disable(){ local id="${1:?id}"; local dst="$(plugins::dir_enabled)/${id}.sh"; [[ -e "${dst}" ]] || { echo "plugin not enabled: ${id}"; return 2; }; rm -f "${dst}"; echo "disabled: ${id}"; }
plugins::info(){ local id="${1:?id}"; local f="$(plugins::dir_available)/${id}/plugin.sh"; [[ -f "${f}" ]] || { echo "plugin not found: ${id}"; return 2; }; # shellcheck source=/dev/null
  . "${f}"; echo "id: ${XRF_PLUGIN_ID}"; echo "version: ${XRF_PLUGIN_VERSION:-0.0.0}"; echo "desc: ${XRF_PLUGIN_DESC:-}"; echo "hooks: ${XRF_PLUGIN_HOOKS[*]:-}"; }
