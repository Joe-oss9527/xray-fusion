#!/usr/bin/env bash
# SNI validation for VLESS+REALITY protocol

# Source guard: prevent double-sourcing (readonly variables cannot be re-declared)
[[ -n "${_XRF_SNI_VALIDATOR_LOADED:-}" ]] && return 0
readonly _XRF_SNI_VALIDATOR_LOADED=1

##
# Check if domain supports TLS 1.3
#
# Uses OpenSSL to establish a TLS connection and verify protocol version.
# TLS 1.3 is required for optimal REALITY protocol performance.
#
# Arguments:
#   $1 - Domain name (string, required)
#   $2 - Port (number, optional, default: 443)
#
# Output:
#   TLS version info to stderr (via core::log)
#
# Returns:
#   0 - TLS 1.3 is supported
#   1 - TLS 1.3 is not supported or connection failed
#
# Example:
#   sni::check_tls13 "www.microsoft.com" 443
##
sni::check_tls13() {
  local domain="${1:?domain required}"
  local port="${2:-443}"

  core::log debug "checking TLS 1.3 support" "$(printf '{"domain":"%s","port":%d}' "${domain}" "${port}")"

  # Use OpenSSL to check TLS version
  # -tls1_3: Only allow TLS 1.3
  # -connect: Target host:port
  # -servername: SNI hostname
  # timeout: Prevent hanging on slow connections
  local tls_output
  tls_output=$(timeout 10 openssl s_client \
    -connect "${domain}:${port}" \
    -servername "${domain}" \
    -tls1_3 \
    < /dev/null 2>&1 | grep -E "Protocol|Cipher")

  if [[ "${tls_output}" =~ TLSv1\.3 ]]; then
    core::log debug "TLS 1.3 supported" "$(printf '{"domain":"%s"}' "${domain}")"
    return 0
  else
    core::log warn "TLS 1.3 not supported" "$(printf '{"domain":"%s","output":"%s"}' "${domain}" "${tls_output}")"
    return 1
  fi
}

##
# Check if domain supports HTTP/2
#
# Uses curl to check HTTP/2 support via ALPN negotiation.
# HTTP/2 indicates modern server configuration suitable for REALITY.
#
# Arguments:
#   $1 - Domain name (string, required)
#
# Output:
#   HTTP version info to stderr (via core::log)
#
# Returns:
#   0 - HTTP/2 is supported
#   1 - HTTP/2 is not supported or connection failed
#
# Example:
#   sni::check_http2 "www.microsoft.com"
##
sni::check_http2() {
  local domain="${1:?domain required}"

  core::log debug "checking HTTP/2 support" "$(printf '{"domain":"%s"}' "${domain}")"

  # Check if curl is available
  if ! command -v curl > /dev/null 2>&1; then
    core::log warn "curl not found, skipping HTTP/2 check" "{}"
    return 1
  fi

  # Use curl to check HTTP/2 support
  # --http2: Try HTTP/2
  # -I: HEAD request only
  # -s: Silent mode
  # -S: Show errors
  # --max-time: Timeout
  # -w: Output format (shows HTTP version)
  local http_version
  http_version=$(timeout 10 curl -I -s -S \
    --http2 \
    --max-time 10 \
    -w "%{http_version}\n" \
    -o /dev/null \
    "https://${domain}" 2>&1 | tail -1)

  if [[ "${http_version}" == "2" ]]; then
    core::log debug "HTTP/2 supported" "$(printf '{"domain":"%s"}' "${domain}")"
    return 0
  else
    core::log warn "HTTP/2 not supported" "$(printf '{"domain":"%s","version":"%s"}' "${domain}" "${http_version}")"
    return 1
  fi
}

