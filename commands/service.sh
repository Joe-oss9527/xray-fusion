#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; . "${HERE}/lib/core.sh"
case "${1-}" in
  setup)   "${HERE}/services/xray/systemd-unit.sh" install ;;
  remove)  "${HERE}/services/xray/systemd-unit.sh" remove  ;;
  *) echo "Usage: xrf service {setup|remove}"; exit 2 ;;
esac
