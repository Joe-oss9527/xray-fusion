#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; . "${HERE}/lib/core.sh"; . "${HERE}/lib/plugins.sh"; . "${HERE}/services/xray/common.sh"
_rm(){ local p="$1"; [[ -e "$p" || -L "$p" ]] && { echo "rm -rf $p"; rm -rf "$p" || true; } }
main(){ core::init "$@"; plugins::ensure_dirs; plugins::load_enabled; plugins::emit uninstall_pre
  systemctl disable --now xray 2>/dev/null || true
  _rm "$(xray::prefix)/bin/xray"; _rm "$(xray::confbase)"
  plugins::emit uninstall_post
  echo "Uninstalled."; }
main "$@"
