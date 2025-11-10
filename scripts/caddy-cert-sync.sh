#!/usr/bin/env bash
# 原子同步 Caddy 证书到 Xray 目录
set -euo pipefail

# Detect script location (for sourcing defaults if running from repo)
# When installed to /usr/local/bin, defaults.sh won't be available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${SCRIPT_DIR}" == */scripts ]]; then
  # Running from repo
  HERE="$(dirname "${SCRIPT_DIR}")"
else
  # Running from /usr/local/bin or other location
  HERE=""
fi

# Lock file management (atomic creation with install(1))
# Uses /var/lib/xray-fusion/locks/ for persistent storage (not tmpfs)
LOCK_FILE="/var/lib/xray-fusion/locks/caddy-cert-sync.lock"
LOCK_DIR="$(dirname "${LOCK_FILE}")"

# Create lock directory
if ! test -d "${LOCK_DIR}"; then
  if ! mkdir -p "${LOCK_DIR}" 2> /dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo mkdir -p "${LOCK_DIR}" || {
        printf '[%s] %-5s [caddy-cert-sync] failed to create lock directory\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
        exit 1
      }
    else
      printf '[%s] %-5s [caddy-cert-sync] cannot create lock directory (no sudo)\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
      exit 1
    fi
  fi
fi

##
# Standalone version of core::ensure_lock_writable (compatible with lib/core.sh)
#
# Ensures lock file is writable by current user. Lightweight version for
# standalone scripts that cannot source lib/core.sh.
#
# Arguments:
#   $1 - Lock file path
#
# Returns:
#   0 - Success, 1 - Failed to make writable
##
ensure_lock_writable() {
  local lock="${1}"

  # File doesn't exist, nothing to fix
  [[ ! -f "${lock}" ]] && return 0

  # Fix ownership (may be root-owned from previous sudo run)
  if ! chown "$(id -u):$(id -g)" "${lock}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo chown "$(id -u):$(id -g)" "${lock}" 2>/dev/null || return 1
    else
      return 1
    fi
  fi

  # Fix permissions
  if ! chmod 0644 "${lock}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo chmod 0644 "${lock}" 2>/dev/null || return 1
    else
      return 1
    fi
  fi

  return 0
}

# Atomic lock file creation (prevents TOCTOU - CWE-362)
if ! test -f "${LOCK_FILE}" 2> /dev/null; then
  # Use install(1) for atomic creation with correct ownership
  if ! install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${LOCK_FILE}" 2> /dev/null; then
    # Fallback to sudo
    if command -v sudo > /dev/null 2>&1; then
      sudo install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${LOCK_FILE}" 2> /dev/null || {
        printf '[%s] %-8s [caddy-cert-sync] failed to create lock file\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
        exit 1
      }
    else
      # Last resort: create with touch (may have wrong ownership)
      touch "${LOCK_FILE}" 2> /dev/null || {
        printf '[%s] %-8s [caddy-cert-sync] cannot create lock file\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
        exit 1
      }
    fi
  fi
fi

# Ensure lock file is writable (handles previous root runs - CWE-283)
ensure_lock_writable "${LOCK_FILE}" || {
  printf '[%s] %-8s [caddy-cert-sync] lock file not writable\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
  exit 1
}

# Non-blocking lock acquisition
exec 200>> "${LOCK_FILE}"
if ! flock -n 200; then
  printf '[%s] %-5s [caddy-cert-sync] another sync process is running, skipping\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "info" >&2
  exit 0
fi

# Try to source defaults (if available), otherwise use hardcoded fallbacks
# This script can run standalone from /usr/local/bin or from repo
if [[ -f "${HERE:-}/lib/defaults.sh" ]]; then
  # shellcheck source=../lib/defaults.sh
  . "${HERE}/lib/defaults.sh"
  CADDY_CERT_BASE="${DEFAULT_CADDY_CERT_BASE}"
  XRAY_CERT_DIR="${DEFAULT_XRAY_CERT_DIR}"
  XRF_DEBUG="${XRF_DEBUG:-${DEFAULT_XRF_DEBUG}}"
  XRF_JSON="${XRF_JSON:-${DEFAULT_XRF_JSON}}"
