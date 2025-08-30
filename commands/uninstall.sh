#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/svc/svc.sh"
. "${HERE}/services/xray/common.sh"

usage() {
cat <<EOF
Usage: xrf uninstall [--purge]
Without --purge: remove Xray binary & config, keep state and snapshots.
With    --purge: remove binary, config, state, snapshots (irreversible).
Respects XRF_DRY_RUN=true for preview.
EOF
}

_rm() {
  local path="$1"
  if [[ -e "${path}" || -L "${path}" ]]; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      echo "rm -rf ${path}"
    else
      sudo rm -rf "${path}" || rm -rf "${path}"
    fi
  fi
}

main() {
  core::init "$@"
  local purge=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge) purge=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) shift ;;
    esac
  done

  # stop service if present
  svc::stop xray || true

  local bin
  bin="$(xray::prefix)/bin/xray"
  local etc
  etc="$(xray::etc)/xray"
  local var
  var="$(xray::var)"

  core::log info "Uninstall plan" "$(printf '{"bin":"%s","etc":"%s","var":"%s","purge":%s}' "${bin}" "${etc}" "${var}" "${purge}")"

  _rm "${bin}"
  _rm "${etc}"
  if [[ "${purge}" == "true" ]]; then
    # best-effort remove service & timers/cron
    "${HERE}/commands/service.sh" remove || true
    "${HERE}/commands/cert.sh" unschedule || true
    _rm "${var}"
  fi

  core::log info "Uninstall completed" "{}"
}
main "$@"
