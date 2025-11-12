#!/usr/bin/env bash
# Installation preview and confirmation

# Source guard: prevent double-sourcing (readonly variables cannot be re-declared)
[[ -n "${_XRF_PREVIEW_LOADED:-}" ]] && return 0
readonly _XRF_PREVIEW_LOADED=1

# Load defaults (needed for port defaults)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/defaults.sh
. "${HERE}/lib/defaults.sh"

##
# Display installation configuration preview
#
# Shows a comprehensive summary of the installation configuration
# before proceeding with actual installation. Supports both text
# and JSON output formats.
#
# Arguments:
#   None (reads from environment variables)
#
# Globals:
#   TOPOLOGY - Installation topology (required)
#   VERSION - Xray version (required)
#   XRAY_DOMAIN - Domain name (required for vision-reality)
#   XRAY_PORT - Reality port (reality-only)
#   XRAY_VISION_PORT - Vision port (vision-reality)
#   XRAY_REALITY_PORT - Reality port (vision-reality)
#   XRAY_FALLBACK_PORT - Fallback port (vision-reality)
#   PLUGINS - Comma-separated plugin list (optional)
#   XRF_JSON - If "true", output JSON format
#
# Output:
#   Configuration preview to stdout (text or JSON format)
#
# Returns:
#   0 - Always succeeds
#
# Example:
#   preview::show
##
preview::show() {
  # shellcheck disable=SC2154  # TOPOLOGY, VERSION, PLUGINS, XRAY_DOMAIN set by args::parse()
  local topology="${TOPOLOGY}"
  # shellcheck disable=SC2154
  local version="${VERSION}"
  # shellcheck disable=SC2154
  local domain="${XRAY_DOMAIN:-N/A}"
  # shellcheck disable=SC2154
  local plugins="${PLUGINS:-none}"

  # Determine ports based on topology (use defaults from lib/defaults.sh)
  local ports=""
  if [[ "${topology}" == "vision-reality" ]]; then
    # shellcheck disable=SC2154  # XRAY_* variables are optionally set by user or use defaults
    local vision_port="${XRAY_VISION_PORT:-${DEFAULT_XRAY_VISION_PORT}}"
    local reality_port="${XRAY_REALITY_PORT:-${DEFAULT_XRAY_REALITY_PORT}}"
    local fallback_port="${XRAY_FALLBACK_PORT:-${DEFAULT_XRAY_FALLBACK_PORT}}"
    ports="${reality_port} (Reality), ${vision_port} (Vision), ${fallback_port} (Caddy)"
  else
    # shellcheck disable=SC2154  # XRAY_PORT is optionally set by user or uses default
    local xray_port="${XRAY_PORT:-${DEFAULT_XRAY_PORT}}"
    ports="${xray_port} (Reality)"
  fi

  # shellcheck disable=SC2154  # XRF_JSON is set by core::init
  if [[ "${XRF_JSON}" == "true" ]]; then
    # JSON format
    local json_output
    json_output=$(
      cat << EOF
{
  "preview": {
    "topology": "${topology}",
    "version": "${version}",
    "domain": "${domain}",
    "ports": "${ports}",
    "plugins": "${plugins}"
  }
}
EOF
    )
    printf '%s\n' "${json_output}"
  else
    # Text format
    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                   Installation Preview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Topology:    ${topology}
  Xray:        ${version}
EOF

    # Only show domain for vision-reality
    if [[ "${topology}" == "vision-reality" ]]; then
      printf "  Domain:      %s\n" "${domain}"
    fi

    cat << EOF
  Ports:       ${ports}
  Plugins:     ${plugins}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
  fi
}

##
# Prompt user for installation confirmation
#
# Displays a confirmation prompt and waits for user input.
# Supports automatic confirmation via --yes flag or non-interactive mode.
#
# Arguments:
#   None
#
# Globals:
#   XRF_YES - If "true", auto-confirm without prompt
#   XRF_JSON - If "true", skip prompt (non-interactive)
#
# Input:
#   User response from stdin (Y/n)
#
# Output:
#   Confirmation prompt to stderr (interactive mode only)
#
# Returns:
#   0 - User confirmed (or auto-confirmed)
#   1 - User declined
#
# Example:
#   preview::confirm || exit 1
##
preview::confirm() {
  # Auto-confirm in non-interactive modes
  # shellcheck disable=SC2154  # XRF_YES and XRF_JSON are set by core::init or args
  if [[ "${XRF_YES:-false}" == "true" ]] || [[ "${XRF_JSON}" == "true" ]]; then
    return 0
  fi

  # Check if running in non-interactive environment
  if [[ ! -t 0 ]]; then
    # stdin is not a terminal (e.g., piped input)
    core::log info "non-interactive mode detected, auto-confirming" "{}"
    return 0
  fi

  # Interactive prompt
  local response=""
  printf "Proceed with installation? [Y/n] " >&2
  read -r response

  # Default to Yes if empty
  response="${response:-Y}"

  case "${response}" in
    [Yy] | [Yy][Ee][Ss])
      return 0
      ;;
    *)
      core::log info "installation cancelled by user" "{}"
      return 1
      ;;
  esac
}

##
# Check if running in dry-run mode
#
# Returns success if --dry-run flag is set, indicating that
# the installation should only show preview without executing.
#
# Arguments:
#   None
#
# Globals:
#   XRF_DRY_RUN - If "true", running in dry-run mode
#
# Returns:
#   0 - Dry-run mode enabled
#   1 - Normal mode
#
# Example:
#   if preview::is_dry_run; then
#     core::log info "dry-run mode, skipping installation" "{}"
#     exit 0
#   fi
##
preview::is_dry_run() {
  [[ "${XRF_DRY_RUN:-false}" == "true" ]]
}
