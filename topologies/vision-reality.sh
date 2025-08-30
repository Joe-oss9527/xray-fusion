#!/usr/bin/env bash
topology::context() {
  local port="${XRAY_PORT:-443}"
  local uuid="${XRAY_UUID:-00000000-0000-0000-0000-000000000000}"
  local domain="${XRAY_DOMAIN:-example.com}"
  local sni="${XRAY_REALITY_SNI:-www.microsoft.com}"
  local sid="${XRAY_SHORT_ID:-0123456789abcdef}"
  printf '{"name":"vision-reality","xray":{"port":%s,"uuid":"%s","domain":"%s","reality_sni":"%s","short_id":"%s"}}\n'     "$port" "$uuid" "$domain" "$sni" "$sid"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then topology::context; fi
