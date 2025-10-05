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

  # 创建证书同步脚本（原子复制 + 证书验证）
  cat > /usr/local/bin/caddy-cert-sync << 'EOF'
#!/bin/bash
# 原子同步 Caddy 证书到 Xray 目录
set -euo pipefail

DOMAIN="${1:-}"
CADDY_CERT_BASE="/root/.local/share/caddy/certificates"
XRAY_CERT_DIR="/usr/local/etc/xray/certs"
XRF_DEBUG="${XRF_DEBUG:-false}"
XRF_JSON="${XRF_JSON:-false}"

# Embedded logging (compatible with core::log from lib/core.sh)
log() {
  local lvl="${1}"
  shift
  local msg="${1}"

  # Filter debug messages unless XRF_DEBUG is true
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  # All logs to stderr
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"[caddy-cert-sync] %s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  else
    printf '[%s] %-5s [caddy-cert-sync] %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  fi
}

cleanup_tmpdir() {
  if [[ -n "${tmpdir:-}" && -d "${tmpdir}" ]]; then
    rm -rf "${tmpdir}" 2>/dev/null || true
  fi
}

trap cleanup_tmpdir EXIT INT TERM HUP

if [[ -z "${DOMAIN}" ]]; then
  log error "domain not specified"
  exit 1
fi

