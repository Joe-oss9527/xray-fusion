#!/usr/bin/env bash
# Network utilities module
# Provides generic network detection and diagnostics functions

set -euo pipefail

# Auto-detect public IPv4 address using multiple methods
net::detect_public_ip() {
  local ip=""
  
  # Method 1: OpenDNS resolver
  ip="$(timeout 3 dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | awk 'NR==1')" || true
  
  # Method 2: Cloudflare TXT record
  if [[ -z "${ip}" ]]; then
    ip="$(timeout 3 dig +short whoami.cloudflare @1.1.1.1 txt 2>/dev/null | tr -d '\"' | awk 'NR==1' || true)"
  fi
  
  # Method 3: ipify.org API
  if [[ -z "${ip}" ]]; then
    ip="$(timeout 3 curl -4fsS https://api.ipify.org 2>/dev/null || true)"
  fi
  
  # Method 4: ifconfig.co API  
  if [[ -z "${ip}" ]]; then
    ip="$(timeout 3 curl -4fsS https://ifconfig.co 2>/dev/null || true)"
  fi
  
  # Fallback: Local interface IP via routing table
  if [[ -z "${ip}" ]]; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if (${i}=="src") print $(i+1)}' | head -n1 || true)"
  fi
  
  echo "${ip}"
}

# Validate if an IP address is properly formatted IPv4
net::is_valid_ipv4() {
  local ip="$1"
  local IFS='.'
  local -a octets
  read -ra octets <<< "${ip}"
  
  # Must have exactly 4 octets
  if [[ ${#octets[@]} -ne 4 ]]; then
    return 1
  fi
  
  # Each octet must be 0-255
  for octet in "${octets[@]}"; do
    if ! [[ "${octet}" =~ ^[0-9]+$ ]] || [[ "${octet}" -lt 0 ]] || [[ "${octet}" -gt 255 ]]; then
      return 1
    fi
    
    # No leading zeros (except for single digit 0)
    if [[ "${octet}" =~ ^0[0-9]+ ]]; then
      return 1
    fi
  done
  
  return 0
}

# Check if a hostname/domain is resolvable
net::is_resolvable() {
  local hostname="$1"
  timeout 3 dig +short "${hostname}" >/dev/null 2>&1
}

# Get the primary network interface
net::get_primary_interface() {
  ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for (i=1;i<=NF;i++) if (${i}=="dev") print $(i+1)}' | head -n1 || true
}