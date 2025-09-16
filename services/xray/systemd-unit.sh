#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; . "${HERE}/lib/core.sh"; . "${HERE}/modules/io.sh"; . "${HERE}/modules/user/user.sh"; . "${HERE}/lib/plugins.sh"
unit_path(){ echo "/etc/systemd/system/xray.service"; }
install_unit(){
  core::init "$@"; user::ensure_system_user xray xray
  local unit_file; unit_file="$(unit_path)"
  io::atomic_write "${unit_file}" 0644 < "${HERE}/packaging/systemd/xray.service"
  systemctl daemon-reload; systemctl enable --now xray || true
  plugins::ensure_dirs; plugins::load_enabled; plugins::emit service_setup "unit=${unit_file}"
  core::log info "systemd unit installed" "$(printf '{"path":"%s"}' "${unit_file}")"
}
remove_unit(){
  core::init "$@"; local unit_file; unit_file="$(unit_path)"
  plugins::ensure_dirs; plugins::load_enabled; plugins::emit service_remove "unit=${unit_file}"
  systemctl disable --now xray || true; rm -f "${unit_file}"; systemctl daemon-reload
  core::log info "systemd unit removed" "{}"
}
case "${1-}" in install) install_unit "$@";; remove) remove_unit "$@";; *) echo "Usage: $0 {install|remove}"; exit 2;; esac
