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
    
    # Clean up certificate configurations if domain info is available
    local state_file="${var}/state.json"
    if [[ -f "${state_file}" ]]; then
      local domain
      domain=$(jq -r '.xray.domain // empty' "${state_file}" 2>/dev/null)
      if [[ -n "${domain}" && -d "${HOME}/.acme.sh/${domain}_ecc" ]]; then
        core::log info "Removing certificate configuration" "$(printf '{"domain":"%s"}' "${domain}")"
        _rm "${HOME}/.acme.sh/${domain}_ecc"
      fi
    fi
    
    # Clean up any remaining xray-related certificate configurations
    if [[ -d "${HOME}/.acme.sh" ]]; then
      local cert_dirs
      cert_dirs=$(find "${HOME}/.acme.sh" -maxdepth 1 -name "*_ecc" -type d 2>/dev/null || true)
      if [[ -n "${cert_dirs}" ]]; then
        while IFS= read -r cert_dir; do
          if [[ -f "${cert_dir}/$(basename "${cert_dir%_ecc}").conf" ]]; then
            # Check if this certificate was installed to xray cert directory
            if grep -q "/usr/local/etc/xray/certs" "${cert_dir}/$(basename "${cert_dir%_ecc}").conf" 2>/dev/null; then
              core::log info "Removing orphaned certificate configuration" "$(printf '{"dir":"%s"}' "${cert_dir}")"
              _rm "${cert_dir}"
            fi
          fi
        done <<< "${cert_dirs}"
      fi
    fi
    
    # Remove xray system user and group
    if id xray >/dev/null 2>&1; then
      core::log info "Removing system user and group" '{"user":"xray"}'
      if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
        echo "userdel xray"
        echo "groupdel xray"
      else
        userdel xray 2>/dev/null || true
        groupdel xray 2>/dev/null || true
      fi
    fi
    
    # Clear systemd cache
    if [[ "${XRF_DRY_RUN:-false}" == "false" ]]; then
      systemctl daemon-reload 2>/dev/null || true
      systemctl reset-failed xray 2>/dev/null || true
    fi
    
    _rm "${var}"
  fi

  core::log info "Uninstall completed" "{}"
}
main "$@"
