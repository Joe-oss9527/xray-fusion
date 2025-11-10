#!/usr/bin/env bash
# xray-fusion online installer
# Usage: curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- [options]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${XRF_REPO_URL:-https://github.com/Joe-oss9527/xray-fusion.git}"
BRANCH="${XRF_BRANCH:-main}"
INSTALL_DIR="${XRF_INSTALL_DIR:-/usr/local/xray-fusion}"

# Runtime variables (will be set by args::parse)
TOPOLOGY=""
DOMAIN=""
VERSION=""
PLUGINS=""
DEBUG=""
PROXY=""

SYMLINK_PATH="/usr/local/bin/xrf"
INSTALL_DIR_PREEXISTING="false"
INSTALL_MARKER=""

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} ${*}"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} ${*}"; }
log_error() { echo -e "${RED}[ERROR]${NC} ${*}"; }
log_debug() { [[ "${DEBUG}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} ${*}" || true; }

# Error handling
error_exit() {
  log_error "${1}"
  cleanup
  exit 1
}

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

# Load unified argument parsing (embedded for installation)
source_args_module() {
  # Create temporary args module for installation
  cat > "${TMP_DIR}/args.sh" << 'ARGS_EOF'
#!/usr/bin/env bash
# Temporary unified argument parsing for installation

# Initialize default values
args::init() {
  TOPOLOGY="reality-only"
  DOMAIN=""
  VERSION="latest"
  PLUGINS=""
  DEBUG="false"
}

# Parse command line arguments
args::parse() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --topology|-t)
        args::validate_topology "${2:-}" || return 1
        TOPOLOGY="${2}"
        shift 2
        ;;
      --domain|-d)
        args::validate_domain "${2:-}" || return 1
        DOMAIN="${2}"
        shift 2
        ;;
      --version|-v)
        args::validate_version "${2:-}" || return 1
        VERSION="${2}"
        shift 2
        ;;
      --plugins|-p)
        PLUGINS="${2:-}"
        shift 2
        ;;
      --proxy)
        PROXY="${2:-}"
        shift 2
        ;;
      --install-dir)
        INSTALL_DIR="${2:-}"
        shift 2
        ;;
      --debug)
        DEBUG="true"
        shift
        ;;
      --help|-h)
        return 10
        ;;
      --)
        shift
        break
        ;;
      *)
        log_error "Unknown argument: ${1}"
        return 1
        ;;
    esac
  done

  # Validate configuration
  args::validate_config || return 1
  return 0
}

# Validation functions
args::validate_topology() {
  local topology="${1:-}"
  [[ -n "${topology}" ]] || { log_error "Topology cannot be empty"; return 1; }
  case "${topology}" in
    reality-only|vision-reality) return 0 ;;
    *) log_error "Invalid topology: ${topology}. Must be 'reality-only' or 'vision-reality'"; return 1 ;;
  esac
}

args::validate_domain() {
  local domain="${1:-}"
  [[ -z "${domain}" ]] && return 0
  [[ "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]] || {
    log_error "Invalid domain format: ${domain}"
    return 1
  }
  case "${domain}" in
    localhost|*.local|127.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*)
      log_error "Internal domain not allowed: ${domain}"
      return 1
      ;;
  esac
}

