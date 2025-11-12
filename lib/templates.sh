#!/usr/bin/env bash
# Configuration template system

# Source guard: prevent double-sourcing (readonly variables cannot be re-declared)
[[ -n "${_XRF_TEMPLATES_LOADED:-}" ]] && return 0
readonly _XRF_TEMPLATES_LOADED=1

# Template directory locations
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILTIN_TEMPLATES_DIR="${HERE}/templates/built-in"
readonly USER_TEMPLATES_DIR="/usr/local/etc/xray-fusion/templates"

##
# List available templates
#
# Lists all available templates (built-in and user-defined) with metadata.
# Supports both text and JSON output formats.
#
# Arguments:
#   None
#
# Globals:
#   XRF_JSON - If "true", output JSON format
#   BUILTIN_TEMPLATES_DIR - Built-in templates location
#   USER_TEMPLATES_DIR - User templates location
#
# Output:
#   Template list to stdout (text or JSON format)
#
# Returns:
#   0 - Success
#
# Example:
#   templates::list
##
templates::list() {
  core::log debug "listing available templates" "{}"

  # Collect all template files
  local template_files=()

  # Built-in templates
  if [[ -d "${BUILTIN_TEMPLATES_DIR}" ]]; then
    while IFS= read -r file; do
      template_files+=("${file}")
    done < <(find "${BUILTIN_TEMPLATES_DIR}" -name "*.json" -type f 2> /dev/null)
  fi

  # User templates
  if [[ -d "${USER_TEMPLATES_DIR}" ]]; then
    while IFS= read -r file; do
      template_files+=("${file}")
    done < <(find "${USER_TEMPLATES_DIR}" -name "*.json" -type f 2> /dev/null)
  fi

  # shellcheck disable=SC2154  # XRF_JSON is set by core::init
  if [[ "${XRF_JSON}" == "true" ]]; then
    # JSON format
    printf '{\n  "templates": [\n'
    local first=1
    for file in "${template_files[@]}"; do
      if [[ -f "${file}" ]]; then
        local metadata
        metadata=$(jq -c '.metadata' "${file}" 2> /dev/null)
        if [[ -n "${metadata}" && "${metadata}" != "null" ]]; then
          [[ "${first}" -eq 0 ]] && printf ',\n'
          printf '    %s' "${metadata}"
          first=0
        fi
      fi
    done
    printf '\n  ]\n}\n'
  else
    # Text format
    printf '\nAvailable Templates:\n\n'

    if [[ "${#template_files[@]}" -eq 0 ]]; then
      printf '  No templates found.\n\n'
      return 0
    fi

    for file in "${template_files[@]}"; do
      if [[ -f "${file}" ]]; then
        local id name description category
        id=$(jq -r '.metadata.id // "unknown"' "${file}" 2> /dev/null)
        name=$(jq -r '.metadata.name // "Unknown"' "${file}" 2> /dev/null)
        description=$(jq -r '.metadata.description // ""' "${file}" 2> /dev/null)
        category=$(jq -r '.metadata.category // "other"' "${file}" 2> /dev/null)

        printf '  [%s] %s\n' "${id}" "${name}"
        printf '      Category: %s\n' "${category}"
        if [[ -n "${description}" ]]; then
          printf '      %s\n' "${description}"
        fi
        printf '\n'
      fi
    done
  fi
}

##
# Load template configuration
#
# Loads template configuration from file and returns JSON.
# Supports both built-in and user-defined templates.
#
# Arguments:
#   $1 - Template ID (string, required)
#
# Output:
#   Template JSON to stdout
#
# Returns:
#   0 - Template loaded successfully
#   1 - Template not found or invalid
#
# Example:
#   templates::load "home"
##
templates::load() {
  local template_id="${1:?template ID required}"

  core::log debug "loading template" "$(printf '{"id":"%s"}' "${template_id}")"

  # Try built-in templates first
  local template_file="${BUILTIN_TEMPLATES_DIR}/${template_id}.json"

  # If not found, try user templates
  if [[ ! -f "${template_file}" ]]; then
    template_file="${USER_TEMPLATES_DIR}/${template_id}.json"
  fi

  # Check if template exists
  if [[ ! -f "${template_file}" ]]; then
    core::log error "template not found" "$(printf '{"id":"%s"}' "${template_id}")"
    return 1
  fi

  # Validate JSON format
  if ! jq empty "${template_file}" 2> /dev/null; then
    core::log error "invalid template JSON" "$(printf '{"file":"%s"}' "${template_file}")"
    return 1
  fi

  # Output template JSON
  cat "${template_file}"
  return 0
}

