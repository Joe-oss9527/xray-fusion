#!/usr/bin/env bash
XRF_PLUGIN_ID="logrotate-obs"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="File logging + logrotate + optional journald tuning, with observability tips"
XRF_PLUGIN_HOOKS=("configure_post" "service_setup" "service_remove" "links_render" "uninstall_pre")
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"; . "${HERE}/lib/core.sh"; . "${HERE}/modules/io.sh"
_log_dir(){ echo "/var/log/xray"; }
_logrotate_path(){ echo "/etc/logrotate.d/xray-fusion"; }
_journal_dropin_dir(){ echo "/etc/systemd/journald.conf.d"; }
_journal_dropin(){ echo "$(_journal_dropin_dir)/xray-fusion.conf"; }

logrotate_obs::configure_post(){
  local topology="" release_dir=""; for kv in "$@"; do case "$kv" in topology=*) topology="${kv#*=}" ;; release_dir=*) release_dir="${kv#*=}" ;; esac; done
  local target="${XRF_LOG_TARGET:-journald}" lvl="${XRAY_LOG_LEVEL:-warning}"
  if [[ "$target" == "file" ]]; then
    local d="$(_log_dir)"; io::ensure_dir "$d" 0750; chown root:xray "$d" 2>/dev/null || true; chmod 0750 "$d" 2>/dev/null || true
    : > "$d/access.log" 2>/dev/null || true; : > "$d/error.log" 2>/dev/null || true; chown root:xray "$d/"*.log 2>/dev/null || true; chmod 0640 "$d/"*.log 2>/dev/null || true
    printf '{"log":{"access":"%s/access.log","error":"%s/error.log","loglevel":"%s"}}' "$d" "$d" "$lvl" | io::atomic_write "${release_dir}/00_log.json" 0640
    core::log info "[logrotate-obs] file logging enabled" "$(printf '{"dir":"%s"}' "$d")"
  else
    core::log info "[logrotate-obs] journald mode" "$(printf '{"loglevel":"%s"}' "$lvl")"
  fi
}

_build_logrotate_body(){
  local freq="${XRF_LOGROTATE_FREQUENCY:-weekly}" rotate="${XRF_LOGROTATE_ROTATE:-8}" size="${XRF_LOGROTATE_SIZE:-50M}"
  cat <<EOF
$(_log_dir)/*.log {
    ${freq}
    rotate ${rotate}
    missingok
    compress
    delaycompress
    notifempty
    copytruncate
    create 0640 xray xray
$( [[ "$freq" == "size" ]] && printf "    size %s\n" "$size" )
}
EOF
}

logrotate_obs::service_setup(){
  local target="${XRF_LOG_TARGET:-journald}"
  if [[ "$target" == "file" ]]; then _build_logrotate_body | io::atomic_write "$(_logrotate_path)" 0644; core::log info "[logrotate-obs] logrotate installed" "$(printf '{"path":"%s"}' "$(_logrotate_path)")"; fi
  if [[ "${XRF_JOURNAL_TUNE:-false}" == "true" ]]; then io::ensure_dir "$(_journal_dropin_dir)" 0755; { echo "[Journal]"; [[ -n "${XRF_JOURNAL_MAX:-}" ]] && echo "SystemMaxUse=${XRF_JOURNAL_MAX}"; echo "RateLimitIntervalSec=${XRF_JOURNAL_RATE_INTERVAL:-30s}"; echo "RateLimitBurst=${XRF_JOURNAL_RATE_BURST:-1000}"; } | io::atomic_write "$(_journal_dropin)" 0644; systemctl restart systemd-journald 2>/dev/null || true; core::log info "[logrotate-obs] journald tuned" "$(printf '{"dropin":"%s"}' "$(_journal_dropin)")"; fi
}

logrotate_obs::service_remove(){ local conf="$(_logrotate_path)"; [[ -f "$conf" ]] && rm -f "$conf" || true; core::log info "[logrotate-obs] logrotate removed" "$(printf '{"path":"%s"}' "$conf")"; }
logrotate_obs::uninstall_pre(){ local j="$(_journal_dropin)"; [[ -f "$j" ]] && rm -f "$j" || true; }

logrotate_obs::links_render(){
  local target="${XRF_LOG_TARGET:-journald}"; echo "[obs] ========= Observability ========="
  if [[ "$target" == "file" ]]; then echo "File logs: $(_log_dir)/{error.log,access.log}"; echo "Follow:    tail -F $(_log_dir)/error.log"; echo "Rotate:    sudo logrotate -f $(_logrotate_path)"
  else echo "Journald:  sudo journalctl -u xray -n 200 -f"; echo "Filter:    sudo journalctl -u xray --since '1 hour ago' | grep -i error"; fi
  echo "[obs] ================================="
}