args::validate_version() {
  local version="${1:-}"
  [[ -n "${version}" ]] || { log_error "Version cannot be empty"; return 1; }
  [[ "${version}" == "latest" ]] && return 0
  [[ "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    log_error "Invalid version format: ${version}. Use 'latest' or 'vX.Y.Z'"
    return 1
  }
}

args::validate_config() {
  if [[ "${TOPOLOGY}" == "vision-reality" && -z "${DOMAIN}" ]]; then
    log_error "Vision-reality topology requires --domain parameter"
    return 1
  fi
}

# Show help
args::show_help() {
  cat << EOF
xray-fusion online installer

Usage:
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- [options]

Options:
  --topology, -t <type>         Installation topology (reality-only|vision-reality)
  --domain, -d <domain>         Domain for vision-reality topology (required)
  --version, -v <version>       Xray version to install (default: latest)
  --plugins, -p <list>          Comma-separated list of plugins to enable
  --proxy <url>                 Use proxy for downloads
  --install-dir <path>          Installation directory (default: /usr/local/xray-fusion)
  --debug                       Enable debug output
  --help, -h                    Show this help

Examples:
  # Reality-only installation
  curl -sL install.sh | bash -s -- --topology reality-only

  # Vision-Reality with domain and plugins
  curl -sL install.sh | bash -s -- --topology vision-reality --domain your.domain.com --plugins cert-auto

  # Specific version
  curl -sL install.sh | bash -s -- --topology reality-only --version v1.8.1

Environment Variables:
  XRF_REPO_URL      Repository URL (default: https://github.com/Joe-oss9527/xray-fusion.git)
  XRF_BRANCH        Branch to use (default: main)
  XRF_INSTALL_DIR   Installation directory (default: /usr/local/xray-fusion)

Xray Configuration Variables:
  XRAY_SNI          SNI domain (default: www.microsoft.com)
  XRAY_PORT         Listen port (default: 443)
  XRAY_UUID         User UUID (auto-generated if not set)
  XRAY_*            All other Xray configuration variables

EOF
}
ARGS_EOF

  source "${TMP_DIR}/args.sh"
}

# Show help
show_help() {
  args::show_help
}

# Parse command line arguments
parse_args() {
  args::init

  local rc=0
  args::parse "$@" || rc=$?

  if [[ ${rc} -eq 10 ]]; then
    show_help
    exit 0
  elif [[ ${rc} -ne 0 ]]; then
    show_help
    exit 1
  fi
}

# Setup environment from parsed arguments
setup_environment() {
  # Set XRAY_DOMAIN for Xray configuration
  if [[ -n "${DOMAIN}" ]]; then
    export XRAY_DOMAIN="${DOMAIN}"
  fi

  # Set debug mode
  if [[ "${DEBUG}" == "true" ]]; then
    export XRF_DEBUG="true"
  fi
}

# Early validation (inspired by 233boy style)
early_checks() {
  # Check if running as root
  [[ ${EUID} -ne 0 ]] && error_exit "当前非 ROOT用户，请使用 sudo 运行此脚本"

  # Check package manager (apt-get or yum)
  local cmd
  cmd=$(type -P apt-get || type -P yum || type -P dnf)
  [[ -z "${cmd}" ]] && error_exit "此脚本仅支持 Ubuntu/Debian/CentOS/RHEL 系统"

  # Check systemd
  if ! type -P systemctl > /dev/null 2>&1; then
    error_exit "此系统缺少 systemctl，请安装 systemd"
  fi

  # Check architecture (simplified)
  case $(uname -m) in
    x86_64 | amd64 | aarch64 | arm64) ;;
    *) error_exit "此脚本仅支持 64 位系统" ;;
  esac

  log_info "基础环境检查通过"
}

# System checks (simplified)
check_system() {
  log_info "检查系统要求..."

  # Basic OS detection without strict validation
  if [[ -f /etc/os-release ]]; then
    # Load in subshell to avoid variable pollution
    local os_info
    os_info=$(source /etc/os-release 2> /dev/null && echo "${ID:-unknown} ${VERSION_ID:-unknown}")
    log_debug "检测到系统: ${os_info}"
  else
    log_warn "无法检测操作系统版本，继续安装..."
  fi

  log_info "系统检查完成"
}

# Install dependencies
install_dependencies() {
  log_info "安装依赖包..."

  local deps="curl wget git jq unzip openssl"
  local missing_deps=""
  local pkg_manager=""

  # Detect package manager
  if command -v apt-get > /dev/null 2>&1; then
    pkg_manager="apt"
  elif command -v yum > /dev/null 2>&1; then
    pkg_manager="yum"
  elif command -v dnf > /dev/null 2>&1; then
    pkg_manager="dnf"
  else
    error_exit "未找到支持的包管理器 (apt/yum/dnf)"
  fi

  log_debug "检测到包管理器: ${pkg_manager}"

  # Check for missing dependencies
  for dep in ${deps}; do
    if ! command -v "${dep}" > /dev/null 2>&1; then
      missing_deps="${missing_deps} ${dep}"
    fi
  done

  # Install missing dependencies
  if [[ -n "${missing_deps}" ]]; then
    log_info "安装缺少的依赖包:${missing_deps}"
    case "${pkg_manager}" in
      apt)
        apt-get update -qq || log_warn "apt-get update 失败，继续安装..."
        apt-get install -y "${missing_deps}" || error_exit "依赖包安装失败"
        ;;
      yum)
        yum install -y epel-release || log_warn "epel-release 安装失败，继续..."
        yum install -y "${missing_deps}" || error_exit "依赖包安装失败"
        ;;
      dnf)
        dnf install -y "${missing_deps}" || error_exit "依赖包安装失败"
        ;;
      *)
        error_exit "不支持的包管理器: ${pkg_manager}"
        ;;
    esac
    log_info "依赖包安装完成"
  else
    log_info "所有依赖包已安装"
  fi
}

