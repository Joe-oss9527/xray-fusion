#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/os.sh"
# shellcheck source=modules/pkg/pkg.sh
. "${HERE}/modules/pkg/pkg.sh"
# shellcheck source=modules/svc/svc.sh
. "${HERE}/modules/svc/svc.sh"
# shellcheck source=modules/fw/fw.sh
. "${HERE}/modules/fw/fw.sh"
# shellcheck source=modules/net/tcp.sh
. "${HERE}/modules/net/tcp.sh"

parse_ports() {
  local ports="80,443,8443,10000"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ports) ports="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  echo "${ports}"
}

main() {
  core::init "$@"
  local ports_csv; ports_csv="$(parse_ports "$@")"
  IFS=',' read -r -a arr <<< "${ports_csv}"

  local os_json; os_json="$(os::detect)"
  local pkg; pkg="$(pkg::detect || echo unknown)"
  local init; init="$(svc::detect || echo unknown)"
  local fw; fw="$(fw::detect || echo none)"

  # probe ports
  local port_items="["
  for p in "${arr[@]}"; do
    if net::is_listening "${p}"; then
      port_items+=$(printf '{"port":%s,"listening":true},' "${p}")
    else
      port_items+=$(printf '{"port":%s,"listening":false},' "${p}")
    fi
  done
  port_items="${port_items%,}]"

  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ok":true,"os":%s,"pkg_manager":"%s","init":"%s","firewall":"%s","ports":%s}\n'       "${os_json}" "${pkg}" "${init}" "${fw}" "${port_items}"
  else
    core::log info "Platform" "${os_json}"
    core::log info "Pkg" "$(printf '{"manager":"%s"}' "${pkg}")"
    core::log info "Init" "$(printf '{"init":"%s"}' "${init}")"
    core::log info "FW"   "$(printf '{"fw":"%s"}' "${fw}")"
    core::log info "Ports" "${port_items}"
  fi
}
main "$@"
