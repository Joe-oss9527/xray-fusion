#!/usr/bin/env bash
# APT backend
apt_pkg::is_available() { command -v apt-get >/dev/null 2>&1; }

apt_pkg::refresh() {
  sudo apt-get update -y -qq
}

apt_pkg::ensure() {
  local name="$1"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${name}"
}
