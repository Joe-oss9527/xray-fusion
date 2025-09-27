#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; . "${HERE}/lib/core.sh"; . "${HERE}/lib/plugins.sh"
usage(){ cat <<EOF
Usage:
  xrf plugin list
  xrf plugin enable <id>
  xrf plugin disable <id>
  xrf plugin info <id>
Env:
  XRF_PLUGINS=/usr/local/lib/xrf/plugins
EOF
}
main(){ core::init "${@}"; plugins::ensure_dirs; local sub="${1-}"; shift||true
  case "${sub}" in
    list) plugins::list ;;
    enable) plugins::enable "${1:?id required}" ;;
    disable) plugins::disable "${1:?id required}" ;;
    info) plugins::info "${1:?id required}" ;;
    *) usage; exit 2 ;;
  esac
}
main "${@}"
