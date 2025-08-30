#!/usr/bin/env bash
# Client links generation for xray-fusion
# Generates vless:// URLs for Reality and Vision protocols

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "${HERE}/lib/core.sh"
source "${HERE}/modules/state.sh"
source "${HERE}/modules/net/network.sh"

# Generate client links based on topology
generate_links() {
  core::init "$@"
  
  local topology uuid short_id reality_pubkey domain server_ip port sni
  
  # Use environment variables if available (during installation), otherwise use state file
  if [[ -n "${XRAY_PORT:-}" ]] && [[ -n "${XRAY_UUID:-}" ]]; then
    # Use current environment (installation in progress)
    topology="${1:-reality-only}"
    port="${XRAY_PORT}"
    uuid="${XRAY_UUID}"
    reality_pubkey="${XRAY_PUBLIC_KEY:-}"
    short_id="${XRAY_SHORT_ID:-}"
    sni="${XRAY_REALITY_SNI:-www.microsoft.com}"
    domain="${XRAY_DOMAIN:-}"
  else
    # Use state file (post-installation)
    local state_json
    state_json="$(state::load)"
    
    if [[ "${state_json}" == "{}" ]]; then
      core::log error "No installation state found" "{}"
      return 1
    fi
    
    topology="$(echo "${state_json}" | jq -r '.topology // "reality-only"')"
    uuid="$(echo "${state_json}" | jq -r '.xray.uuid // empty')"
    short_id="$(echo "${state_json}" | jq -r '.xray.short_id // empty')"
    reality_pubkey="$(echo "${state_json}" | jq -r '.xray.reality_public_key // empty')"
    domain="$(echo "${state_json}" | jq -r '.xray.domain // empty')"
    port="$(echo "${state_json}" | jq -r '.xray.port // "8443"')"
    sni="$(echo "${state_json}" | jq -r '.xray.reality_sni // "www.microsoft.com"')"
  fi
  
  # Auto-detect server IP if not available
  if [[ -n "${state_json:-}" ]]; then
    server_ip="$(echo "${state_json}" | jq -r '.server_ip // empty')"
  else
    server_ip=""
  fi
  
  if [[ -z "${server_ip}" ]]; then
    server_ip="$(net::detect_public_ip)"
    if [[ -z "${server_ip}" ]]; then
      core::log warn "Cannot auto-detect public IP" "{}"
      server_ip="YOUR_SERVER_IP"
    else
      core::log info "Auto-detected server IP" "$(printf '{"ip":"%s"}' "${server_ip}")"
    fi
  fi
  
  # Use first SNI from comma-separated list
  local sni_first="${sni%%,*}"
  
  echo "========== LINKS =========="
  
  case "${topology}" in
    "vision-reality")
      if [[ -n "${domain}" && -n "${uuid}" ]]; then
        local vision_link="vless://${uuid}@${domain}:443?security=tls&flow=xtls-rprx-vision&sni=${domain}&fp=chrome#Vision-${domain}"
        echo "VISION : ${vision_link}"
        
        # Generate QR code if qrencode is available
        if command -v qrencode >/dev/null 2>&1; then
          echo "----- Vision QR -----"
          echo "${vision_link}" | qrencode -t ansiutf8 || true
        fi
      fi
      
      if [[ -n "${server_ip}" && -n "${uuid}" && -n "${reality_pubkey}" && -n "${short_id}" ]]; then
        local reality_link="vless://${uuid}@${server_ip}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni_first}&fp=chrome&pbk=${reality_pubkey}&sid=${short_id}&spx=%2F#REALITY-${server_ip}"
        echo "REALITY: ${reality_link}"
        
        if command -v qrencode >/dev/null 2>&1; then
          echo "----- Reality QR -----"
          echo "${reality_link}" | qrencode -t ansiutf8 || true
        fi
      fi
      ;;
      
    "reality-only")
      if [[ -n "${server_ip}" && -n "${uuid}" && -n "${reality_pubkey}" && -n "${short_id}" ]]; then
        local reality_link="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni_first}&fp=chrome&pbk=${reality_pubkey}&sid=${short_id}&spx=%2F#REALITY-${server_ip}"
        echo "REALITY: ${reality_link}"
        
        if command -v qrencode >/dev/null 2>&1; then
          echo "----- Reality QR -----" 
          echo "${reality_link}" | qrencode -t ansiutf8 || true
        fi
      else
        # In dry run mode or when pubkey is placeholder, show informational message instead of error
        if [[ "${XRF_DRY_RUN:-false}" == "true" ]] || [[ "${reality_pubkey}" == "fake_public_key_for_preview" ]]; then
          echo "REALITY: vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni_first}&fp=chrome&pbk=[REALITY_PUBLIC_KEY]&sid=${short_id}&spx=%2F#REALITY-${server_ip}"
          echo "Note: Actual Reality public key will be generated during real installation"
        else
          core::log error "Missing required parameters for Reality link generation" "$(printf '{"server_ip":"%s","uuid":"%s","pubkey":"%s","short_id":"%s"}' "${server_ip}" "${uuid}" "${reality_pubkey}" "${short_id}")"
          return 1
        fi
      fi
      ;;
      
    *)
      core::log error "Unknown topology" "$(printf '{"topology":"%s"}' "${topology}")"
      return 1
      ;;
  esac
  
  echo "=========================="
  
  # Show usage instructions
  echo ""
  echo "Copy the link above to your Xray client configuration."
  if ! command -v qrencode >/dev/null 2>&1; then
    echo "Tip: Install 'qrencode' package to display QR codes."
  fi
}

main() {
  core::init "$@"
  generate_links "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi