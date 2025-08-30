#!/usr/bin/env bash
# openrc backend
svc_openrc::enable() { sudo rc-update add "$1" default || true; }
svc_openrc::start()  { sudo rc-service "$1" start || true; }
svc_openrc::reload() { sudo rc-service "$1" reload || sudo rc-service "$1" restart || true; }
svc_openrc::status() {
  local name="$1"
  if rc-service "${name}" status >/dev/null 2>&1; then
    echo '{"active":true,"sub":"running"}'; return 0
  else
    echo '{"active":false,"sub":"stopped"}'; return 3
  fi
}
svc_openrc::is_healthy() { rc-service "$1" status >/dev/null 2>&1; }
svc_openrc::stop() { sudo rc-service "$1" stop || true; }
