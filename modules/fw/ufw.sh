#!/usr/bin/env bash
fw_ufw::is_available() { command -v ufw >/dev/null 2>&1; }

fw_ufw::open() {
  local rule="$1"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "ufw allow $rule"; return 0
  fi
  sudo ufw allow "$rule"
}

fw_ufw::close() {
  local rule="$1"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "ufw delete allow $rule"; return 0
  fi
  sudo ufw delete allow "$rule"
}

fw_ufw::list() {
  sudo ufw status || true
}
