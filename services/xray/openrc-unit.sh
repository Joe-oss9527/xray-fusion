#!/usr/bin/env bash
# Install/remove OpenRC init script
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/io.sh"

initd_path() { echo "/etc/init.d/xray"; }

install_openrc() {
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan OpenRC install" "$(printf '{"path":"%s"}' "$(initd_path)")"
    sed -n '1,80p' "$HERE/packaging/openrc/xray"
    return 0
  fi
  io::atomic_write "$(initd_path)" 0755 < "$HERE/packaging/openrc/xray"
  sudo rc-update add xray default || true
  core::log info "OpenRC unit installed" "$(printf '{"path":"%s"}' "$(initd_path)")"
}

remove_openrc() {
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan OpenRC removal" "$(printf '{"path":"%s"}' "$(initd_path)")"
    return 0
  fi
  sudo rc-update del xray default || true
  sudo rm -f "$(initd_path)"
  core::log info "OpenRC unit removed" "{}"
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "$sub" in
    install) install_openrc ;;
    remove)  remove_openrc ;;
    *) echo "Usage: $0 {install|remove}"; exit 2 ;;
  esac
}
main "$@"
