#!/usr/bin/env bash
# DNF backend
dnf_pkg::is_available() { command -v dnf >/dev/null 2>&1; }

dnf_pkg::refresh() {
  sudo dnf -y -q makecache || sudo dnf -y -q check-update || true
}

dnf_pkg::ensure() {
  local name="$1"
  sudo dnf install -y -q "${name}"
}