# Download xray-fusion
download_project() {
  log_info "从 ${REPO_URL} 下载 xray-fusion (分支: ${BRANCH})..."

  TMP_DIR="$(mktemp -d)"
  log_debug "使用临时目录: ${TMP_DIR}"

  # Set proxy if specified
  if [[ -n "${PROXY}" ]]; then
    export https_proxy="${PROXY}"
    export http_proxy="${PROXY}"
    log_info "使用代理: ${PROXY}"
  fi

  # Download with automatic fallback (git → tarball)
  log_debug "开始下载..."

  # Try git clone first (preferred)
  local download_success=false
  if command -v git > /dev/null 2>&1; then
    log_debug "尝试 git clone..."
    if git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMP_DIR}/xray-fusion" 2> /dev/null; then
      log_debug "git clone 成功"
      download_success=true
    else
      log_warn "git clone 失败，尝试 tarball 下载..."
    fi
  else
    log_debug "git 不可用，使用 tarball 下载"
  fi

  # Fallback to tarball if git failed
  if [[ "${download_success}" == "false" ]]; then
    local tarball_url="${REPO_URL%.git}/archive/refs/heads/${BRANCH}.tar.gz"
    local tarball="${TMP_DIR}/archive.tar.gz"

    log_debug "下载 tarball: ${tarball_url}"

    # Try curl first
    if command -v curl > /dev/null 2>&1; then
      if curl -fsSL --connect-timeout 10 --max-time 300 "${tarball_url}" -o "${tarball}" 2> /dev/null; then
        log_debug "tarball 下载成功 (curl)"
        download_success=true
      else
        log_warn "curl 下载失败"
        rm -f "${tarball}"
      fi
    fi

    # Fallback to wget
    if [[ "${download_success}" == "false" ]] && command -v wget > /dev/null 2>&1; then
      if wget -q --timeout=10 "${tarball_url}" -O "${tarball}" 2> /dev/null; then
        log_debug "tarball 下载成功 (wget)"
        download_success=true
      else
        log_warn "wget 下载失败"
        rm -f "${tarball}"
      fi
    fi

    # Extract tarball if downloaded
    if [[ "${download_success}" == "true" ]]; then
      log_debug "解压 tarball..."
      if tar -xzf "${tarball}" -C "${TMP_DIR}" 2> /dev/null; then
        # Rename extracted directory
        mv "${TMP_DIR}/xray-fusion-${BRANCH}" "${TMP_DIR}/xray-fusion" 2> /dev/null \
          || mv "${TMP_DIR}"/xray-fusion-* "${TMP_DIR}/xray-fusion" 2> /dev/null
        rm -f "${tarball}"
      else
        log_error "tarball 解压失败"
        rm -f "${tarball}"
        download_success=false
      fi
    fi
  fi

  # Check final result
  if [[ "${download_success}" == "false" ]]; then
    log_error "所有下载方式均失败 (git/curl/wget)"
    log_info "请检查网络连接或尝试使用代理"
    error_exit "下载失败"
  fi

  # === NEW: Verify download integrity ===

  # Source download verification module if available
  if [[ -f "${TMP_DIR}/xray-fusion/lib/download.sh" ]]; then
    # Need core.sh for logging
    if [[ -f "${TMP_DIR}/xray-fusion/lib/core.sh" ]]; then
      source "${TMP_DIR}/xray-fusion/lib/core.sh"
    fi
    source "${TMP_DIR}/xray-fusion/lib/download.sh"
  fi

  # 1. Get actual commit hash
  local actual_commit=""
  if [[ -d "${TMP_DIR}/xray-fusion/.git" ]]; then
    actual_commit=$(git -C "${TMP_DIR}/xray-fusion" rev-parse HEAD 2> /dev/null || true)
    if [[ -n "${actual_commit}" ]]; then
      log_debug "下载的 commit: ${actual_commit}"
    fi
  fi

  # 2. Verify against expected commit (if provided)
  if [[ -n "${XRF_EXPECTED_COMMIT:-}" && -n "${actual_commit}" ]]; then
    log_info "验证下载完整性..."
    if [[ "${actual_commit,,}" != "${XRF_EXPECTED_COMMIT,,}" ]]; then
      log_error "下载完整性验证失败：commit hash 不匹配"
      log_error "期望: ${XRF_EXPECTED_COMMIT}"
      log_error "实际: ${actual_commit}"
      error_exit "完整性验证失败（可能的中间人攻击）"
    fi
    log_info "✓ Commit 验证通过"
  else
    if [[ -n "${actual_commit}" ]]; then
      log_debug "跳过 commit 验证（未指定 XRF_EXPECTED_COMMIT）"
      log_debug "要启用验证，请设置: export XRF_EXPECTED_COMMIT='${actual_commit}'"
    fi
  fi

  # 3. Verify GPG signature (optional)
  if [[ -d "${TMP_DIR}/xray-fusion/.git" ]] && command -v gpg > /dev/null 2>&1; then
    if git -C "${TMP_DIR}/xray-fusion" verify-commit HEAD 2> /dev/null; then
      log_info "✓ GPG 签名验证通过"
    else
      log_debug "GPG 签名验证失败或 commit 未签名（可选验证）"
    fi
  fi

  # === END: Verification ===

  # Verify download completeness
  if [[ ! -d "${TMP_DIR}/xray-fusion" ]] || [[ ! -f "${TMP_DIR}/xray-fusion/bin/xrf" ]]; then
    error_exit "下载的文件不完整或损坏"
  fi

  log_info "下载完成"
}

