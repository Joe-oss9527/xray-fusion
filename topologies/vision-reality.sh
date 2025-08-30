#!/usr/bin/env bash
topology::context() {
  # All variables should be set by install.sh before calling this function
  local vision_port="${XRAY_VISION_PORT:?XRAY_VISION_PORT must be set}"
  local reality_port="${XRAY_REALITY_PORT:?XRAY_REALITY_PORT must be set}"
  local uuid_vision="${XRAY_UUID_VISION:?XRAY_UUID_VISION must be set}"
  local uuid_reality="${XRAY_UUID_REALITY:?XRAY_UUID_REALITY must be set}"
  local domain="${XRAY_DOMAIN:?XRAY_DOMAIN must be set}"
  local sni="${XRAY_REALITY_SNI:?XRAY_REALITY_SNI must be set}"
  local sid="${XRAY_SHORT_ID:?XRAY_SHORT_ID must be set}"
  local pubkey="${XRAY_PUBLIC_KEY:-}"
  printf '{"name":"vision-reality","xray":{"vision_port":%s,"reality_port":%s,"uuid_vision":"%s","uuid_reality":"%s","domain":"%s","reality_sni":"%s","short_id":"%s","reality_public_key":"%s"}}\n' "${vision_port}" "${reality_port}" "${uuid_vision}" "${uuid_reality}" "${domain}" "${sni}" "${sid}" "${pubkey}"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then topology::context; fi