##
# Validate template structure
#
# Validates template JSON structure and required fields.
#
# Arguments:
#   $1 - Template ID (string, required)
#
# Output:
#   Validation errors to stderr (via core::log)
#
# Returns:
#   0 - Template is valid
#   1 - Template is invalid
#
# Example:
#   templates::validate "home"
##
templates::validate() {
  local template_id="${1:?template ID required}"

  core::log debug "validating template" "$(printf '{"id":"%s"}' "${template_id}")"

  # Load template
  local template
  template="$(templates::load "${template_id}")" || return 1

  # Check required metadata fields
  local required_metadata_fields=("id" "name" "description")
  for field in "${required_metadata_fields[@]}"; do
    local value
    value=$(echo "${template}" | jq -r ".metadata.${field} // empty")
    if [[ -z "${value}" ]]; then
      core::log error "missing required metadata field" "$(printf '{"field":"%s"}' "${field}")"
      return 1
    fi
  done

  # Check required config fields
  local topology
  topology=$(echo "${template}" | jq -r '.config.topology // empty')
  if [[ -z "${topology}" ]]; then
    core::log error "missing required config field" '{"field":"topology"}'
    return 1
  fi

  # Validate topology value
  if [[ "${topology}" != "reality-only" && "${topology}" != "vision-reality" ]]; then
    core::log error "invalid topology value" "$(printf '{"topology":"%s"}' "${topology}")"
    return 1
  fi

  core::log debug "template validation passed" "$(printf '{"id":"%s"}' "${template_id}")"
  return 0
}

##
# Export template configuration as environment variables
#
# Converts template JSON to environment variables for use in installation.
# Sets TEMPLATE_* variables that can be consumed by install flow.
#
# Arguments:
#   $1 - Template ID (string, required)
#
# Globals (exports):
#   TEMPLATE_TOPOLOGY - Template topology
#   TEMPLATE_VERSION - Xray version
#   TEMPLATE_PLUGINS - Comma-separated plugin list
#   TEMPLATE_PORT - Reality port (reality-only)
#   TEMPLATE_VISION_PORT - Vision port (vision-reality)
#   TEMPLATE_REALITY_PORT - Reality port (vision-reality)
#   TEMPLATE_SNI - SNI domain(s)
#   TEMPLATE_REALITY_DEST - Reality destination
#   TEMPLATE_SNIFFING - Sniffing enabled
#
# Returns:
#   0 - Success
#   1 - Template not found or invalid
#
# Example:
#   templates::export "home"
#   echo $TEMPLATE_TOPOLOGY
##
templates::export() {
  local template_id="${1:?template ID required}"

  core::log debug "exporting template variables" "$(printf '{"id":"%s"}' "${template_id}")"

  # Validate template first
  templates::validate "${template_id}" || return 1

  # Load template
  local template
  template="$(templates::load "${template_id}")" || return 1

  # Export metadata
  export TEMPLATE_ID="${template_id}"
  TEMPLATE_NAME=$(echo "${template}" | jq -r '.metadata.name')
  export TEMPLATE_NAME

  # Export config - topology
  TEMPLATE_TOPOLOGY=$(echo "${template}" | jq -r '.config.topology')
  export TEMPLATE_TOPOLOGY

  # Export config - xray settings
  TEMPLATE_VERSION=$(echo "${template}" | jq -r '.config.xray.version // "latest"')
  export TEMPLATE_VERSION

  TEMPLATE_SNI=$(echo "${template}" | jq -r '.config.xray.sni // ""')
  export TEMPLATE_SNI

  TEMPLATE_REALITY_DEST=$(echo "${template}" | jq -r '.config.xray.reality_dest // ""')
  export TEMPLATE_REALITY_DEST

  TEMPLATE_SNIFFING=$(echo "${template}" | jq -r '.config.xray.sniffing // false')
  export TEMPLATE_SNIFFING

  # Export topology-specific settings
  if [[ "${TEMPLATE_TOPOLOGY}" == "reality-only" ]]; then
    TEMPLATE_PORT=$(echo "${template}" | jq -r '.config.xray.port // 443')
    export TEMPLATE_PORT
  else
    TEMPLATE_VISION_PORT=$(echo "${template}" | jq -r '.config.xray.vision_port // 8443')
    export TEMPLATE_VISION_PORT
    TEMPLATE_REALITY_PORT=$(echo "${template}" | jq -r '.config.xray.reality_port // 443')
    export TEMPLATE_REALITY_PORT
  fi

  # Export plugins (convert array to comma-separated string)
  TEMPLATE_PLUGINS=$(echo "${template}" | jq -r '.config.plugins // [] | join(",")')
  export TEMPLATE_PLUGINS

  core::log info "template variables exported" "$(printf '{"id":"%s","topology":"%s"}' "${template_id}" "${TEMPLATE_TOPOLOGY}")"
  return 0
}

