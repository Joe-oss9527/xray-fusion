#!/usr/bin/env bash
topology::context() {
  # All variables should be set by install.sh before calling this function
  local port="${XRAY_PORT:?XRAY_PORT must be set}"
  local uuid="${XRAY_UUID:?XRAY_UUID must be set}" 
  local sni="${XRAY_REALITY_SNI:?XRAY_REALITY_SNI must be set}"
  local sid="${XRAY_SHORT_ID:?XRAY_SHORT_ID must be set}"
  local pubkey="${XRAY_PUBLIC_KEY:-}"
  printf '{"name":"reality-only","xray":{"port":%s,"uuid":"%s","reality_sni":"%s","short_id":"%s","reality_public_key":"%s"}}\n' "${port}" "${uuid}" "${sni}" "${sid}" "${pubkey}"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then topology::context; fi
