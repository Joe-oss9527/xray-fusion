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
log_debug() { [[ "${DEBUG}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} ${*}"; }

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
    cat <<EOF
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
    --topology vision-reality --enable-plugins cert-acme,logrotate-obs

Environment Variables:
  XRF_REPO_URL      Repository URL (default: https://github.com/Joe-oss9527/xray-fusion.git)
  XRF_BRANCH        Branch to use (default: main)
  XRF_INSTALL_DIR   Installation directory (default: /usr/local/xray-fusion)
  XRF_LOG_TARGET    Log target (file|journal) for logrotate-obs plugin
  XRAY_*            All Xray configuration variables (see README.md)

EOF
}

# System checks
check_system() {
    log_info "Checking system requirements..."

    # Check if running as root
    if [[ ${EUID} -ne 0 ]]; then
        error_exit "This script must be run as root. Please use sudo."
    fi

    # Check OS support
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot determine OS. /etc/os-release not found."
    fi

    local ID VERSION VERSION_ID
    . /etc/os-release
    case "${ID}" in
        ubuntu|debian|centos|rhel|fedora|rocky|almalinux)
            log_debug "Detected supported OS: ${ID} ${VERSION_ID}"
            ;;
        *)
            log_warn "Untested OS: ${ID} ${VERSION_ID}. Proceeding anyway..."
            ;;
    esac

    # Check architecture
    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64|aarch64|arm64)
            log_debug "Detected supported architecture: ${arch}"
            ;;
        *)
            error_exit "Unsupported architecture: ${arch}. Only x86_64/amd64 and aarch64/arm64 are supported."
            ;;
    esac

    # Check systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        error_exit "systemd is required but not found. Please install systemd."
    fi

    log_info "System requirements check passed"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."

    local deps="curl wget git jq unzip openssl"
    local missing_deps=""
    local pkg_manager=""

    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    else
        error_exit "No supported package manager found (apt/yum/dnf)"
    fi

    # Check for missing dependencies
    for dep in ${deps}; do
        if ! command -v "${dep}" >/dev/null 2>&1; then
            missing_deps="${missing_deps} ${dep}"
        fi
    done

    # Install missing dependencies
    if [[ -n "${missing_deps}" ]]; then
        log_info "Installing missing dependencies:${missing_deps}"
        case "${pkg_manager}" in
            apt)
                apt-get update -qq
                apt-get install -y ${missing_deps}
                ;;
            yum)
                yum install -y epel-release || true
                yum install -y ${missing_deps}
                ;;
            dnf)
                dnf install -y ${missing_deps}
                ;;
        esac
    else
        log_info "All dependencies are already installed"
    fi
}

# Download xray-fusion
download_project() {
    log_info "Downloading xray-fusion from ${REPO_URL} (branch: ${BRANCH})..."

    TMP_DIR="$(mktemp -d)"
    log_debug "Using temporary directory: ${TMP_DIR}"

    # Set proxy if specified
    if [[ -n "${PROXY}" ]]; then
        export https_proxy="${PROXY}"
        export http_proxy="${PROXY}"
        log_info "Using proxy: ${PROXY}"
    fi

    # Clone repository
    if ! git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMP_DIR}/xray-fusion"; then
        error_exit "Failed to download xray-fusion from ${REPO_URL}"
    fi

    log_info "Download completed"
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
    : >"${INSTALL_MARKER}"

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
        target="$(readlink -f "${SYMLINK_PATH}" 2>/dev/null || true)"
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
    if ! "./bin/xrf" status >/dev/null 2>&1; then
        log_warn "xrf command validation failed"
        return 1
    fi

    # Check if global symlink works
    if [[ -L "${SYMLINK_PATH}" ]] && command -v xrf >/dev/null 2>&1; then
        log_debug "Global xrf command accessible"
    else
        log_warn "Global xrf command not accessible"
    fi

    # Check if service is running (if systemctl available)
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet xray 2>/dev/null; then
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
            --help|-h)
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

# Show installation summary
show_summary() {
    log_info "Installation Summary:"
    echo "  Topology: ${TOPOLOGY}"
    echo "  Version: ${XRAY_VERSION_REQ}"
    echo "  Install Directory: ${INSTALL_DIR}"
    [[ -n "${ENABLE_PLUGINS}" ]] && echo "  Enabled Plugins: ${ENABLE_PLUGINS}"
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
    cat <<'EOF'
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
    check_system
    install_dependencies
    download_project
    install_xray_fusion
    enable_plugins
    run_xray_install
    show_summary

    log_info "Installation completed successfully!"
}

# Run main function with all arguments
main "${@}"
