#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/plugins.sh"
. "${HERE}/services/xray/common.sh"

_rm() {
  local p="${1}"
  [[ -e "${p}" || -L "${p}" ]] && {
    echo "rm -rf ${p}"
    rm -rf "${p}" || true
  }
}

uninstall_caddy() {
  core::log info "uninstalling Caddy" "{}"

  # Stop and disable Caddy service
  if systemctl is-active --quiet caddy 2> /dev/null; then
    systemctl stop caddy || true
  fi
  if systemctl is-enabled --quiet caddy 2> /dev/null; then
    systemctl disable caddy || true
  fi

  # Stop and disable cert-reload timer/service (current timer-based approach)
  systemctl stop cert-reload.timer 2> /dev/null || true
  systemctl stop cert-reload.service 2> /dev/null || true
  systemctl disable cert-reload.timer 2> /dev/null || true

  # Stop and disable old path-based units (deprecated)
  systemctl stop cert-reload.path 2> /dev/null || true
  systemctl disable cert-reload.path 2> /dev/null || true

  # Stop and disable very old timer units (backward compatibility)
  systemctl stop caddy-cert-sync.timer 2> /dev/null || true
  systemctl stop caddy-cert-sync.service 2> /dev/null || true
  systemctl disable caddy-cert-sync.timer 2> /dev/null || true
  systemctl disable caddy-cert-sync.service 2> /dev/null || true

  # Remove systemd units (current timer-based)
  _rm "/etc/systemd/system/caddy.service"
  _rm "/etc/systemd/system/cert-reload.timer"
  _rm "/etc/systemd/system/cert-reload.service"

  # Remove deprecated path-based units
  _rm "/etc/systemd/system/cert-reload.path"
  _rm "/etc/systemd/system/cert-reload.target"

  # Remove old timer-based units (backward compatibility)
  _rm "/etc/systemd/system/caddy-cert-sync.service"
  _rm "/etc/systemd/system/caddy-cert-sync.timer"

  # Reload systemd daemon and reset failed states
  systemctl daemon-reload || true
  systemctl reset-failed caddy.service 2> /dev/null || true
  systemctl reset-failed cert-reload.timer 2> /dev/null || true
  systemctl reset-failed cert-reload.service 2> /dev/null || true
  systemctl reset-failed cert-reload.path 2> /dev/null || true
  systemctl reset-failed caddy-cert-sync.service 2> /dev/null || true
  systemctl reset-failed caddy-cert-sync.timer 2> /dev/null || true

  # Remove Caddy binary and config
  _rm "/usr/local/bin/caddy"
  _rm "/usr/local/bin/caddy-cert-sync"
  _rm "/usr/local/etc/caddy"

  # Remove Caddy data directories (optional, commented out to preserve certificates)
  # _rm "/root/.local/share/caddy"
  # _rm "/root/.config/caddy"

  core::log info "Caddy uninstalled" "{}"
}

disable_all_plugins() {
  local enabled_dir="${HERE}/plugins/enabled"

  if [[ ! -d "${enabled_dir}" ]]; then
    return 0
  fi

  core::log info "disabling all plugins" "{}"

  # Find all enabled plugins and disable them
  for plugin_link in "${enabled_dir}"/*.sh; do
    if [[ -L "${plugin_link}" ]]; then
      local plugin_name
      plugin_name="$(basename "${plugin_link}" .sh)"
      core::log info "disabling plugin" "$(printf '{"plugin":"%s"}' "${plugin_name}")"
      rm -f "${plugin_link}" || true
    fi
  done

  core::log info "all plugins disabled" "{}"
}

main() {
  core::init "${@}"
  plugins::ensure_dirs
  plugins::load_enabled
  plugins::emit uninstall_pre

  # Uninstall Xray
  "${HERE}/services/xray/systemd-unit.sh" remove 2> /dev/null || true
  _rm "$(xray::prefix)/bin/xray"
  _rm "$(xray::confbase)"

  # Uninstall Caddy if it was installed by cert-auto plugin
  if [[ -f "/usr/local/bin/caddy" ]]; then
    uninstall_caddy
  fi

  plugins::emit uninstall_post

  # Disable all enabled plugins after uninstallation
  disable_all_plugins

  echo "Uninstalled."
}
main "${@}"
