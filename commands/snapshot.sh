#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/state.sh"
. "${HERE}/modules/svc/svc.sh"

cfg_path() { echo "${XRF_ETC:-/usr/local/etc}/xray/config.json"; }
snap_dir() { echo "${XRF_VAR:-/var/lib/xray-fusion}/snapshots"; }

usage() {
cat <<EOF
Usage:
  xrf snapshot create <name>
  xrf snapshot restore <name>
Environment overrides:
  XRF_ETC=/usr/local/etc
  XRF_VAR=/var/lib/xray-fusion
EOF
}

snapshot_create() {
  local name="$1"
  [[ -z "${name}" ]] && { core::log error "name required"; return 2; }
  local dir
  dir="$(snap_dir)/${name}"
  io::ensure_dir "${dir}" 0755
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan snapshot" "$(printf '{"name":"%s","dir":"%s"}' "${name}" "${dir}")"
    return 0
  fi
  local cfg; cfg="$(cfg_path)"
  [[ -f "${cfg}" ]] || { core::log error "config not found" "$(printf '{"path":"%s"}' "${cfg}")"; return 3; }
  cp -f "${cfg}" "${dir}/config.json"
  state::load > "${dir}/state.json"
  printf '{"name":"%s","created_at":"%s"}
' "${name}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${dir}/meta.json"
  core::log info "Snapshot created" "$(printf '{"dir":"%s"}' "${dir}")"
}

snapshot_restore() {
  local name="$1"
  [[ -z "${name}" ]] && { core::log error "name required"; return 2; }
  local dir
  dir="$(snap_dir)/${name}"
  [[ -d "${dir}" ]] || { core::log error "snapshot not found" "$(printf '{"dir":"%s"}' "${dir}")"; return 3; }
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan restore" "$(printf '{"name":"%s"}' "${name}")"
    return 0
  fi
  local cfg; cfg="$(cfg_path)"
  io::atomic_write "${cfg}" 0644 < "${dir}/config.json"
  svc::reload xray || true
  core::log info "Restored" "$(printf '{"config":"%s"}' "${cfg}")"
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "${sub}" in
    create) snapshot_create "${1-}" ;;
    restore) snapshot_restore "${1-}" ;;
    *) usage; exit 2 ;;
  esac
}
main "$@"
