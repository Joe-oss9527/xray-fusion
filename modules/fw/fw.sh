#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=modules/fw/ufw.sh
. "${HERE}/modules/fw/ufw.sh"
# shellcheck source=modules/fw/firewalld.sh
. "${HERE}/modules/fw/firewalld.sh"

fw::detect() {
  if fw_ufw::is_available; then echo "ufw"; return 0; fi
  if fw_firewalld::is_available; then echo "firewalld"; return 0; fi
  echo "none"; return 1
}

fw::open() {
  local port="$1"/tcp
  case "$(fw::detect)" in
    ufw) fw_ufw::open "${port}" ;;
    firewalld) fw_firewalld::open "${port}" ;;
    *) return 2 ;;
  esac
}

fw::close() {
  local port="$1"/tcp
  case "$(fw::detect)" in
    ufw) fw_ufw::close "${port}" ;;
    firewalld) fw_firewalld::close "${port}" ;;
    *) return 2 ;;
  esac
}

fw::list() {
  case "$(fw::detect)" in
    ufw) fw_ufw::list ;;
    firewalld) fw_firewalld::list ;;
    *) return 2 ;;
  esac
}
