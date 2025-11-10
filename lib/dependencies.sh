#!/usr/bin/env bash
# Dependency checking utilities
set -euo pipefail

##
# Check critical dependencies before proceeding
#
# This function performs fail-fast validation of required system tools
# before attempting any installation operations. It ensures:
# - At least one download tool is available (git, curl, or wget)
# - systemctl is available (systemd is required for service management)
# - Basic POSIX utilities are present (mktemp, tar, gzip)
#
# The function logs detailed information about found/missing tools to help
# users quickly identify and resolve dependency issues.
#
# Globals:
#   None (uses core::log if available, otherwise logs to stderr)
#
# Returns:
#   0 - All critical dependencies are available
#   1 - One or more critical dependencies are missing
#
# Example:
#   deps::check_critical || error_exit "Missing critical dependencies"
##
deps::check_critical() {
  local missing=()

  # Check downloader availability (need at least one)
  local has_downloader=false
  for tool in git curl wget; do
    if command -v "${tool}" >/dev/null 2>&1; then
      has_downloader=true
      if declare -f core::log >/dev/null 2>&1; then
        core::log debug "found downloader" "$(printf '{"tool":"%s"}' "${tool}")"
      fi
      break
    fi
  done

  if [[ "${has_downloader}" == "false" ]]; then
    if declare -f core::log >/dev/null 2>&1; then
      core::log error "需要至少一个下载工具: git, curl, 或 wget" '{}'
    else
      printf '[ERROR] 需要至少一个下载工具: git, curl, 或 wget\n' >&2
    fi
    return 1
  fi

  # Check systemctl (systemd required)
  if ! command -v systemctl >/dev/null 2>&1; then
    if declare -f core::log >/dev/null 2>&1; then
      core::log error "systemctl not found (systemd required)" '{}'
    else
      printf '[ERROR] systemctl not found (systemd required)\n' >&2
    fi
    missing+=("systemctl")
  fi

  # Check basic utilities
  for tool in mktemp tar gzip; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      if declare -f core::log >/dev/null 2>&1; then
        core::log warn "missing utility" "$(printf '{"tool":"%s"}' "${tool}")"
      else
        printf '[WARN] missing utility: %s\n' "${tool}" >&2
      fi
      missing+=("${tool}")
    fi
  done

  # Fail if any critical tool is missing
  if [[ ${#missing[@]} -gt 0 ]]; then
    if declare -f core::log >/dev/null 2>&1; then
      core::log error "missing critical dependencies" "$(printf '{"tools":"%s"}' "${missing[*]}")"
    else
      printf '[ERROR] missing critical dependencies: %s\n' "${missing[*]}" >&2
    fi
    return 1
  fi

  if declare -f core::log >/dev/null 2>&1; then
    core::log debug "all critical dependencies available" '{}'
  fi
  return 0
}

##
# Check optional dependencies
#
# This function checks for optional tools that enhance functionality but
# are not strictly required for basic installation. Missing optional tools
# will generate warnings but will not cause the function to fail.
#
# Optional tools checked:
# - jq: JSON processing (used for config manipulation if available)
# - openssl: TLS certificate operations (enhanced validation)
# - gpg: GPG signature verification (enhanced security)
#
# These tools may be installed automatically by the installer if needed,
# or their functionality may be gracefully degraded.
#
# Globals:
#   None (uses core::log if available, otherwise logs to stderr)
#
# Returns:
#   0 - Always succeeds (logs warnings for missing tools)
#
# Example:
#   deps::check_optional  # Always safe to call
##
deps::check_optional() {
  local optional_tools="jq openssl gpg"
  local missing=()

  for tool in ${optional_tools}; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing+=("${tool}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    if declare -f core::log >/dev/null 2>&1; then
      core::log warn "missing optional tools (functionality may be limited)" "$(printf '{"tools":"%s"}' "${missing[*]}")"
    else
      printf '[WARN] missing optional tools (functionality may be limited): %s\n' "${missing[*]}" >&2
    fi
  fi

  return 0
}

##
# Print user-friendly error message for missing dependencies
#
# This function generates a helpful error message with installation
# instructions for common Linux distributions when critical dependencies
# are missing.
#
# Arguments:
#   $@ - List of missing tool names
#
# Output:
#   Multi-line error message with installation instructions to stderr
#
# Returns:
#   0 - Always succeeds
#
# Example:
#   deps::print_install_help "curl" "tar" "systemctl"
##
deps::print_install_help() {
  local missing=("$@")

  printf '\n=== 缺少关键依赖 ===\n' >&2
  printf '缺少以下工具: %s\n\n' "${missing[*]}" >&2

  printf '请根据您的系统安装:\n\n' >&2

  printf '# Debian/Ubuntu\n' >&2
  printf 'sudo apt-get update && sudo apt-get install -y' >&2
  for tool in "${missing[@]}"; do
    case "${tool}" in
      systemctl) printf ' systemd' >&2 ;;
      *) printf ' %s' "${tool}" >&2 ;;
    esac
  done
  printf '\n\n' >&2

  printf '# CentOS/RHEL/Rocky\n' >&2
  printf 'sudo yum install -y' >&2
  for tool in "${missing[@]}"; do
    case "${tool}" in
      systemctl) printf ' systemd' >&2 ;;
      *) printf ' %s' "${tool}" >&2 ;;
    esac
  done
  printf '\n\n' >&2

  printf '# Arch Linux\n' >&2
  printf 'sudo pacman -S' >&2
  for tool in "${missing[@]}"; do
    case "${tool}" in
      systemctl) printf ' systemd' >&2 ;;
      *) printf ' %s' "${tool}" >&2 ;;
    esac
  done
  printf '\n\n' >&2

  return 0
}