##
# Show template details
#
# Displays detailed information about a template including
# configuration, requirements, and notes.
#
# Arguments:
#   $1 - Template ID (string, required)
#
# Globals:
#   XRF_JSON - If "true", output JSON format
#
# Output:
#   Template details to stdout (text or JSON format)
#
# Returns:
#   0 - Success
#   1 - Template not found or invalid
#
# Example:
#   templates::show "home"
##
templates::show() {
  local template_id="${1:?template ID required}"

  core::log debug "showing template details" "$(printf '{"id":"%s"}' "${template_id}")"

  # Validate template first
  templates::validate "${template_id}" || return 1

  # Load template
  local template
  template="$(templates::load "${template_id}")" || return 1

  # shellcheck disable=SC2154  # XRF_JSON is set by core::init
  if [[ "${XRF_JSON}" == "true" ]]; then
    # JSON format - output entire template
    echo "${template}" | jq '.'
  else
    # Text format - formatted display
    local name description topology version plugins
    name=$(echo "${template}" | jq -r '.metadata.name')
    description=$(echo "${template}" | jq -r '.metadata.description')
    topology=$(echo "${template}" | jq -r '.config.topology')
    version=$(echo "${template}" | jq -r '.config.xray.version')
    plugins=$(echo "${template}" | jq -r '.config.plugins // [] | join(", ")')

    printf '\nTemplate: %s [%s]\n\n' "${name}" "${template_id}"
    printf 'Description:\n  %s\n\n' "${description}"
    printf 'Configuration:\n'
    printf '  Topology:  %s\n' "${topology}"
    printf '  Version:   %s\n' "${version}"
    if [[ -n "${plugins}" ]]; then
      printf '  Plugins:   %s\n' "${plugins}"
    fi

    # Show requirements if present
    local requirements
    requirements=$(echo "${template}" | jq -r '.requirements // [] | length')
    if [[ "${requirements}" -gt 0 ]]; then
      printf '\nRequirements:\n'
      echo "${template}" | jq -r '.requirements[]' | while IFS= read -r req; do
        printf '  - %s\n' "${req}"
      done
    fi

    # Show notes if present
    local notes
    notes=$(echo "${template}" | jq -r '.notes // [] | length')
    if [[ "${notes}" -gt 0 ]]; then
      printf '\nNotes:\n'
      echo "${template}" | jq -r '.notes[]' | while IFS= read -r note; do
        printf '  - %s\n' "${note}"
      done
    fi
    printf '\n'
  fi
}
