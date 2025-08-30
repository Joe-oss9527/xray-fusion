#!/usr/bin/env bash
# Schedule/unschedule certificate auto-renew (systemd timer or cron fallback)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/io.sh"

sysd_service() { echo "/etc/systemd/system/xrf-cert-renew.service"; }
sysd_timer()   { echo "/etc/systemd/system/xrf-cert-renew.timer"; }
cron_file()    { echo "/etc/cron.d/xrf-cert-renew"; }

schedule() {
  if command -v systemctl >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan systemd timer install" "$(printf '{"service":"%s","timer":"%s"}' "$(sysd_service)" "$(sysd_timer)")"
      sed -n '1,80p' "$HERE/packaging/systemd/xrf-cert-renew.service"
      sed -n '1,80p' "$HERE/packaging/systemd/xrf-cert-renew.timer"
      return 0
    fi
    io::atomic_write "/usr/local/libexec/xrf-cert-renew.sh" 0755 < "$HERE/packaging/libexec/xrf-cert-renew.sh"
    io::atomic_write "$(sysd_service)" 0644 < "$HERE/packaging/systemd/xrf-cert-renew.service"
    io::atomic_write "$(sysd_timer)" 0644 < "$HERE/packaging/systemd/xrf-cert-renew.timer"
    sudo systemctl daemon-reload
    sudo systemctl enable --now xrf-cert-renew.timer
    core::log info "systemd timer installed" "{}"
  else
    # cron fallback
    local line='0 3 * * * root acme.sh --cron >/dev/null 2>&1'
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan cron install" "$(printf '{"file":"%s","line":"%s"}' "$(cron_file)" "$line")"
      return 0
    fi
    io::atomic_write "$(cron_file)" 0644 <<<"$line"
    core::log info "cron installed" "{}"
  fi
}

unschedule() {
  if command -v systemctl >/dev/null 2>&1; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan systemd timer removal" "$(printf '{"service":"%s","timer":"%s"}' "$(sysd_service)" "$(sysd_timer)")"
      return 0
    fi
    sudo systemctl disable --now xrf-cert-renew.timer || true
    sudo rm -f "$(sysd_service)" "$(sysd_timer)"
    sudo systemctl daemon-reload
    core::log info "systemd timer removed" "{}"
  else
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Plan cron removal" "$(printf '{"file":"%s"}' "$(cron_file)")"
      return 0
    fi
    sudo rm -f "$(cron_file)"
    core::log info "cron removed" "{}"
  fi
}

usage() {
cat <<EOF
Usage:
  xrf cert schedule     # install systemd timer or cron
  xrf cert unschedule   # remove systemd timer or cron
EOF
}

main() {
  core::init "$@"
  local sub="${1-}"; shift || true
  case "$sub" in
    schedule) schedule ;;
    unschedule) unschedule ;;
    *) usage; exit 2 ;;
  esac
}
main "$@"
