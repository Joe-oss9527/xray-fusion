#!/usr/bin/env bash
# UI progress and feedback module for xray-fusion
# Provides user-friendly progress tracking and installation feedback

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"

# Installation progress tracking
declare -A _PROGRESS_STEPS
declare -i _PROGRESS_CURRENT=0
declare -i _PROGRESS_TOTAL=0

# Initialize progress tracking
ui::progress_init() {
  local total_steps="${1:?Total steps required}"
  _PROGRESS_TOTAL="${total_steps}"
  _PROGRESS_CURRENT=0
  
  if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
    echo "🚀 Starting xray-fusion installation..."
    echo "═══════════════════════════════════"
  fi
}

# Update progress with current step
ui::progress_step() {
  local step_name="${1:?Step name required}"
  local description="${2:-}"
  
  _PROGRESS_CURRENT=$((_PROGRESS_CURRENT + 1))
  
  if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
    printf "[%d/%d] %s" "${_PROGRESS_CURRENT}" "${_PROGRESS_TOTAL}" "${step_name}"
    if [[ -n "${description}" ]]; then
      printf " - %s" "${description}"
    fi
    echo ""
  fi
  
  # Also log structured data for JSON mode
  core::log info "Installation step" "$(printf '{"step":%d,"total":%d,"name":"%s","description":"%s"}' "${_PROGRESS_CURRENT}" "${_PROGRESS_TOTAL}" "${step_name}" "${description}")"
}

# Mark installation as completed
ui::progress_complete() {
  local topology="${1:-}"
  local version="${2:-}"
  
  if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
    echo ""
    echo "✅ xray-fusion installation completed successfully!"
    echo "═════════════════════════════════════════════"
    if [[ -n "${topology}" ]]; then
      echo "📡 Topology: ${topology}"
    fi
    if [[ -n "${version}" ]]; then
      echo "🔧 Version: ${version}"
    fi
    echo ""
  fi
  
  core::log info "Installation completed" "$(printf '{"topology":"%s","version":"%s","status":"success"}' "${topology}" "${version}")"
}

# Show installation failure
ui::progress_fail() {
  local error_msg="${1:-Unknown error}"
  local step="${2:-}"
  
  if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
    echo ""
    echo "❌ Installation failed!"
    echo "═════════════════════"
    echo "Error: ${error_msg}"
    if [[ -n "${step}" ]]; then
      echo "Failed at step: ${step}"
    fi
    echo ""
    echo "💡 Try running with --debug for more information"
    echo "   or check the logs for details."
  fi
  
  core::log error "Installation failed" "$(printf '{"error":"%s","step":"%s","current":%d,"total":%d}' "${error_msg}" "${step}" "${_PROGRESS_CURRENT}" "${_PROGRESS_TOTAL}")"
}

# Show service status information
ui::show_service_status() {
  local service_name="${1:-xray}"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "Would check service status: ${service_name}"
    return 0
  fi
  
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet "${service_name}" 2>/dev/null; then
      echo "🟢 Service ${service_name} is running"
      core::log info "Service status" "$(printf '{"service":"%s","status":"active"}' "${service_name}")"
    elif systemctl is-enabled --quiet "${service_name}" 2>/dev/null; then
      echo "🟡 Service ${service_name} is enabled but not running"
      core::log warn "Service status" "$(printf '{"service":"%s","status":"enabled_but_inactive"}' "${service_name}")"
    else
      echo "🔴 Service ${service_name} is not running"
      core::log warn "Service status" "$(printf '{"service":"%s","status":"inactive"}' "${service_name}")"
    fi
  else
    echo "ℹ️  systemctl not available - cannot check service status"
  fi
}

# Show final installation summary
ui::show_summary() {
  local topology="${1:-}"
  local version="${2:-}"
  local config_path="${3:-/usr/local/etc/xray/config.json}"
  local state_path="${4:-/var/lib/xray-fusion/state.json}"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    return 0
  fi
  
  echo ""
  echo "📋 Installation Summary"
  echo "═════════════════════"
  echo "Configuration: ${config_path}"
  echo "State file:    ${state_path}"
  echo ""
  
  # Show service status
  ui::show_service_status "xray"
  
  echo ""
  echo "🔧 Management Commands:"
  echo "  Start service:   sudo systemctl start xray"
  echo "  Stop service:    sudo systemctl stop xray"
  echo "  Check status:    sudo systemctl status xray"
  echo "  View logs:       sudo journalctl -u xray -f"
  echo ""
  echo "📚 For more information, visit: https://xtls.github.io/Xray-docs-next/"
}