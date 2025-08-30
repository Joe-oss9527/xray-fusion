#!/usr/bin/env bash
# User management module for xray-fusion
# Provides idempotent user and group creation operations

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"

# Ensure a system user exists with proper configuration
user::ensure_system_user() {
  local username="${1:?Username required}"
  local groupname="${2:-${username}}"
  local home_dir="${3:-/var/lib/${username}}"
  local shell="${4:-/usr/sbin/nologin}"
  local comment="${5:-System user for ${username} service}"
  
  # Create group first if it doesn't exist
  if ! getent group "${groupname}" >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan create system group" "$(printf '{"group":"%s"}' "${groupname}")"
      return 0
    fi
    sudo groupadd --system "${groupname}"
    core::log info "Created system group" "$(printf '{"group":"%s"}' "${groupname}")"
  fi
  
  # Create user if it doesn't exist
  if ! getent passwd "${username}" >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan create system user" "$(printf '{"user":"%s","group":"%s","home":"%s","shell":"%s"}' "${username}" "${groupname}" "${home_dir}" "${shell}")"
      return 0
    fi
    
    sudo useradd --system \
      --gid "${groupname}" \
      --home-dir "${home_dir}" \
      --no-create-home \
      --shell "${shell}" \
      --comment "${comment}" \
      "${username}"
    
    core::log info "Created system user" "$(printf '{"user":"%s","group":"%s","home":"%s"}' "${username}" "${groupname}" "${home_dir}")"
  else
    core::log info "System user already exists" "$(printf '{"user":"%s"}' "${username}")"
  fi
}

# Remove a system user and optionally its group
user::remove_system_user() {
  local username="${1:?Username required}"
  local remove_group="${2:-false}"
  
  if getent passwd "${username}" >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan remove system user" "$(printf '{"user":"%s"}' "${username}")"
      return 0
    fi
    
    sudo userdel "${username}"
    core::log info "Removed system user" "$(printf '{"user":"%s"}' "${username}")"
  fi
  
  if [[ "${remove_group}" == "true" ]] && getent group "${username}" >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan remove system group" "$(printf '{"group":"%s"}' "${username}")"
      return 0
    fi
    
    sudo groupdel "${username}"
    core::log info "Removed system group" "$(printf '{"group":"%s"}' "${username}")"
  fi
}

# Check if user exists
user::exists() {
  local username="${1:?Username required}"
  getent passwd "${username}" >/dev/null 2>&1
}

# Get user's primary group
user::get_group() {
  local username="${1:?Username required}"
  if user::exists "${username}"; then
    id -gn "${username}"
  else
    return 1
  fi
}

# Get user's home directory
user::get_home() {
  local username="${1:?Username required}"
  if user::exists "${username}"; then
    getent passwd "${username}" | cut -d: -f6
  else
    return 1
  fi
}