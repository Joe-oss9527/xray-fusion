#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/core.sh"

xray::bin() { echo "${XRF_PREFIX:-/usr/local}/bin/xray"; }

usage() {
cat <<EOF
Usage:
  xrf harden setcap     # set 'cap_net_bind_service=+ep' on xray binary
  xrf harden dropcap    # remove file caps from xray binary
  xrf harden status     # show current file caps
EOF
}

ensure_root_or_sudo() {
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then return 0; fi
  if [[ "$EUID" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    core::log error "require root or sudo"; exit 2
  fi
}

do_setcap() {
  local bin; bin="$(xray::bin)"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "setcap 'cap_net_bind_service=+ep' "$bin""
    return 0
  fi
  ensure_root_or_sudo
  sudo setcap 'cap_net_bind_service=+ep' "$bin" || setcap 'cap_net_bind_service=+ep' "$bin"
}

do_dropcap() {
  local bin; bin="$(xray::bin)"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "setcap -r "$bin""
    return 0
  fi
  ensure_root_or_sudo
  sudo setcap -r "$bin" || setcap -r "$bin"
}

do_status() {
  local bin; bin="$(xray::bin)"
  if command -v getcap >/dev/null 2>&1; then
    getcap "$bin" || true
  else
    echo "getcap not available; install libcap2-bin/libcap"
  fi
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "$sub" in
    setcap) do_setcap ;;
    dropcap) do_dropcap ;;
    status) do_status ;;
    *) usage; exit 2 ;;
  esac
}
main "$@"
