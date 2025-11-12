#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/backup.sh"

usage() {
  cat << 'EOF'
Usage: xrf backup <command> [options]

Manage Xray configuration backups.

Commands:
  create [--name <name>]    Create a new backup
  list                      List available backups
  restore <name>            Restore from backup
  delete <name>             Delete a backup
  verify <name>             Verify backup integrity

Options:
  --name <name>             Custom backup name (for create command)
  --json                    Output in JSON format (for list command)
  --help, -h                Show this help

Examples:
  # Create backup with auto-generated name
  xrf backup create

  # Create backup with custom name
  xrf backup create --name pre-upgrade

  # List all backups
  xrf backup list

  # List backups in JSON format
  xrf backup list --json

  # Restore from backup
  xrf backup restore backup-20231201-120000

  # Verify backup integrity
  xrf backup verify backup-20231201-120000

  # Delete old backup
  xrf backup delete backup-20231101-100000

EOF
}

main() {
  core::init "${@}"

  local command="${1:-}"
  shift || true

  case "${command}" in
    create)
      # Parse options
      local backup_name=""
      while [[ $# -gt 0 ]]; do
        case "${1}" in
          --name)
            backup_name="${2:-}"
            if [[ -z "${backup_name}" ]]; then
              core::log error "missing value for --name" "{}"
              exit 1
            fi
            shift 2
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

      # Create backup
      if ! backup::create "${backup_name}"; then
        exit 1
      fi
      ;;

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

      # List backups
      backup::list
      ;;

    restore)
      local backup_name="${1:-}"

      if [[ -z "${backup_name}" ]]; then
        core::log error "backup name required" "{}"
        usage
        exit 1
      fi

      # Confirmation prompt
      printf '\n⚠️  WARNING: This will replace your current configuration!\n\n'
      printf 'Backup to restore: %s\n' "${backup_name}"
      printf 'Current configuration will be backed up automatically.\n\n'

      # Skip confirmation if --yes flag is set
      if [[ "${XRF_YES:-false}" != "true" ]]; then
        read -rp "Continue with restore? [y/N] " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
          core::log info "restore cancelled" "{}"
          exit 0
        fi
      fi

      # Restore backup
      if ! backup::restore "${backup_name}"; then
        exit 1
      fi
      ;;

    delete)
      local backup_name="${1:-}"

      if [[ -z "${backup_name}" ]]; then
        core::log error "backup name required" "{}"
        usage
        exit 1
      fi

      # Confirmation prompt
      if [[ "${XRF_YES:-false}" != "true" ]]; then
        read -rp "Delete backup '${backup_name}'? [y/N] " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
          core::log info "deletion cancelled" "{}"
          exit 0
        fi
      fi

      # Delete backup
      if ! backup::delete "${backup_name}"; then
        exit 1
      fi
      ;;

    verify)
      local backup_name="${1:-}"

      if [[ -z "${backup_name}" ]]; then
        core::log error "backup name required" "{}"
        usage
        exit 1
      fi

      # Verify backup
      if backup::verify "${backup_name}"; then
        printf '\n✓ Backup integrity verified: %s\n\n' "${backup_name}"
        exit 0
      else
        printf '\n✗ Backup verification failed: %s\n\n' "${backup_name}"
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

main "${@}"
