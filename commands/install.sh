#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/pkg/pkg.sh"

usage() {
cat <<EOF
Usage: xrf install [--version vX.Y.Z|latest] [--topology reality-only] [--dry]
Environment:
  XRF_PREFIX=/usr/local       # install prefix
  XRF_ETC=/usr/local/etc      # config dir base
  XRF_VAR=/var/lib/xray-fusion
  XRF_DRY_RUN=true|false
EOF
}

HERE2="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE2/topologies/reality-only.sh"
. "$HERE2/topologies/vision-reality.sh"
. "$HERE2/modules/state.sh"
main() {
  core::init "$@"
  local version="latest" topology="reality-only"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) version="$2"; shift 2 ;;
      --topology) topology="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) shift ;;
    esac
  done

  # Ensure runtime deps (dry-run prints plan)
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan deps" '{"apt":["curl","unzip","jq","gettext-base"],"dnf":["curl","unzip","jq","gettext"]}'
  else
    if [[ "$(pkg::detect)" == "apt" ]]; then
      pkg::refresh || true
      pkg::ensure curl; pkg::ensure unzip; pkg::ensure jq; pkg::ensure gettext-base
    elif [[ "$(pkg::detect)" == "dnf" ]]; then
      pkg::refresh || true
      pkg::ensure curl; pkg::ensure unzip; pkg::ensure jq; pkg::ensure gettext
    fi
  fi

  "$HERE/services/xray/install.sh" --version "$version"
  XRAY_PORT="${XRAY_PORT:-8443}" XRAY_UUID="${XRAY_UUID:-00000000-0000-0000-0000-000000000000}"   XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}" XRAY_SHORT_ID="${XRAY_SHORT_ID:-0123456789abcdef}"   "$HERE/services/xray/configure.sh"
  local ver="unknown"
  if command -v "$XRF_PREFIX/bin/xray" >/dev/null 2>&1; then
    ver=$("$XRF_PREFIX/bin/xray" -version 2>/dev/null | head -n1 | awk '{print $2}')
  fi
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local state; state=$(jq -n --arg topo "$topology" --arg ver "$ver" --argjson ctx "$ctx" --arg ts "$now" '{topology:$topo, version:$ver, installed_at:$ts} + $ctx')
  state::save "$state"
}

main "$@"
