#!/usr/bin/env bash
topology::context() {
  local port="${XRAY_PORT:-8443}"
  local uuid="${XRAY_UUID:-00000000-0000-0000-0000-000000000000}"
  local sni="${XRAY_REALITY_SNI:-www.microsoft.com}"
  local sid="${XRAY_SHORT_ID:-0123456789abcdef}"
  printf '{"name":"reality-only","xray":{"port":%s,"uuid":"%s","reality_sni":"%s","short_id":"%s"}}\n'     "$port" "$uuid" "$sni" "$sid"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then topology::context; fi
