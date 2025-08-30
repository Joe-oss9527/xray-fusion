#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/svc/svc.sh"

usage() {
# Auto-detects init system (systemd/OpenRC) and installs respective unit

cat <<EOF
Usage:
  xrf service setup         # install and enable the service (systemd)
  xrf service remove        # disable and remove the service
EOF
}
main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "${sub}" in
    setup)
      if command -v systemctl >/dev/null 2>&1; then "${HERE}/services/xray/systemd-unit.sh" install;
      elif command -v rc-service >/dev/null 2>&1; then "${HERE}/services/xray/openrc-unit.sh" install;
      else core::log error "unknown init"; exit 2; fi ;;
    remove)
      if command -v systemctl >/dev/null 2>&1; then "${HERE}/services/xray/systemd-unit.sh" remove;
      elif command -v rc-service >/dev/null 2>&1; then "${HERE}/services/xray/openrc-unit.sh" remove;
      else core::log error "unknown init"; exit 2; fi ;;
    *) usage; exit 2 ;;
  esac
}
main "$@"
