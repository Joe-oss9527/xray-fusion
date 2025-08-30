#!/usr/bin/env bash
# Package manager dispatcher
# Provides: pkg::detect, pkg::refresh, pkg::ensure <name>
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=modules/pkg/apt.sh
. "${HERE}/modules/pkg/apt.sh"
# shellcheck source=modules/pkg/dnf.sh
. "${HERE}/modules/pkg/dnf.sh"

pkg::detect() {
  if apt_pkg::is_available; then echo "apt"; return 0; fi
  if dnf_pkg::is_available; then echo "dnf"; return 0; fi
  echo "unknown"; return 1
}

pkg::refresh() {
  case "$(pkg::detect)" in
    apt) apt_pkg::refresh ;;
    dnf) dnf_pkg::refresh ;;
    *) return 1 ;;
  esac
}

pkg::ensure() {
  local name="$1"
  case "$(pkg::detect)" in
    apt) apt_pkg::ensure "${name}" ;;
    dnf) dnf_pkg::ensure "${name}" ;;
    *) return 1 ;;
  esac
}