# Install xray-fusion
install_xray_fusion() {
  log_info "Installing xray-fusion to ${INSTALL_DIR}..."

  # Create installation directory
  if [[ -d "${INSTALL_DIR}" ]]; then
    INSTALL_DIR_PREEXISTING="true"
  else
    INSTALL_DIR_PREEXISTING="false"
  fi
  mkdir -p "${INSTALL_DIR}"

  INSTALL_MARKER="${INSTALL_DIR}/.install_in_progress"
  : > "${INSTALL_MARKER}"

  # Copy files
  cp -r "${TMP_DIR}/xray-fusion"/* "${INSTALL_DIR}/"

  # Make scripts executable
  chmod +x "${INSTALL_DIR}/bin/xrf"
  find "${INSTALL_DIR}" -name "*.sh" -type f -exec chmod +x {} \;

  # Create symlink for global access
  if [[ -L "${SYMLINK_PATH}" ]]; then
    rm -f "${SYMLINK_PATH}"
  fi
  ln -sf "${INSTALL_DIR}/bin/xrf" "${SYMLINK_PATH}"

  # Verify symlink creation
  if [[ ! -L "${SYMLINK_PATH}" ]]; then
    log_warn "Failed to create global symlink: ${SYMLINK_PATH}"
  else
    log_debug "Created symlink: ${SYMLINK_PATH} -> ${INSTALL_DIR}/bin/xrf"
  fi

  log_info "xray-fusion installed successfully"
}

# Cleanup partial installation
cleanup_partial_installation() {
  log_warn "Cleaning up partial installation"

  if [[ -L "${SYMLINK_PATH}" ]]; then
    local target
    target="$(readlink -f "${SYMLINK_PATH}" 2> /dev/null || true)"
    if [[ "${target}" == "${INSTALL_DIR}/bin/xrf" ]]; then
      rm -f "${SYMLINK_PATH}"
      log_debug "Removed symlink: ${SYMLINK_PATH}"
    fi
  fi

  if [[ -n "${INSTALL_MARKER}" && -f "${INSTALL_MARKER}" ]]; then
    rm -f "${INSTALL_MARKER}"
    if [[ "${INSTALL_DIR_PREEXISTING}" != "true" ]]; then
      rm -rf "${INSTALL_DIR}"
      log_debug "Removed installation directory: ${INSTALL_DIR}"
    else
      log_warn "Preserving existing installation directory: ${INSTALL_DIR}"
    fi
  fi
}

# Run xray installation
run_xray_install() {
  log_info "Installing Xray with topology: ${TOPOLOGY}"

  local install_args=("--topology" "${TOPOLOGY}")

  if [[ -n "${DOMAIN}" ]]; then
    install_args+=("--domain" "${DOMAIN}")
  fi

  if [[ "${VERSION}" != "latest" ]]; then
    install_args+=("--version" "${VERSION}")
  fi

  if [[ -n "${PLUGINS}" ]]; then
    install_args+=("--plugins" "${PLUGINS}")
  fi

  if [[ "${DEBUG}" == "true" ]]; then
    install_args+=("--debug")
  fi

  # Change to installation directory
  cd "${INSTALL_DIR}"

  # Run installation with unified arguments
  if "./bin/xrf" install "${install_args[@]}"; then
    log_info "Xray installation completed successfully"
    [[ -n "${INSTALL_MARKER}" && -f "${INSTALL_MARKER}" ]] && rm -f "${INSTALL_MARKER}"
    INSTALL_MARKER=""

    # Post-installation validation
    validate_installation
  else
    cleanup_partial_installation
    error_exit "Xray installation failed"
  fi
}

# Validate installation
validate_installation() {
  log_debug "Validating installation..."

  # Check if xrf command works
  if ! "./bin/xrf" status > /dev/null 2>&1; then
    log_warn "xrf command validation failed"
    return 1
  fi

  # Check if global symlink works
  if [[ -L "${SYMLINK_PATH}" ]] && command -v xrf > /dev/null 2>&1; then
    log_debug "Global xrf command accessible"
  else
    log_warn "Global xrf command not accessible"
  fi

  # Check if service is running (if systemctl available)
  if command -v systemctl > /dev/null 2>&1; then
    if systemctl is-active --quiet xray 2> /dev/null; then
      log_debug "Xray service is running"
    else
      log_warn "Xray service is not running"
    fi
  fi

  log_debug "Installation validation completed"
}

# Show installation summary
show_summary() {
  log_info "Installation Summary:"
  echo "  Topology: ${TOPOLOGY}"
  echo "  Version: ${VERSION}"
  echo "  Install Directory: ${INSTALL_DIR}"
  [[ -n "${DOMAIN}" ]] && echo "  Domain: ${DOMAIN}"
  [[ -n "${PLUGINS}" ]] && echo "  Enabled Plugins: ${PLUGINS}"
  [[ -n "${XRAY_SNI:-}" ]] && echo "  Custom SNI: ${XRAY_SNI}"
  [[ -n "${XRAY_PORT:-}" ]] && echo "  Custom Port: ${XRAY_PORT}"
  echo ""
  log_info "Next steps:"
  echo "  1. Check status: xrf status"
  echo "  2. View client links: xrf links"
  echo "  3. Manage plugins: xrf plugin list"
  echo ""
  log_info "For more information, run: xrf help"
}

# Main function
main() {
  echo -e "${GREEN}"
  cat << 'EOF'
 ██╗  ██╗██████╗  █████╗ ██╗   ██╗      ███████╗██╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗
 ╚██╗██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝      ██╔════╝██║   ██║██╔════╝██║██╔═══██╗████╗  ██║
  ╚███╔╝ ██████╔╝███████║ ╚████╔╝       █████╗  ██║   ██║███████╗██║██║   ██║██╔██╗ ██║
  ██╔██╗ ██╔══██╗██╔══██║  ╚██╔╝        ██╔══╝  ██║   ██║╚════██║██║██║   ██║██║╚██╗██║
 ██╔╝ ██╗██║  ██║██║  ██║   ██║         ██║     ╚██████╔╝███████║██║╚██████╔╝██║ ╚████║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝         ╚═╝      ╚═════╝ ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
  echo -e "${NC}"
  echo "                    Xray Fusion - One-Click Installer"
  echo ""

  # Download and setup args module first
  TMP_DIR="$(mktemp -d)"
  source_args_module

  parse_args "${@}"

  # Run early checks first
  early_checks

  # Setup environment from parsed arguments
  setup_environment

  # Continue with installation steps
  check_system
  install_dependencies
  download_project
  install_xray_fusion
  run_xray_install
  show_summary

  log_info "安装完成！"
}

# Run main function with all arguments
main "${@}"
