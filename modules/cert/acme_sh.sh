#!/usr/bin/env bash
# Minimal acme.sh backend wrapper. Assumes acme.sh is installed if not dry-run.
# All functions honor XRF_DRY_RUN=true for preview-only mode.

acme_sh::bin() {
  command -v acme.sh 2>/dev/null || echo "/root/.acme.sh/acme.sh"
}

acme_sh::install() {
  local email="${1:-admin@example.com}"  # Accept email parameter with fallback
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "Would install acme.sh to ~/.acme.sh/ with email: ${email}"
    return 0
  fi
  
  local acme_path="/root/.acme.sh/acme.sh"
  if [[ -x "${acme_path}" ]]; then
    return 0  # Already installed
  fi
  
  # Install acme.sh following official method with provided email
  curl -s https://get.acme.sh | sh -s email="${email}"
  
  # Verify installation
  if [[ ! -x "${acme_path}" ]]; then
    return 1
  fi
}

acme_sh::issue() {
  local domain="$1" email="$2" out="$3"
  mkdir -p "${out}"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    echo "Would install acme.sh if needed"
    echo "acme.sh --issue -d ${domain} --standalone --server letsencrypt --accountemail ${email}"
    echo "acme.sh --install-cert -d ${domain} --fullchain-file ${out}/fullchain.pem --key-file ${out}/privkey.pem --reloadcmd 'systemctl reload xray || true'"
    echo "Would write certs under ${out}"
    return 0
  fi
  
  # Auto-install acme.sh if needed, using the same email
  acme_sh::install "${email}" || { echo "Failed to install acme.sh"; return 1; }
  
  local acme; acme="$(acme_sh::bin)"
  
  # Register account first
  "${acme}" --register-account -m "${email}" || true
  
  # Force remove any existing certificate config to start fresh
  local domain_dir="${HOME}/.acme.sh/${domain}_ecc"
  if [[ -d "${domain_dir}" ]]; then
    rm -rf "${domain_dir}"
  fi
  
  # Issue certificate with force flag to bypass cache
  "${acme}" --issue -d "${domain}" --standalone --server letsencrypt --accountemail "${email}" --force || return 1
  
  # Install certificate without reload command during initial setup
  # Higher-level cert:: interface handles reload command setup
  "${acme}" --install-cert -d "${domain}" \
    --fullchain-file "${out}/fullchain.pem" \
    --key-file "${out}/privkey.pem" || return 1
  
  # Verify files exist and set basic permissions
  if [[ -f "${out}/fullchain.pem" && -f "${out}/privkey.pem" ]]; then
    chmod 600 "${out}/privkey.pem" || true
    chmod 644 "${out}/fullchain.pem" || true
    return 0
  else
    echo "ERROR: Certificate files not found after installation"
    return 1
  fi
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
