#!/usr/bin/env bash
# systemd backend
svc_systemd::enable() { sudo systemctl enable "$1"; }
svc_systemd::start()  { sudo systemctl start "$1"; }
svc_systemd::reload() { sudo systemctl reload "$1" || sudo systemctl restart "$1"; }
svc_systemd::status() {
  local name="$1"
  local a s
  a=$(systemctl is-active "$name" 2>/dev/null || true)
  s=$(systemctl show -p SubState --value "$name" 2>/dev/null || true)
  if [[ "$a" == "active" ]]; then
    printf '{"active":true,"sub":"%s"}\n' "${s:-running}"
    return 0
  else
    printf '{"active":false,"sub":"%s"}\n' "${s:-unknown}"
    return 3
  fi
}
svc_systemd::is_healthy() {
  local name="$1"
  systemctl is-active --quiet "$name"
}


svc_systemd::stop()  { sudo systemctl stop "$1" || true; }
