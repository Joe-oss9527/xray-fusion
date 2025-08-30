#!/usr/bin/env bash
# Install/remove systemd unit for Xray
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/io.sh"
. "$HERE/modules/svc/systemd.sh"

unit_path() { echo "/etc/systemd/system/xray.service"; }

install_unit() {
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan systemd unit install" "$(printf '{"path":"%s"}' "$(unit_path)")"
    sed -n '1,80p' "$HERE/packaging/systemd/xray.service"
    return 0
  fi
  io::atomic_write "$(unit_path)" 0644 < "$HERE/packaging/systemd/xray.service"
  sudo systemctl daemon-reload
  svc_systemd::enable xray || true
  svc_systemd::start xray || true
  core::log info "systemd unit installed" "$(printf '{"path":"%s"}' "$(unit_path)")"
}

remove_unit() {
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan systemd unit removal" "$(printf '{"path":"%s"}' "$(unit_path)")"
    return 0
  fi
  sudo systemctl disable --now xray || true
  sudo rm -f "$(unit_path)"
  sudo systemctl daemon-reload
  core::log info "systemd unit removed" "{}"
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "$sub" in
    install) install_unit ;;
    remove)  remove_unit ;;
    *) echo "Usage: $0 {install|remove}"; exit 2 ;;
  esac
}
main "$@"
