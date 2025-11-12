#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/sni_validator.sh"

usage() {
  cat << 'EOF'
Usage: xrf test-sni <domain> [options]

Test SNI domain suitability for VLESS+REALITY protocol.

Arguments:
  <domain>                      Domain to test (required)

Options:
  --port <port>                 Port to test (default: 443)
  --json                        Output in JSON format
  --help, -h                    Show this help

Checks performed:
  - TLS 1.3 support
  - HTTP/2 support
  - Cross-domain redirect detection

Examples:
  # Test default SNI
  xrf test-sni www.microsoft.com

  # Test with custom port
  xrf test-sni example.com --port 8443

  # JSON output
  xrf test-sni www.cloudflare.com --json

EOF
}

main() {
  core::init "${@}"

  local domain=""
  local port="443"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --port)
        port="${2:-443}"
        shift 2
        ;;
      --json)
        export XRF_JSON="true"
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      -*)
        core::log error "unknown option" "$(printf '{"option":"%s"}' "${1}")"
        usage
        exit 1
        ;;
      *)
        # First positional argument is domain
        if [[ -z "${domain}" ]]; then
          domain="${1}"
        else
          core::log error "unexpected argument" "$(printf '{"arg":"%s"}' "${1}")"
          usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate domain is provided
  if [[ -z "${domain}" ]]; then
    core::log error "domain required" "{}"
    usage
    exit 1
  fi

  # Run validation
  if sni::validate "${domain}" "${port}"; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
