#!/usr/bin/env bash
# Caddy 自动 TLS 管理模块
# 参考 233boy/Xray 实现

caddy::bin() { echo "/usr/local/bin/caddy"; }
caddy::config_dir() { echo "/usr/local/etc/caddy"; }
caddy::config_file() { echo "$(caddy::config_dir)/Caddyfile"; }
caddy::cert_dir() { echo "/usr/local/etc/xray/certs"; }
caddy::systemd_file() { echo "/etc/systemd/system/caddy.service"; }

caddy::detect_arch() {
  local arch_u
  arch_u="$(uname -m)"
  case "${arch_u}" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *)
      core::log error "unsupported arch" "$(printf '{"arch":"%s"}' "${arch_u}")"
      exit 2
      ;;
  esac
}

caddy::get_latest_version() {
  curl -fsSL https://api.github.com/repos/caddyserver/caddy/releases/latest \
    | grep -o '"tag_name":[[:space:]]*"[^"]*"' \
    | cut -d'"' -f4
}

caddy::install() {
  if [[ -x "$(caddy::bin)" ]]; then
    core::log info "caddy already installed" "$(printf '{"version":"%s"}' "$("$(caddy::bin)" version 2> /dev/null | head -n1 | cut -d' ' -f1)")"
    return 0
  fi

  local version arch tmpdir tmpfile
  version="$(caddy::get_latest_version)"
  arch="$(caddy::detect_arch)"
  tmpdir="$(mktemp -d)"
  tmpfile="${tmpdir}/caddy.tar.gz"

  # Store tmpdir in a global variable for trap cleanup
  _CADDY_TMPDIR="${tmpdir}"
  trap 'rm -rf "${_CADDY_TMPDIR:-}" 2>/dev/null || true; unset _CADDY_TMPDIR' EXIT

  local url="https://github.com/caddyserver/caddy/releases/download/${version}/caddy_${version:1}_linux_${arch}.tar.gz"

  core::log info "downloading caddy" "$(printf '{"version":"%s","arch":"%s"}' "${version}" "${arch}")"
  curl -fsSL "${url}" -o "${tmpfile}" || {
    core::log error "download failed" "$(printf '{"url":"%s"}' "${url}")"
    return 1
  }

  tar -xzf "${tmpfile}" -C "${tmpdir}" caddy || {
    core::log error "extract failed" "{}"
    return 1
  }

  io::install_file "${tmpdir}/caddy" "$(caddy::bin)" 0755
  core::log info "caddy installed" "$(printf '{"bin":"%s","version":"%s"}' "$(caddy::bin)" "${version}")"
}

caddy::create_systemd_service() {
  cat > "$(caddy::systemd_file)" << 'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/local/bin/caddy run --environ --config /usr/local/etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /usr/local/etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable caddy
  core::log info "caddy service created" "$(printf '{"service":"%s"}' "$(caddy::systemd_file)")"
}

caddy::setup_auto_tls() {
  local domain="${1}" xray_port="${2:-8443}"

  # Configurable Caddy ports (defaults: 80 for HTTP, 8444 for HTTPS to avoid conflict with Xray Vision)
  local caddy_http_port="${CADDY_HTTP_PORT:-80}"
  local caddy_https_port="${CADDY_HTTPS_PORT:-8444}"
  local caddy_fallback_port="${CADDY_FALLBACK_PORT:-8080}"

  # Validate port numbers (1-65535)
  for port_info in "${caddy_http_port}:CADDY_HTTP_PORT" "${caddy_https_port}:CADDY_HTTPS_PORT" "${caddy_fallback_port}:CADDY_FALLBACK_PORT"; do
    local port="${port_info%%:*}" name="${port_info#*:}"
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ "${port}" -lt 1 ]] || [[ "${port}" -gt 65535 ]]; then
      core::log error "invalid port number" "$(printf '{"port":"%s","name":"%s","valid_range":"1-65535"}' "${port}" "${name}")"
      return 1
    fi
  done

  # Check for port conflicts with Xray Vision
  if [[ "${caddy_https_port}" == "${xray_port}" ]]; then
    core::log error "port conflict detected" "$(printf '{"caddy_https_port":"%s","xray_vision_port":"%s"}' "${caddy_https_port}" "${xray_port}")"
    return 1
  fi

  io::ensure_dir "$(caddy::config_dir)" 0755
  io::ensure_dir "$(caddy::cert_dir)" 0755

  core::log debug "configuring caddy" "$(printf '{"http_port":"%s","https_port":"%s","fallback_port":"%s"}' "${caddy_http_port}" "${caddy_https_port}" "${caddy_fallback_port}")"

  # 创建 Caddyfile 配置 - Caddy 作为 fallback 服务，不占用 443
  cat > "$(caddy::config_file)" << EOF
{
  admin off
  http_port ${caddy_http_port}
  https_port ${caddy_https_port}
}

:${caddy_fallback_port} {
  respond "404 - Page Not Found" 404
}

