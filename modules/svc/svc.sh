#!/usr/bin/env bash
# Service manager dispatcher
SVC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SVC_DIR}/systemd.sh"
. "${SVC_DIR}/openrc.sh"
svc::detect() {
  if command -v systemctl >/dev/null 2>&1; then echo "systemd"; return 0; fi
  if command -v rc-service >/dev/null 2>&1; then echo "openrc"; return 0; fi
  echo "unknown"; return 1
}

svc::enable() {
  case "$(svc::detect)" in
    systemd) svc_systemd::enable "$@" ;;
    openrc)  svc_openrc::enable "$@" ;;
    *) return 1 ;;
  esac
}

svc::start() {
  case "$(svc::detect)" in
    systemd) svc_systemd::start "$@" ;;
    openrc)  svc_openrc::start "$@" ;;
    *) return 1 ;;
  esac
}

svc::reload() {
  case "$(svc::detect)" in
    systemd) svc_systemd::reload "$@" ;;
    openrc)  svc_openrc::reload "$@" ;;
    *) return 1 ;;
  esac
}

svc::status() {
  case "$(svc::detect)" in
    systemd) svc_systemd::status "$@" ;;
    openrc)  svc_openrc::status "$@" ;;
    *) echo '{"active":false,"reason":"unknown-init"}'; return 1 ;;
  esac
}

svc::is_healthy() {
  case "$(svc::detect)" in
    systemd) svc_systemd::is_healthy "$@" ;;
    openrc)  svc_openrc::is_healthy "$@" ;;
    *) return 1 ;;
  esac
}


svc::stop() {
  case "$(svc::detect)" in
    systemd) svc_systemd::stop "$@" ;;
    openrc)  svc_openrc::stop "$@" ;;
    *) return 1 ;;
  esac
}
