#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; . "${HERE}/lib/core.sh"; . "${HERE}/services/xray/common.sh"
main(){ core::init "$@"; local ver="unknown"; [[ -x "$(xray::bin)" ]] && ver="$("$(xray::bin)" -version 2>/dev/null | awk 'NR==1{print $2}')"; core::log info "Xray" "$(printf '{"version":"%s","active_confdir":"%s"}' "${ver}" "$(xray::active)")" ; }
main "$@"
