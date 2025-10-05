#!/usr/bin/env bash
# Unified argument parsing module for xray-fusion
# Provides consistent parameter interface for both install.sh and xrf commands

# Initialize default values
args::init() {
  TOPOLOGY="reality-only"
  DOMAIN=""
  VERSION="latest"
  PLUGINS=""
  DEBUG="false"
}

# Parse command line arguments
args::parse() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --topology | -t)
        args::validate_topology "${2:-}" || return 1
        TOPOLOGY="${2}"
        shift 2
        ;;
      --domain | -d)
        args::validate_domain "${2:-}" || return 1
        DOMAIN="${2}"
        shift 2
        ;;
      --version | -v)
        args::validate_version "${2:-}" || return 1
        VERSION="${2}"
        shift 2
        ;;
      --plugins | -p)
        PLUGINS="${2:-}"
        shift 2
        ;;
      --debug)
        DEBUG="true"
        shift
        ;;
      --help | -h)
        return 10 # Special return code for help
        ;;
      --)
        shift
        break
        ;;
      *)
        core::log error "unknown argument" "$(printf '{"arg":"%s"}' "${1}")"
        return 1
        ;;
    esac
  done

  # Validate configuration
  args::validate_config || return 1

  # Export variables for use by other modules
  export TOPOLOGY DOMAIN VERSION PLUGINS DEBUG

  return 0
}

# Topology validation
args::validate_topology() {
  local topology="${1:-}"
  if [[ -z "${topology}" ]]; then
    core::log error "topology cannot be empty" "{}"
    return 1
  fi

  case "${topology}" in
    reality-only | vision-reality)
      return 0
      ;;
    *)
      core::log error "invalid topology" "$(printf '{"topology":"%s","valid":"reality-only,vision-reality"}' "${topology}")"
      return 1
      ;;
  esac
}

# Domain validation
args::validate_domain() {
  local domain="${1:-}"
  if [[ -z "${domain}" ]]; then
    return 0 # Domain is optional for reality-only
  fi

  # Basic domain validation (RFC compliant)
  if [[ ! "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    core::log error "invalid domain format" "$(printf '{"domain":"%s"}' "${domain}")"
    return 1
  fi

  # Prevent localhost and internal domains
  case "${domain}" in
    localhost | *.local | 127.* | 10.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].* | 192.168.*)
      core::log error "internal domain not allowed" "$(printf '{"domain":"%s"}' "${domain}")"
      return 1
      ;;
  esac

  return 0
}

# Version validation
args::validate_version() {
  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    core::log error "version cannot be empty" "{}"
    return 1
  fi

  # Allow 'latest' or semantic version format
  if [[ "${version}" == "latest" ]]; then
    return 0
  fi

  if [[ ! "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    core::log error "invalid version format" "$(printf '{"version":"%s","format":"vX.Y.Z or latest"}' "${version}")"
    return 1
  fi

  return 0
}

# Configuration validation
args::validate_config() {
  # vision-reality topology requires domain
  if [[ "${TOPOLOGY}" == "vision-reality" && -z "${DOMAIN}" ]]; then
    core::log error "vision-reality topology requires domain" "$(printf '{"topology":"%s"}' "${TOPOLOGY}")"
    return 1
  fi

  return 0
}

# Show help for common arguments
args::show_help() {
  cat << EOF
Options:
  --topology, -t <type>         Installation topology (reality-only|vision-reality)
  --domain, -d <domain>         Domain for vision-reality topology (required)
  --version, -v <version>       Xray version to install (default: latest)
  --plugins, -p <list>          Comma-separated list of plugins to enable
  --debug                       Enable debug output
  --help, -h                    Show this help

Examples:
  # Reality-only topology
  --topology reality-only

  # Vision-Reality with domain and plugins
  --topology vision-reality --domain your.domain.com --plugins cert-auto

  # Specific version
  --version v1.8.1

EOF
}

# Show current configuration (debug helper)
args::show_config() {
  if [[ "${DEBUG}" == "true" ]]; then
    core::log debug "parsed arguments" "$(printf '{"topology":"%s","domain":"%s","version":"%s","plugins":"%s","debug":"%s"}' \
      "${TOPOLOGY}" "${DOMAIN}" "${VERSION}" "${PLUGINS}" "${DEBUG}")"
  fi
}

# Export parsed arguments as environment variables
args::export_vars() {
  # Set XRAY_DOMAIN for Xray configuration
  if [[ -n "${DOMAIN}" ]]; then
    export XRAY_DOMAIN="${DOMAIN}"
  fi

  # Set XRF_DEBUG for core module
  export XRF_DEBUG="${DEBUG}"
}