##
# Check if domain redirects to another host
#
# Uses curl to follow redirects and check if final URL matches original domain.
# Redirects can break REALITY protocol routing.
#
# Arguments:
#   $1 - Domain name (string, required)
#
# Output:
#   Redirect info to stderr (via core::log)
#
# Returns:
#   0 - No redirect or redirect stays on same domain
#   1 - Redirects to different domain
#
# Example:
#   sni::check_redirect "www.microsoft.com"
##
sni::check_redirect() {
  local domain="${1:?domain required}"

  core::log debug "checking for redirects" "$(printf '{"domain":"%s"}' "${domain}")"

  # Check if curl is available
  if ! command -v curl > /dev/null 2>&1; then
    core::log warn "curl not found, skipping redirect check" "{}"
    return 1
  fi

  # Use curl to check for redirects
  # -I: HEAD request only
  # -L: Follow redirects
  # -s: Silent mode
  # -S: Show errors
  # --max-time: Timeout
  # -w: Output final URL
  local final_url
  final_url=$(timeout 10 curl -I -L -s -S \
    --max-time 10 \
    -w "%{url_effective}\n" \
    -o /dev/null \
    "https://${domain}" 2>&1 | tail -1)

  # Extract hostname from final URL
  local final_host
  final_host=$(echo "${final_url}" | sed -E 's|https?://([^/]+).*|\1|')

  # Check if redirect changed domain
  if [[ "${final_host}" == "${domain}" ]] || [[ -z "${final_host}" ]]; then
    core::log debug "no cross-domain redirect" "$(printf '{"domain":"%s"}' "${domain}")"
    return 0
  else
    core::log warn "cross-domain redirect detected" "$(printf '{"original":"%s","final":"%s"}' "${domain}" "${final_host}")"
    return 1
  fi
}

##
# Comprehensive SNI validation
#
# Runs all validation checks (TLS 1.3, HTTP/2, redirect) and returns
# overall result. Suitable for pre-installation validation.
#
# Arguments:
#   $1 - Domain name (string, required)
#   $2 - Port (number, optional, default: 443)
#
# Globals:
#   XRF_JSON - If "true", output JSON format
#
# Output:
#   Validation results to stdout (text or JSON format)
#
# Returns:
#   0 - All checks passed
#   1 - One or more checks failed
#
# Example:
#   sni::validate "www.microsoft.com" 443
##
sni::validate() {
  local domain="${1:?domain required}"
  local port="${2:-443}"

  core::log info "validating SNI" "$(printf '{"domain":"%s","port":%d}' "${domain}" "${port}")"

  # Run all checks
  local tls13_ok=0
  local http2_ok=0
  local redirect_ok=0

  sni::check_tls13 "${domain}" "${port}" && tls13_ok=1 || tls13_ok=0
  sni::check_http2 "${domain}" && http2_ok=1 || http2_ok=0
  sni::check_redirect "${domain}" && redirect_ok=1 || redirect_ok=0

  # Calculate overall result
  local all_passed=0
  if [[ "${tls13_ok}" -eq 1 && "${http2_ok}" -eq 1 && "${redirect_ok}" -eq 1 ]]; then
    all_passed=1
  fi

  # shellcheck disable=SC2154  # XRF_JSON is set by core::init
  if [[ "${XRF_JSON}" == "true" ]]; then
    # JSON format
    local json_output
    json_output=$(
      cat << EOF
{
  "domain": "${domain}",
  "port": ${port},
  "checks": {
    "tls13": $([ "${tls13_ok}" -eq 1 ] && echo "true" || echo "false"),
    "http2": $([ "${http2_ok}" -eq 1 ] && echo "true" || echo "false"),
    "no_redirect": $([ "${redirect_ok}" -eq 1 ] && echo "true" || echo "false")
  },
  "passed": $([ "${all_passed}" -eq 1 ] && echo "true" || echo "false")
}
EOF
    )
    printf '%s\n' "${json_output}"
  else
    # Text format
    printf '\nTesting SNI: %s\n\n' "${domain}"
    printf '  %s TLS 1.3 supported\n' "$([ "${tls13_ok}" -eq 1 ] && echo "✓" || echo "✗")"
    printf '  %s HTTP/2 enabled\n' "$([ "${http2_ok}" -eq 1 ] && echo "✓" || echo "✗")"
    printf '  %s No cross-domain redirects\n' "$([ "${redirect_ok}" -eq 1 ] && echo "✓" || echo "✗")"
    printf '\n'

    if [[ "${all_passed}" -eq 1 ]]; then
      printf 'Domain %s is suitable for REALITY protocol.\n\n' "${domain}"
    else
      printf 'Domain %s has issues. REALITY protocol may not work optimally.\n\n' "${domain}"
    fi
  fi

  # Return overall result
  [[ "${all_passed}" -eq 1 ]]
}