else
  # Fallback values (for standalone execution from /usr/local/bin)
  CADDY_CERT_BASE="/root/.local/share/caddy/certificates"
  XRAY_CERT_DIR="/usr/local/etc/xray/certs"
  XRF_DEBUG="${XRF_DEBUG:-false}"
  XRF_JSON="${XRF_JSON:-false}"
fi

DOMAIN="${1:-}"

##
# Standalone logging function compatible with core::log
#
# This is a lightweight version for standalone scripts that cannot
# source lib/core.sh. Maintains compatibility with the main logging
# system's format and behavior.
#
# Arguments:
#   $1 - Log level (debug|info|warn|error)
#   $2 - Message string
#
# Globals:
#   XRF_JSON - If "true", output JSON format
#   XRF_DEBUG - If "true", show debug messages
#
# Output:
#   Log line to stderr (text or JSON format)
#
# Example:
#   log info "Certificate synced successfully"
#   log error "Failed to sync certificate"
##
log() {
  local lvl="${1}"
  shift
  local msg="${1}"

  # Filter debug messages unless XRF_DEBUG is true
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  # Generate ISO 8601 timestamp (UTC)
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # All logs to stderr (consistent with lib/core.sh)
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"[caddy-cert-sync] %s"}\n' \
      "${ts}" "${lvl}" "${msg}" >&2
  else
    # Use consistent width: %-8s (matches lib/core.sh format)
    printf '[%s] %-8s [caddy-cert-sync] %s\n' \
      "${ts}" "${lvl}" "${msg}" >&2
  fi
}

cleanup_tmpdir() {
  if [[ -n "${tmpdir:-}" && -d "${tmpdir}" ]]; then
    rm -rf "${tmpdir}" 2> /dev/null || true
  fi
}

trap cleanup_tmpdir EXIT INT TERM HUP

if [[ -z "${DOMAIN}" ]]; then
  log error "domain not specified"
  exit 1
fi

# 动态查找域名证书（限制深度为 3 层，覆盖所有 ACME providers）
# Caddy 目录结构: certificates/<provider>/<domain>/<domain>.crt (最大深度 3 层)
cert_file=$(find "${CADDY_CERT_BASE}" -maxdepth 3 -type f -name "${DOMAIN}.crt" \
  -printf '%T@ %p\n' 2> /dev/null | sort -rn | head -1 | cut -d' ' -f2-)
key_file=$(find "${CADDY_CERT_BASE}" -maxdepth 3 -type f -name "${DOMAIN}.key" \
  -printf '%T@ %p\n' 2> /dev/null | sort -rn | head -1 | cut -d' ' -f2-)

log debug "certificate search completed" "$(printf '{"base":"%s","maxdepth":3,"cert_found":"%s","key_found":"%s"}' \
  "${CADDY_CERT_BASE}" "${cert_file:-none}" "${key_file:-none}")"

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
if ! openssl x509 -in "${cert_file}" -noout -checkend 0 > /dev/null 2>&1; then
  log error "certificate has already expired - aborting sync"
  exit 1
fi

# 证书验证：检查有效期（7天警告窗口）
if ! openssl x509 -in "${cert_file}" -noout -checkend 604800 > /dev/null 2>&1; then
  log warn "certificate expires within 7 days - renewal may have failed"
fi

# 证书和私钥匹配性验证（支持 RSA 和 ECDSA）
validate_cert_key_match() {
  local cert="${1}"
  local key="${2}"

  # 通用方法：比较公钥（适用于 RSA 和 ECDSA）
  local cert_pub key_pub
  cert_pub=$(openssl x509 -in "${cert}" -pubkey -noout 2> /dev/null | sha256sum | awk '{print $1}')
  key_pub=$(openssl pkey -in "${key}" -pubout 2> /dev/null | sha256sum | awk '{print $1}')

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
if getent group xray > /dev/null 2>&1; then
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
if systemctl is-active --quiet xray 2> /dev/null; then
  log info "restarting xray service to apply new certificates"
  if systemctl restart xray > /dev/null 2>&1; then
    log info "xray service restarted successfully"
  else
    log error "failed to restart xray service"
    exit 1
  fi
fi

exit 0
