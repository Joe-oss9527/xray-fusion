#!/usr/bin/env bash
# Minimal acme.sh backend wrapper. Assumes acme.sh is installed if not dry-run.
# All functions honor XRF_DRY_RUN=true for preview-only mode.

acme_sh::bin() {
  command -v acme.sh 2>/dev/null || echo "/root/.acme.sh/acme.sh"
}

acme_sh::issue() {
  local domain="$1" email="$2" out="$3"
  mkdir -p "${out}"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "acme.sh --issue -d ${domain} --standalone --server letsencrypt --accountemail ${email}"
    echo "Would write certs under ${out}"
    return 0
  fi
  local acme; acme="$(acme_sh::bin)"
  "${acme}" --register-account -m "${email}" || true
  "${acme}" --issue -d "${domain}" --standalone --server letsencrypt --accountemail "${email}"
  "${acme}" --install-cert -d "${domain}"     --fullchain-file "${out}/fullchain.pem"     --key-file "${out}/privkey.pem"     --reloadcmd "true"
  chmod 600 "${out}/privkey.pem" || true
}

acme_sh::renew() {
  local domain="$1" out="$2"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "acme.sh --renew -d ${domain} --force"
    return 0
  fi
  local acme; acme="$(acme_sh::bin)"
  "${acme}" --renew -d "${domain}" --force || true
}

acme_sh::exists() {
  local out="$1"
  local f="${out}/fullchain.pem" k="${out}/privkey.pem"
  if [[ -f "${f}" && -f "${k}" ]]; then
    printf '{"exists":true,"fullchain":"%s","privkey":"%s"}\n' "${f}" "${k}"
    return 0
  fi
  printf '{"exists":false}\n'
  return 1
}
