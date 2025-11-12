#!/usr/bin/env bash
# shellcheck disable=SC2034  # Plugin metadata variables are used by the plugin system
XRF_PLUGIN_ID="cert-auto"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Auto-issue/renew TLS via Caddy for Vision"
XRF_PLUGIN_HOOKS=("configure_pre" "service_setup")
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/validators.sh"
. "${HERE}/modules/web/caddy.sh"

cert_auto::configure_pre() {
  local topology="" release_dir=""
  for kv in "${@}"; do case "${kv}" in topology=*) topology="${kv#*=}" ;; release_dir=*) release_dir="${kv#*=}" ;; esac done

  core::log debug "cert-auto configure_pre called" "$(printf '{"topology":"%s","release_dir":"%s","XRAY_DOMAIN":"%s"}' "${topology}" "${release_dir}" "${XRAY_DOMAIN:-unset}")"

  [[ "${topology}" == "vision-reality" ]] || {
    core::log debug "cert-auto skipping - topology is not vision-reality" "{}"
    return 0
  }

  local domain="${XRAY_DOMAIN:-}"
  [[ -n "${domain}" ]] || {
    core::log error "cert-auto requires domain for vision-reality topology" "$(printf '{"example":"bin/xrf install --topology vision-reality --domain your-domain.com --plugins cert-auto"}')"
    return 1
  }

  # Security: Validate domain name (RFC compliant, length limits, internal domain check)
  if ! validators::domain "${domain}"; then
    core::log error "invalid or internal domain" "$(printf '{"domain":"%s"}' "${domain}")"
    return 1
  fi

  local vision_port="${XRAY_VISION_PORT:-8443}"
  core::log info "cert-auto setting up auto TLS" "$(printf '{"domain":"%s","port":"%s"}' "${domain}" "${vision_port}")"

  # Install Caddy
  core::log debug "cert-auto installing Caddy" "{}"
  caddy::install || {
    core::log error "cert-auto failed to install caddy" "{}"
    return 1
  }

  # Configure Caddy automatic TLS
  core::log debug "cert-auto configuring Caddy auto TLS" "{}"
  caddy::setup_auto_tls "${domain}" "${vision_port}" || {
    core::log error "cert-auto failed to setup auto TLS" "{}"
    return 1
  }

  # Set up certificate synchronization
  core::log debug "cert-auto setting up certificate sync" "{}"
  caddy::setup_cert_sync "${domain}" || {
    core::log error "cert-auto failed to setup cert sync" "{}"
    return 1
  }

  # Wait for certificate generation
  core::log debug "cert-auto waiting for certificate generation" "{}"
  caddy::wait_for_cert "${domain}" || {
    core::log error "cert-auto certificate generation timeout" "{}"
    return 1
  }

  local cert_dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  core::log info "cert-auto setup complete" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${domain}" "${cert_dir}")"

  # Verify certificate files
  if [[ -f "${cert_dir}/fullchain.pem" && -f "${cert_dir}/privkey.pem" ]]; then
    core::log debug "cert-auto certificates verified" "$(printf '{"fullchain":"%s","privkey":"%s"}' "${cert_dir}/fullchain.pem" "${cert_dir}/privkey.pem")"
  else
    core::log error "cert-auto certificates not found after setup" "$(printf '{"cert_dir":"%s"}' "${cert_dir}")"
    return 1
  fi
}

cert_auto::service_setup() {
  local cert_dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  [[ -f "${cert_dir}/privkey.pem" ]] || return 0

  # Set certificate file permissions
  chown root:xray "${cert_dir}/privkey.pem" "${cert_dir}/fullchain.pem" 2> /dev/null || true
  chmod 640 "${cert_dir}/privkey.pem" || true
  chmod 644 "${cert_dir}/fullchain.pem" || true

  core::log info "cert-auto certificate permissions set" "$(printf '{"cert_dir":"%s"}' "${cert_dir}")"
}
