#!/usr/bin/env bash
# xray-fusion online installer
# Usage: curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_TOPOLOGY="reality-only"
DEFAULT_VERSION="latest"
REPO_URL="${XRF_REPO_URL:-https://github.com/Joe-oss9527/xray-fusion.git}"
BRANCH="${XRF_BRANCH:-main}"
INSTALL_DIR="${XRF_INSTALL_DIR:-/usr/local/xray-fusion}"

# Runtime variables
TOPOLOGY="${DEFAULT_TOPOLOGY}"
XRAY_VERSION_REQ="${DEFAULT_VERSION}"
ENABLE_PLUGINS=""
PROXY=""
DEBUG=""

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

# Show help
show_help() {
  cat << EOF
xray-fusion online installer

Usage:
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- [options]

Options:
  --topology <reality-only|vision-reality>  Installation topology (default: reality-only)
  --version <version>                        Xray version to install (default: latest)
  --enable-plugins <plugin1,plugin2>        Enable plugins after installation
  --proxy <proxy_url>                       Use proxy for downloads
  --install-dir <path>                       Installation directory (default: /usr/local/xray-fusion)
  --debug                                    Enable debug output
  --help                                     Show this help

Examples:
  # Basic installation
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash

  # Advanced installation with plugins
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- \\
    --topology vision-reality --enable-plugins cert-auto,logrotate-obs

Environment Variables:
  XRF_REPO_URL      Repository URL (default: https://github.com/Joe-oss9527/xray-fusion.git)
  XRF_BRANCH        Branch to use (default: main)
  XRF_INSTALL_DIR   Installation directory (default: /usr/local/xray-fusion)
  XRF_LOG_TARGET    Log target (file|journal) for logrotate-obs plugin

  Xray Configuration (Reality-only topology):
  XRAY_SNI          SNI domain (default: www.microsoft.com)
  XRAY_PORT         Listen port (default: 443)
  XRAY_UUID         User UUID (auto-generated if not set)
  XRAY_*            All other Xray configuration variables (see README.md)

EOF
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
    local ID VERSION_ID
    . /etc/os-release
    log_debug "检测到系统: ${ID} ${VERSION_ID:-unknown}"
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

  # Clone repository with better error handling
  log_debug "开始克隆仓库..."
  if ! git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMP_DIR}/xray-fusion" 2> /dev/null; then
    log_error "从 ${REPO_URL} 下载失败"
    log_info "请检查网络连接或尝试使用代理"
    error_exit "下载失败"
  fi

  # Verify download
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

# Enable plugins
enable_plugins() {
  if [[ -n "${ENABLE_PLUGINS}" ]]; then
    log_info "Enabling plugins: ${ENABLE_PLUGINS}"

    # Split plugins by comma
    IFS=',' read -ra PLUGINS <<< "${ENABLE_PLUGINS}"
    for plugin in "${PLUGINS[@]}"; do
      plugin="$(echo "${plugin}" | xargs)" # trim whitespace
      if "${INSTALL_DIR}/bin/xrf" plugin enable "${plugin}"; then
        log_info "Enabled plugin: ${plugin}"
      else
        log_warn "Failed to enable plugin: ${plugin}"
      fi
    done
  fi
}

# Run xray installation
run_xray_install() {
  log_info "Installing Xray with topology: ${TOPOLOGY}"

  local install_args=("--topology" "${TOPOLOGY}")

  if [[ "${XRAY_VERSION_REQ}" != "latest" ]]; then
    install_args+=("--version" "${XRAY_VERSION_REQ}")
  fi

  # Set debug mode if enabled
  if [[ "${DEBUG}" == "true" ]]; then
    install_args+=("--debug")
  fi

  # Change to installation directory
  cd "${INSTALL_DIR}"

  # Run installation
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

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
      --topology)
        TOPOLOGY="${2}"
        if [[ "${TOPOLOGY}" != "reality-only" && "${TOPOLOGY}" != "vision-reality" ]]; then
          error_exit "Invalid topology: ${TOPOLOGY}. Must be 'reality-only' or 'vision-reality'."
        fi
        shift 2
        ;;
      --version)
        XRAY_VERSION_REQ="${2}"
        shift 2
        ;;
      --enable-plugins)
        ENABLE_PLUGINS="${2}"
        shift 2
        ;;
      --proxy)
        PROXY="${2}"
        shift 2
        ;;
      --install-dir)
        INSTALL_DIR="${2}"
        shift 2
        ;;
      --debug)
        DEBUG="true"
        shift
        ;;
      --help | -h)
        show_help
        exit 0
        ;;
      *)
        log_warn "Unknown option: ${1}"
        shift
        ;;
    esac
  done
}

# Handle environment variable compatibility
setup_environment() {
  # Support common port variable aliases
  if [[ -n "${XRAY_PORT:-}" && -z "${XRAY_REALITY_PORT:-}" ]]; then
    export XRAY_REALITY_PORT="${XRAY_PORT}"
    log_debug "使用 XRAY_PORT 设置 XRAY_REALITY_PORT=${XRAY_REALITY_PORT}"
  fi
}

# Show installation summary
show_summary() {
  log_info "Installation Summary:"
  echo "  Topology: ${TOPOLOGY}"
  echo "  Version: ${XRAY_VERSION_REQ}"
  echo "  Install Directory: ${INSTALL_DIR}"
  [[ -n "${ENABLE_PLUGINS}" ]] && echo "  Enabled Plugins: ${ENABLE_PLUGINS}"
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

  parse_args "${@}"

  # Run early checks first
  early_checks

  # Setup environment variable compatibility
  setup_environment

  # Continue with installation steps
  check_system
  install_dependencies
  download_project
  install_xray_fusion
  enable_plugins
  run_xray_install
  show_summary

  log_info "安装完成！"
}

# Run main function with all arguments
main "${@}"
