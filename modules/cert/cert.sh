#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=modules/cert/acme_sh.sh
. "${HERE}/modules/cert/acme_sh.sh"

# Contract:
# cert::issue <domain> <email> <out_dir>
# cert::renew <domain> <out_dir>
# cert::exists <out_dir>  -> prints JSON {"exists":bool,"fullchain":"...", "privkey":"..."}
# cert::set_reload_command <domain> <out_dir> [reload_cmd]
# cert::fix_ownership <out_dir> [user:group]

cert::issue() { acme_sh::issue "$@"; }
cert::renew() { acme_sh::renew "$@"; }
cert::exists(){ acme_sh::exists "$@"; }

cert::set_reload_command() {
  local domain="$1" out="$2" reload_cmd="${3:-systemctl reload xray}"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "Would set reload command for ${domain}: ${reload_cmd}"
    return 0
  fi
  
  local acme; acme="$(acme_sh::bin)"
  "${acme}" --install-cert -d "${domain}" \
    --fullchain-file "${out}/fullchain.pem" \
    --key-file "${out}/privkey.pem" \
    --reloadcmd "${reload_cmd}" >/dev/null 2>&1 || true
}

cert::fix_ownership() {
  local out="$1" owner="${2:-xray:xray}"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "Would set ownership ${owner} for certificates in ${out}"
    return 0
  fi
  
  if [[ -f "${out}/privkey.pem" && -f "${out}/fullchain.pem" ]]; then
    # Extract user from owner (before colon)
    local user="${owner%%:*}"
    if id "${user}" >/dev/null 2>&1; then
      chown "${owner}" "${out}/privkey.pem" "${out}/fullchain.pem" || true
    fi
  fi
}
