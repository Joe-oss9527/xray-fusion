#!/usr/bin/env bash
acme_sh::bin(){ command -v acme.sh 2>/dev/null || echo "/root/.acme.sh/acme.sh"; }
acme_sh::exists(){ local out="${1}"; [[ -f "${out}/fullchain.pem" && -f "${out}/privkey.pem" ]]; }
acme_sh::issue(){
  local domain="${1}" email="${2}" out="${3}"
  mkdir -p "${out}"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "[cert] would issue cert for ${domain} -> ${out}"
    : > "${out}/fullchain.pem"; : > "${out}/privkey.pem"
    return 0
  fi
  local ac; ac="$(acme_sh::bin)"
  "${ac}" --register-account -m "${email}" || true
  "${ac}" --issue -d "${domain}" --standalone --server letsencrypt --force || return 1
  "${ac}" --install-cert -d "${domain}" --fullchain-file "${out}/fullchain.pem" --key-file "${out}/privkey.pem" || return 1
  chmod 600 "${out}/privkey.pem" || true; chmod 644 "${out}/fullchain.pem" || true
}
acme_sh::renew(){ local domain="${1}"; local ac; ac="$(acme_sh::bin)"; "${ac}" --renew -d "${domain}" --force || true; }
