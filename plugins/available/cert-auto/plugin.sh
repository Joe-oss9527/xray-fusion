#!/usr/bin/env bash
# shellcheck disable=SC2034  # Plugin metadata variables are used by the plugin system
XRF_PLUGIN_ID="cert-auto"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Auto-issue/renew TLS via Caddy for Vision"
XRF_PLUGIN_HOOKS=("configure_pre" "service_setup")
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/web/caddy.sh"

# Validate domain - use shared validation from args module
_validate_domain() {
  local domain="${1}"

  # Reuse RFC-compliant validation from lib/args.sh
  if [[ ! "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    core::log error "invalid domain format" "$(printf '{"domain":"%s"}' "${domain}")"
    return 1
  fi

  # Prevent localhost and internal domains
  case "${domain}" in
    localhost | *.local | 127.* | 10.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].* | 192.168.*)
      core::log error "internal domain not allowed" "$(printf '{"domain":"%s"}' "${domain}")"
      return 1
      ;;
  esac

  return 0
}

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

  # Security: Validate domain name
  if ! _validate_domain "${domain}"; then
    core::log error "invalid or internal domain" "$(printf '{"domain":"%s"}' "${domain}")"
    return 1
  fi

  local vision_port="${XRAY_VISION_PORT:-8443}"
  core::log info "cert-auto setting up auto TLS" "$(printf '{"domain":"%s","port":"%s"}' "${domain}" "${vision_port}")"

  # 安装 Caddy
  core::log debug "cert-auto installing Caddy" "{}"
  caddy::install || {
    core::log error "cert-auto failed to install caddy" "{}"
    return 1
  }

  # 配置 Caddy 自动 TLS
  core::log debug "cert-auto configuring Caddy auto TLS" "{}"
  caddy::setup_auto_tls "${domain}" "${vision_port}" || {
    core::log error "cert-auto failed to setup auto TLS" "{}"
    return 1
  }

  # 设置证书同步
  core::log debug "cert-auto setting up certificate sync" "{}"
  caddy::setup_cert_sync "${domain}" || {
    core::log error "cert-auto failed to setup cert sync" "{}"
    return 1
  }

  # 等待证书生成
  core::log debug "cert-auto waiting for certificate generation" "{}"
  caddy::wait_for_cert "${domain}" || {
    core::log error "cert-auto certificate generation timeout" "{}"
    return 1
  }

  local cert_dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  core::log info "cert-auto setup complete" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${domain}" "${cert_dir}")"

  # 验证证书文件
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

  # 设置证书文件权限
  chown root:xray "${cert_dir}/privkey.pem" "${cert_dir}/fullchain.pem" 2> /dev/null || true
  chmod 640 "${cert_dir}/privkey.pem" || true
  chmod 644 "${cert_dir}/fullchain.pem" || true

  core::log info "cert-auto certificate permissions set" "$(printf '{"cert_dir":"%s"}' "${cert_dir}")"
}
