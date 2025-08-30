#!/usr/bin/env bash
# Install/remove systemd unit for Xray
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/os.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/svc/systemd.sh"
. "${HERE}/modules/user/user.sh"

unit_path() { echo "/etc/systemd/system/xray.service"; }

install_unit() {
  # Create dedicated xray user for security
  user::ensure_system_user "xray" "xray" "/var/lib/xray" "/usr/sbin/nologin" "Xray proxy service user"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    local unit_file
    unit_file="$(unit_path)"
    core::log info "Plan systemd unit install" "$(printf '{"path":"%s","user":"xray","group":"xray"}' "${unit_file}")"
    sed -e 's/User=nobody/User=xray/' -e 's/Group=nogroup/Group=xray/' "${HERE}/packaging/systemd/xray.service"
    return 0
  fi
  
  # Generate unit file with dedicated xray user
  local unit_file
  unit_file="$(unit_path)"
  sed -e 's/User=nobody/User=xray/' -e 's/Group=nogroup/Group=xray/' "${HERE}/packaging/systemd/xray.service" | \
    io::atomic_write "${unit_file}" 0644
  
  sudo systemctl daemon-reload
  svc_systemd::enable xray || true
  svc_systemd::start xray || true
  local unit_file
  unit_file="$(unit_path)"
  core::log info "systemd unit installed" "$(printf '{"path":"%s","user":"xray","group":"xray"}' "${unit_file}")"
}

remove_unit() {
  local remove_user="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge-user) remove_user="true"; shift ;;
      *) shift ;;
    esac
  done
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    local unit_file
    unit_file="$(unit_path)"
    core::log info "Plan systemd unit removal" "$(printf '{"path":"%s","remove_user":"%s"}' "${unit_file}" "${remove_user}")"
    if [[ "${remove_user}" == "true" ]]; then
      core::log info "Plan remove xray user" '{"user":"xray","group":"xray"}'
    fi
    return 0
  fi
  
  # Check if service exists before attempting to disable
  if systemctl list-unit-files "xray.service" --quiet >/dev/null 2>&1; then
    sudo systemctl disable --now xray
  fi
  local unit_file
  unit_file="$(unit_path)"
  sudo rm -f "${unit_file}"
  sudo systemctl daemon-reload
  core::log info "systemd unit removed" "{}"
  
  # Optionally remove dedicated user (useful for complete uninstall)
  if [[ "${remove_user}" == "true" ]]; then
    user::remove_system_user "xray" "true"
  fi
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "${sub}" in
    install) install_unit ;;
    remove)  remove_unit "$@" ;;
    *) echo "Usage: $0 {install|remove [--purge-user]}"; exit 2 ;;
  esac
}
main "$@"