# 动态查找域名证书（支持任意 ACME provider 目录结构，选择最新的）
cert_file=$(find "${CADDY_CERT_BASE}" -maxdepth 4 -type f -name "${DOMAIN}.crt" \
  -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
key_file=$(find "${CADDY_CERT_BASE}" -maxdepth 4 -type f -name "${DOMAIN}.key" \
  -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [[ ! -f "${cert_file}" ]]; then
  log error "certificate file not found for ${DOMAIN}"
  log error "searched in: ${CADDY_CERT_BASE}"
  exit 1
fi

if [[ ! -f "${key_file}" ]]; then
  log error "private key file not found for ${DOMAIN}"
  log error "searched in: ${CADDY_CERT_BASE}"
  exit 1
fi

log info "found certificate: ${cert_file}"
log info "found private key: ${key_file}"

# 证书验证：检查是否已过期
if ! openssl x509 -in "${cert_file}" -noout -checkend 0 >/dev/null 2>&1; then
  log error "certificate has already expired - aborting sync"
  exit 1
fi

# 证书验证：检查有效期（7天警告窗口）
if ! openssl x509 -in "${cert_file}" -noout -checkend 604800 >/dev/null 2>&1; then
  log warn "certificate expires within 7 days - renewal may have failed"
fi

# 证书和私钥匹配性验证（支持 RSA 和 ECDSA）
validate_cert_key_match() {
  local cert="${1}"
  local key="${2}"

  # 通用方法：比较公钥（适用于 RSA 和 ECDSA）
  local cert_pub key_pub
  cert_pub=$(openssl x509 -in "${cert}" -pubkey -noout 2>/dev/null | sha256sum | awk '{print $1}')
  key_pub=$(openssl pkey -in "${key}" -pubout 2>/dev/null | sha256sum | awk '{print $1}')

  if [[ -z "${cert_pub}" || -z "${key_pub}" ]]; then
    log error "failed to extract public keys for validation"
    return 1
  fi

  if [[ "${cert_pub}" != "${key_pub}" ]]; then
    log error "certificate and private key do not match"
    log error "cert pubkey hash: ${cert_pub}"
    log error "key pubkey hash: ${key_pub}"
    return 1
  fi

  log info "certificate and private key validated successfully"
  return 0
}

if ! validate_cert_key_match "${cert_file}" "${key_file}"; then
  exit 1
fi

# 原子复制：使用同分区临时目录 + mv（POSIX 原子操作）
mkdir -p "${XRAY_CERT_DIR}"
tmpdir=$(mktemp -d -p "${XRAY_CERT_DIR}" .cert-sync.XXXXXX)

# 备份现有证书（用于失败回滚）
backup_dir="${XRAY_CERT_DIR}/.backup.$$"
mkdir -p "${backup_dir}"

if [[ -f "${XRAY_CERT_DIR}/fullchain.pem" ]]; then
  cp -a "${XRAY_CERT_DIR}/fullchain.pem" "${backup_dir}/fullchain.pem"
fi
if [[ -f "${XRAY_CERT_DIR}/privkey.pem" ]]; then
  cp -a "${XRAY_CERT_DIR}/privkey.pem" "${backup_dir}/privkey.pem"
fi

# 复制到临时目录
cp "${cert_file}" "${tmpdir}/fullchain.pem"
cp "${key_file}" "${tmpdir}/privkey.pem"

# 设置权限（在临时目录中）
chmod 644 "${tmpdir}/fullchain.pem" || {
  log error "failed to set permissions on fullchain.pem"
  rm -rf "${tmpdir}" "${backup_dir}"
  exit 1
}

chmod 640 "${tmpdir}/privkey.pem" || {
  log error "failed to set permissions on privkey.pem"
  rm -rf "${tmpdir}" "${backup_dir}"
  exit 1
}

# 设置所有权（验证 xray 组存在）
if getent group xray >/dev/null 2>&1; then
  chown root:xray "${tmpdir}"/*.pem || {
    log error "failed to set ownership (root:xray)"
    rm -rf "${tmpdir}" "${backup_dir}"
    exit 1
  }
else
  log warn "xray group does not exist - files will be owned by root:root"
  chown root:root "${tmpdir}"/*.pem
fi

# 原子移动（带回滚能力）
if ! mv -f "${tmpdir}/fullchain.pem" "${XRAY_CERT_DIR}/fullchain.pem"; then
  log error "failed to move fullchain.pem"
  rm -rf "${tmpdir}" "${backup_dir}"
  exit 1
fi

if ! mv -f "${tmpdir}/privkey.pem" "${XRAY_CERT_DIR}/privkey.pem"; then
  log error "failed to move privkey.pem - rolling back fullchain"
  # 回滚：恢复旧的 fullchain
  if [[ -f "${backup_dir}/fullchain.pem" ]]; then
    mv -f "${backup_dir}/fullchain.pem" "${XRAY_CERT_DIR}/fullchain.pem"
  fi
  rm -rf "${tmpdir}" "${backup_dir}"
  exit 1
fi

# 成功 - 清理备份和临时目录
rm -rf "${backup_dir}"
rmdir "${tmpdir}"
trap - EXIT

log info "certificates atomically updated for ${DOMAIN}"

# 重启 Xray 服务（Xray 不支持 SIGHUP 优雅重载）
# 参考: https://github.com/XTLS/Xray-core/discussions/1060
if systemctl is-active --quiet xray 2>/dev/null; then
  log info "restarting xray service to apply new certificates"
  if systemctl restart xray >/dev/null 2>&1; then
    log info "xray service restarted successfully"
  else
    log error "failed to restart xray service"
    exit 1
  fi
fi

exit 0
EOF

  chmod +x /usr/local/bin/caddy-cert-sync

  # 创建 systemd service 用于证书同步
  cat > /etc/systemd/system/cert-reload.service << EOF
[Unit]
Description=Sync Caddy certificates to Xray for ${domain}
After=caddy.service
PartOf=caddy.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/caddy-cert-sync ${domain}

# 环境变量（与项目日志系统兼容）
Environment="XRF_DEBUG=\${XRF_DEBUG:-false}"
Environment="XRF_JSON=\${XRF_JSON:-false}"

# 安全加固
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/usr/local/etc/xray/certs
NoNewPrivileges=true

# 资源限制
MemoryMax=50M
TasksMax=10
EOF

  # 创建 systemd timer 定期检查证书（比 path 单元更可靠）
  # 参考: systemd Path 单元在某些文件系统和嵌套目录场景下不可靠
  cat > /etc/systemd/system/cert-reload.timer << EOF
[Unit]
Description=Periodic certificate sync check for ${domain}
PartOf=caddy.service

[Timer]
# 启动后 2 分钟首次运行
OnBootSec=2min
# 每 10 分钟检查一次（证书变更频率低，10分钟足够）
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable cert-reload.timer
  systemctl start cert-reload.timer

  core::log info "certificate sync configured (timer-based)" "$(printf '{"domain":"%s","interval":"10min"}' "${domain}")"
}