${domain}:${caddy_https_port} {
  reverse_proxy 127.0.0.1:${xray_port}
}
EOF

  # 创建 systemd 服务
  caddy::create_systemd_service

  # 启动 Caddy
  systemctl start caddy || {
    core::log error "failed to start caddy" "{}"
    return 1
  }

  core::log info "caddy configured for auto TLS" "$(printf '{"domain":"%s","config":"%s","http_port":"%s","https_port":"%s"}' "${domain}" "$(caddy::config_file)" "${caddy_http_port}" "${caddy_https_port}")"
}

caddy::wait_for_cert() {
  local domain="${1}" max_wait=120 waited=0

  core::log info "waiting for certificate" "$(printf '{"domain":"%s"}' "${domain}")"

  # 等待 Caddy 启动并获取证书
  while [[ $waited -lt $max_wait ]]; do
    # 检查 Caddy 是否正在运行
    if systemctl is-active --quiet caddy; then
      core::log debug "caddy service is active" "$(printf '{"waited":"%ds"}' "${waited}")"

      # 先检查 Caddy 是否已获取证书（检查 Caddy 自己的证书目录）
      if ls /root/.local/share/caddy/certificates/*/"${domain}.crt" > /dev/null 2>&1; then
        core::log debug "caddy certificate found in cert directory" "$(printf '{"domain":"%s"}' "${domain}")"

        # 尝试同步证书
        if /usr/local/bin/caddy-cert-sync > /dev/null 2>&1; then
          core::log debug "certificate sync succeeded" "{}"
        else
          core::log debug "certificate sync failed, will retry" "{}"
        fi
      else
        core::log debug "caddy certificate not ready yet" "$(printf '{"waited":"%ds"}' "${waited}")"
      fi

      # 检查证书是否已同步到 Xray 目录
      if [[ -f "$(caddy::cert_dir)/fullchain.pem" && -f "$(caddy::cert_dir)/privkey.pem" ]]; then
        core::log info "certificate ready" "$(printf '{"domain":"%s","waited":"%ds"}' "${domain}" "${waited}")"
        return 0
      fi
    else
      core::log debug "waiting for caddy service to start" "$(printf '{"waited":"%ds"}' "${waited}")"
    fi

    sleep 5
    ((waited += 5))
  done

  core::log error "certificate timeout" "$(printf '{"domain":"%s","waited":"%ds"}' "${domain}" "${waited}")"
  return 1
}

caddy::setup_cert_sync() {
  local domain="${1}"

  # 创建证书同步脚本（动态查找证书路径）
  cat > /usr/local/bin/caddy-cert-sync << 'EOF'
#!/bin/bash
# 同步 Caddy 证书到 Xray 目录
set -euo pipefail

DOMAIN="${1:-}"
CADDY_CERT_BASE="/root/.local/share/caddy/certificates"
XRAY_CERT_DIR="/usr/local/etc/xray/certs"

if [[ -z "${DOMAIN}" ]]; then
  echo "[caddy-cert-sync] ERROR: domain not specified" >&2
  exit 1
fi

# 动态查找域名证书（支持任意 ACME provider 目录结构）
cert_file=$(find "${CADDY_CERT_BASE}" -type f -name "${DOMAIN}.crt" -print -quit 2>/dev/null || true)
key_file=$(find "${CADDY_CERT_BASE}" -type f -name "${DOMAIN}.key" -print -quit 2>/dev/null || true)

if [[ -f "${cert_file}" && -f "${key_file}" ]]; then
  mkdir -p "${XRAY_CERT_DIR}"
  cp "${cert_file}" "${XRAY_CERT_DIR}/fullchain.pem"
  cp "${key_file}" "${XRAY_CERT_DIR}/privkey.pem"
  chmod 644 "${XRAY_CERT_DIR}/fullchain.pem"
  chmod 640 "${XRAY_CERT_DIR}/privkey.pem"
  chown root:xray "${XRAY_CERT_DIR}"/*.pem 2>/dev/null || true
  echo "[caddy-cert-sync] certificates updated for ${DOMAIN}"
  exit 0
fi

echo "[caddy-cert-sync] no certificates found for ${DOMAIN}" >&2
exit 1
EOF

  chmod +x /usr/local/bin/caddy-cert-sync

  # 创建 systemd service 传递域名参数
  cat > /etc/systemd/system/caddy-cert-sync.service << EOF
[Unit]
Description=Sync Caddy certificates to Xray
After=caddy.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/caddy-cert-sync ${domain}
EOF

  # 创建 systemd timer 定期同步

  cat > /etc/systemd/system/caddy-cert-sync.timer << EOF
[Unit]
Description=Sync Caddy certificates hourly
Requires=caddy-cert-sync.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable caddy-cert-sync.timer
  systemctl start caddy-cert-sync.timer

  core::log info "certificate sync configured" "$(printf '{"domain":"%s"}' "${domain}")"
}
