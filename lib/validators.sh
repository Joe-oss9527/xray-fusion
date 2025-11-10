#!/usr/bin/env bash
# Input validation utilities
# Provides RFC-compliant validators for domains, ports, UUIDs, and other inputs
# NOTE: This file is sourced. Strict mode is set by the calling script or core::init()

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/core.sh
. "${HERE}/lib/core.sh"

# Domain validation (RFC 1035 compliant)
# Validates:
# - RFC compliant format (alphanumeric + hyphens)
# - Total length <= 253 characters (DNS limit)
# - Each label <= 63 characters
# - No leading/trailing hyphens in labels
# - Rejects internal/private domains
validators::domain() {
  local domain="${1:-}"

  # Empty check
  if [[ -z "${domain}" ]]; then
    core::log debug "domain validation failed: empty" "{}"
    return 1
  fi

  # Length check (DNS specification: total length <= 253)
  if [[ ${#domain} -gt 253 ]]; then
    core::log debug "domain validation failed: length exceeds 253" "$(printf '{"domain":"%s","length":%d}' "${domain}" ${#domain})"
    return 1
  fi

  # Check each label length (DNS specification: label <= 63)
  local IFS='.'
  local labels
  read -ra labels <<< "$domain"
  for label in "${labels[@]}"; do
    if [[ ${#label} -gt 63 ]]; then
      core::log debug "domain validation failed: label exceeds 63" "$(printf '{"label":"%s","length":%d}' "${label}" ${#label})"
      return 1
    fi
  done

  # RFC 1035 compliant regex
  # - Labels must start and end with alphanumeric
  # - Labels can contain hyphens in the middle
  # - Labels are separated by dots
  if [[ ! "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    core::log debug "domain validation failed: RFC format" "$(printf '{"domain":"%s"}' "${domain}")"
    return 1
  fi

  # Reject internal/private domains
  case "${domain}" in
    localhost | *.local | 127.* | 10.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].* | 192.168.*)
      core::log debug "domain validation failed: internal domain" "$(printf '{"domain":"%s"}' "${domain}")"
      return 1
      ;;
  esac

  return 0
}

# Port validation
# Validates port number is in range 1-65535
validators::port() {
  local port="${1:-}"

  # Empty check
  if [[ -z "${port}" ]]; then
    core::log debug "port validation failed: empty" "{}"
    return 1
  fi

  # Numeric check
  if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
    core::log debug "port validation failed: not numeric" "$(printf '{"port":"%s"}' "${port}")"
    return 1
  fi

  # Range check (1-65535)
  if [[ "${port}" -lt 1 || "${port}" -gt 65535 ]]; then
    core::log debug "port validation failed: out of range" "$(printf '{"port":%s,"valid_range":"1-65535"}' "${port}")"
    return 1
  fi

  return 0
}

# UUID validation (UUIDv4 format)
# Format: 8-4-4-4-12 hexadecimal digits
validators::uuid() {
  local uuid="${1:-}"

  # Empty check
  if [[ -z "${uuid}" ]]; then
    core::log debug "uuid validation failed: empty" "{}"
    return 1
  fi

  # UUIDv4 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  if [[ ! "${uuid}" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    core::log debug "uuid validation failed: invalid format" "$(printf '{"uuid":"%s"}' "${uuid}")"
    return 1
  fi

  return 0
}

# shortId validation (Xray Reality protocol)
# Requirements:
# - Hexadecimal characters only
# - Even length (2, 4, 6, 8, 10, 12, 14, 16)
# - Maximum 16 characters
# - Empty string is valid (part of shortIds pool)
validators::shortid() {
  local sid="${1:-}"

  # Empty is valid (part of the pool)
  if [[ -z "${sid}" ]]; then
    return 0
  fi

  # Length check (<= 16)
  if [[ ${#sid} -gt 16 ]]; then
    core::log debug "shortid validation failed: exceeds 16 chars" "$(printf '{"shortid":"%s","length":%d}' "${sid}" ${#sid})"
    return 1
  fi

  # Even length check
  if [[ $((${#sid} % 2)) -ne 0 ]]; then
    core::log debug "shortid validation failed: odd length" "$(printf '{"shortid":"%s","length":%d}' "${sid}" ${#sid})"
    return 1
  fi

  # Hexadecimal check
  if [[ ! "${sid}" =~ ^[0-9a-fA-F]+$ ]]; then
    core::log debug "shortid validation failed: not hexadecimal" "$(printf '{"shortid":"%s"}' "${sid}")"
    return 1
  fi

  return 0
}

# Version validation
# Accepts: 'latest' or semantic version 'vX.Y.Z' or 'X.Y.Z'
validators::version() {
  local version="${1:-}"

  # Empty check
  if [[ -z "${version}" ]]; then
    core::log debug "version validation failed: empty" "{}"
    return 1
  fi

  # Accept 'latest'
  if [[ "${version}" == "latest" ]]; then
    return 0
  fi

  # Semantic version format: vX.Y.Z or X.Y.Z
  if [[ ! "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    core::log debug "version validation failed: invalid format" "$(printf '{"version":"%s","expected":"vX.Y.Z or latest"}' "${version}")"
    return 1
  fi

  return 0
}
