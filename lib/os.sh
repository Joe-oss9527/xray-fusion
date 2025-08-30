#!/usr/bin/env bash
os::detect() {
  local id=unknown version_id=unknown arch selinux=false
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-unknown}"
    version_id="${VERSION_ID:-unknown}"
  fi
  arch="$(uname -m)"
  if command -v getenforce >/dev/null 2>&1; then
    [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]] && selinux=true
  fi
  printf '{"id":"%s","version_id":"%s","arch":"%s","selinux":%s}\n'     "$id" "$version_id" "$arch" "$selinux"
}
