#!/usr/bin/env bash
# shellcheck disable=SC2034  # Plugin metadata variables are used by the plugin system
XRF_PLUGIN_ID="links-qr"
XRF_PLUGIN_VERSION="1.1.0"
XRF_PLUGIN_DESC="Render QR codes for client links (requires qrencode)"
XRF_PLUGIN_HOOKS=("links_render")

HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${HERE}/lib/core.sh"

links_qr::links_render() {
  local link="" topology=""

  # Parse arguments
  for arg in "${@}"; do
    case "${arg}" in
      link=*) link="${arg#link=}" ;;
      topology=*) topology="${arg#topology=}" ;;
    esac
  done

  # Check if qrencode is available
  command -v qrencode > /dev/null 2>&1 || {
    core::log debug "qrencode not found, skipping QR generation"
    return 0
  }

  # Validate link
  if [[ -z "${link}" ]]; then
    core::log debug "No link provided to QR plugin"
    return 0
  fi

  # Render QR code to terminal
  echo "" # Blank line for spacing
  qrencode -t ANSIUTF8 "${link}" 2>&1 || {
    core::log error "Failed to generate QR code"
    return 1
  }
  echo "" # Bottom spacing
}
