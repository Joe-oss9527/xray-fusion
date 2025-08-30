#!/usr/bin/env bash
fw_firewalld::is_available() { command -v firewall-cmd >/dev/null 2>&1; }

fw_firewalld::open() {
  local rule="$1"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "firewall-cmd --permanent --add-port=${rule}"; return 0
  fi
  sudo firewall-cmd --permanent --add-port="${rule}"
  sudo firewall-cmd --reload
}

fw_firewalld::close() {
  local rule="$1"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "firewall-cmd --permanent --remove-port=${rule}"; return 0
  fi
  sudo firewall-cmd --permanent --remove-port="${rule}"
  sudo firewall-cmd --reload
}

fw_firewalld::list() {
  sudo firewall-cmd --list-all || true
}
