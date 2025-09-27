#!/usr/bin/env bash
XRF_PLUGIN_ID="cert-auto"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Auto-issue/renew TLS via Caddy for Vision"
XRF_PLUGIN_HOOKS=("configure_pre" "service_setup")
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${HERE}/modules/web/caddy.sh"

cert_auto::configure_pre() {
  local topology="" release_dir=""
  for kv in "${@}"; do case "${kv}" in topology=*) topology="${kv#*=}" ;; release_dir=*) release_dir="${kv#*=}" ;; esac done
  [[ "${topology}" == "vision-reality" ]] || return 0

  local domain="${XRAY_DOMAIN:-}"
  [[ -n "${domain}" ]] || {
    echo "[cert-auto] XRAY_DOMAIN not set; skip" >&2
    return 0
  }

  local vision_port="${XRAY_VISION_PORT:-8443}"

  echo "[cert-auto] setting up auto TLS for ${domain}" >&2

  # 安装 Caddy
  caddy::install || {
    echo "[cert-auto] failed to install caddy" >&2
    return 1
  }

  # 配置 Caddy 自动 TLS
  caddy::setup_auto_tls "${domain}" "${vision_port}" || {
    echo "[cert-auto] failed to setup auto TLS" >&2
    return 1
  }

  # 设置证书同步
  caddy::setup_cert_sync "${domain}" || {
    echo "[cert-auto] failed to setup cert sync" >&2
    return 1
  }

  # 等待证书生成
  caddy::wait_for_cert "${domain}" || {
    echo "[cert-auto] certificate generation timeout" >&2
    return 1
  }

  echo "[cert-auto] auto TLS setup complete for ${domain}" >&2
}

cert_auto::service_setup() {
  local cert_dir="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
  [[ -f "${cert_dir}/privkey.pem" ]] || return 0

  # 设置证书文件权限
  chown root:xray "${cert_dir}/privkey.pem" "${cert_dir}/fullchain.pem" 2> /dev/null || true
  chmod 600 "${cert_dir}/privkey.pem" || true
  chmod 644 "${cert_dir}/fullchain.pem" || true

  echo "[cert-auto] certificate permissions set" >&2
}