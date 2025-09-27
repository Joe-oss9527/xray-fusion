#!/usr/bin/env bash
XRF_PLUGIN_ID="cert-acme"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Auto-issue/renew TLS via acme.sh for Vision"
XRF_PLUGIN_HOOKS=("configure_pre" "service_setup")
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${HERE}/modules/cert/acme_sh.sh"
cert_acme::configure_pre(){
  local topology="" release_dir=""
  for kv in "$@"; do case "$kv" in topology=*) topology="${kv#*=}" ;; release_dir=*) release_dir="${kv#*=}" ;; esac; done
  [[ "$topology" == "vision-reality" ]] || return 0
  local dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  local domain="${XRAY_DOMAIN:-}"
  [[ -n "$domain" ]] || { echo "[cert-acme] XRAY_DOMAIN not set; skip" >&2; return 0; }
  if acme_sh::exists "$dir"; then echo "[cert-acme] cert exists in $dir" >&2; return 0; fi
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then echo "[cert-acme] would issue cert for $domain into $dir" >&2; mkdir -p "$dir"; : >"$dir/fullchain.pem"; : >"$dir/privkey.pem"; return 0; fi
  local email="${XRAY_EMAIL:-admin@${domain}}"; echo "[cert-acme] issuing cert for ${domain} -> ${dir}" >&2; acme_sh::issue "$domain" "$email" "$dir" || { echo "[cert-acme] issue failed" >&2; return 1; }
}
cert_acme::service_setup(){
  local dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  [[ -f "$dir/privkey.pem" ]] || return 0
  chown xray:xray "$dir/privkey.pem" "$dir/fullchain.pem" 2>/dev/null || true
  if command -v acme.sh >/dev/null 2>&1; then
    acme.sh --install-cert -d "${XRAY_DOMAIN}" \
      --fullchain-file "${dir}/fullchain.pem" \
      --key-file "${dir}/privkey.pem" \
      --reloadcmd "systemctl reload xray || true" >/dev/null 2>&1 || true
  fi
}
