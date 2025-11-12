#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/templates.sh"

usage() {
  cat << 'EOF'
Usage: xrf templates <command> [options]

Manage configuration templates.

Commands:
  list                          List available templates
  show <template-id>            Show template details
  validate <template-id>        Validate template structure

Options:
  --json                        Output in JSON format
  --help, -h                    Show this help

Examples:
  # List available templates
  xrf templates list

  # Show template details
  xrf templates show home

  # Validate template
  xrf templates validate office

  # JSON output
  xrf templates list --json

EOF
}

main() {
  core::init "${@}"

  local command="${1:-}"
  shift || true

  case "${command}" in
    list)
      # Parse options
      while [[ $# -gt 0 ]]; do
        case "${1}" in
          --json)
            export XRF_JSON="true"
            shift
            ;;
          --help | -h)
            usage
            exit 0
            ;;
          *)
            core::log error "unknown option" "$(printf '{"option":"%s"}' "${1}")"
            usage
            exit 1
            ;;
        esac
      done

      templates::list
      ;;

    show)
      local template_id="${1:-}"
      shift || true

      if [[ -z "${template_id}" ]]; then
        core::log error "template ID required" "{}"
        usage
        exit 1
      fi

      # Parse options
      while [[ $# -gt 0 ]]; do
        case "${1}" in
          --json)
            export XRF_JSON="true"
            shift
            ;;
          *)
            core::log error "unknown option" "$(printf '{"option":"%s"}' "${1}")"
            usage
            exit 1
            ;;
        esac
      done

      templates::show "${template_id}"
      ;;

    validate)
      local template_id="${1:-}"

      if [[ -z "${template_id}" ]]; then
        core::log error "template ID required" "{}"
        usage
        exit 1
      fi

      if templates::validate "${template_id}"; then
        printf '\nTemplate %s is valid ✓\n\n' "${template_id}"
        exit 0
      else
        printf '\nTemplate %s is invalid ✗\n\n' "${template_id}"
        exit 1
      fi
      ;;

    --help | -h | "")
      usage
      exit 0
      ;;

    *)
      core::log error "unknown command" "$(printf '{"command":"%s"}' "${command}")"
      usage
      exit 1
      ;;
  esac
}

main "$@"
