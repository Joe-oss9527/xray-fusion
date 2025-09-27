#!/usr/bin/env bash
# xray-fusion online uninstaller
# Usage: curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REPO_URL="${XRF_REPO_URL:-https://github.com/Joe-oss9527/xray-fusion.git}"
BRANCH="${XRF_BRANCH:-main}"
INSTALL_DIR="${XRF_INSTALL_DIR:-/usr/local/xray-fusion}"

# Runtime variables
KEEP_CONFIG=""
FORCE=""
DEBUG=""
REMOVE_INSTALL_DIR=""

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { [[ "$DEBUG" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# Error handling
error_exit() {
    log_error "$1"
    cleanup
    exit 1
}

cleanup() {
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# Show help
show_help() {
    cat <<EOF
xray-fusion online uninstaller

Usage:
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- [options]

Options:
  --keep-config                 Keep configuration files and state
  --remove-install-dir          Remove the entire installation directory
  --force                       Force uninstallation without confirmation
  --debug                       Enable debug output
  --help                        Show this help

Examples:
  # Complete uninstallation
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash

  # Keep configuration files
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- --keep-config

  # Force uninstallation without confirmation
  curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- --force

Environment Variables:
  XRF_REPO_URL      Repository URL (default: https://github.com/Joe-oss9527/xray-fusion.git)
  XRF_BRANCH        Branch to use (default: main)
  XRF_INSTALL_DIR   Installation directory (default: /usr/local/xray-fusion)

EOF
}

# Check if xray-fusion is installed
check_installation() {
    log_info "Checking xray-fusion installation..."

    # Check if xrf command exists
    if ! command -v xrf >/dev/null 2>&1; then
        # Check if installation directory exists
        if [[ ! -d "$INSTALL_DIR" ]]; then
            log_warn "xray-fusion is not installed or not found in expected locations"
            if [[ "$FORCE" != "true" ]]; then
                if [[ -t 0 ]]; then
                    read -p "Continue anyway? [y/N]: " -r
                else
                    log_warn "Non-interactive mode: defaulting to cancel"
                    REPLY="N"
                fi
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Uninstallation cancelled"
                    exit 0
                fi
            fi
            return 1
        fi
    fi

    log_info "Found xray-fusion installation"
    return 0
}

# Get installation info
get_installation_info() {
    log_info "Gathering installation information..."

    # Try to get status from installed xrf
    if command -v xrf >/dev/null 2>&1; then
        log_debug "Getting status from installed xrf..."
        if xrf status 2>/dev/null; then
            echo ""
        fi
    fi

    # Check systemd service
    if systemctl is-active --quiet xray 2>/dev/null; then
        log_info "Xray service is currently running"
    elif systemctl is-enabled --quiet xray 2>/dev/null; then
        log_info "Xray service is enabled but not running"
    fi

    # Show what will be removed
    echo ""
    log_info "The following will be removed:"
    [[ -L /usr/local/bin/xrf ]] && echo "  - Global xrf command: /usr/local/bin/xrf"
    [[ -d "$INSTALL_DIR" ]] && echo "  - Installation directory: $INSTALL_DIR"

    # Check for Xray binaries and configs
    local xray_locations=(
        "/usr/local/bin/xray"
        "/usr/local/etc/xray"
        "/var/log/xray"
        "/etc/systemd/system/xray.service"
    )

    for location in "${xray_locations[@]}"; do
        if [[ -e "$location" ]]; then
            if [[ "$KEEP_CONFIG" == "true" && ("$location" == *"/etc/xray"* || "$location" == *"config"*) ]]; then
                echo "  - $location (KEPT due to --keep-config)"
            else
                echo "  - $location"
            fi
        fi
    done
    echo ""
}

# Confirm uninstallation
confirm_uninstallation() {
    if [[ "$FORCE" == "true" ]]; then
        log_info "Force mode enabled, skipping confirmation"
        return 0
    fi

    log_warn "This will completely remove xray-fusion and Xray from your system!"
    [[ "$KEEP_CONFIG" == "true" ]] && log_info "Configuration files will be preserved"

    if [[ -t 0 ]]; then
        read -p "Are you sure you want to continue? [y/N]: " -r
    else
        log_warn "Non-interactive mode: defaulting to cancel"
        REPLY="N"
    fi
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
}

# Download uninstall scripts if needed
download_uninstall_scripts() {
    # If we can use the installed version, do so
    if [[ -f "$INSTALL_DIR/bin/xrf" ]]; then
        log_debug "Using installed xrf for uninstallation"
        return 0
    fi

    log_info "Downloading uninstall scripts..."

    TMP_DIR="$(mktemp -d)"
    log_debug "Using temporary directory: $TMP_DIR"

    # Clone repository (only needed files)
    if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/xray-fusion" 2>/dev/null; then
        log_warn "Failed to download from repository, attempting manual uninstallation"
        return 1
    fi

    log_info "Downloaded uninstall scripts"
    return 0
}

# Stop and remove systemd service
remove_systemd_service() {
    log_info "Removing systemd service..."

    # Stop service if running
    if systemctl is-active --quiet xray 2>/dev/null; then
        log_info "Stopping Xray service..."
        systemctl stop xray || log_warn "Failed to stop xray service"
    fi

    # Disable service if enabled
    if systemctl is-enabled --quiet xray 2>/dev/null; then
        log_info "Disabling Xray service..."
        systemctl disable xray || log_warn "Failed to disable xray service"
    fi

    # Remove service file
    if [[ -f /etc/systemd/system/xray.service ]]; then
        rm -f /etc/systemd/system/xray.service
        systemctl daemon-reload
        log_info "Removed systemd service file"
    fi
}

# Run xray-fusion uninstall
run_xrf_uninstall() {
    local xrf_cmd=""

    # Determine which xrf command to use
    if [[ -f "$INSTALL_DIR/bin/xrf" ]]; then
        xrf_cmd="$INSTALL_DIR/bin/xrf"
    elif [[ -f "$TMP_DIR/xray-fusion/bin/xrf" ]]; then
        xrf_cmd="$TMP_DIR/xray-fusion/bin/xrf"
    elif command -v xrf >/dev/null 2>&1; then
        xrf_cmd="xrf"
    else
        log_warn "No xrf command available, performing manual uninstallation"
        return 1
    fi

    log_info "Running xray-fusion uninstall..."

    # Change to appropriate directory
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
    elif [[ -d "$TMP_DIR/xray-fusion" ]]; then
        cd "$TMP_DIR/xray-fusion"
    fi

    # Run uninstall command
    if "$xrf_cmd" uninstall 2>/dev/null; then
        log_info "xray-fusion uninstall completed"
        return 0
    else
        log_warn "xrf uninstall failed, continuing with manual cleanup"
        return 1
    fi
}

# Manual cleanup
manual_cleanup() {
    log_info "Performing manual cleanup..."

    # Remove global xrf symlink
    if [[ -L /usr/local/bin/xrf ]]; then
        rm -f /usr/local/bin/xrf
        log_debug "Removed /usr/local/bin/xrf"
    fi

    # Remove Xray binary
    if [[ -f /usr/local/bin/xray ]]; then
        rm -f /usr/local/bin/xray
        log_debug "Removed /usr/local/bin/xray"
    fi

    # Remove Xray configuration (unless keeping config)
    if [[ "$KEEP_CONFIG" != "true" ]]; then
        if [[ -d /usr/local/etc/xray ]]; then
            rm -rf /usr/local/etc/xray
            log_debug "Removed /usr/local/etc/xray"
        fi
    else
        log_info "Keeping Xray configuration files"
    fi

    # Remove log directory
    if [[ -d /var/log/xray ]]; then
        rm -rf /var/log/xray
        log_debug "Removed /var/log/xray"
    fi

    # Remove logrotate configuration
    if [[ -f /etc/logrotate.d/xray-fusion ]]; then
        rm -f /etc/logrotate.d/xray-fusion
        log_debug "Removed logrotate configuration"
    fi
}

# Remove installation directory
remove_installation_directory() {
    if [[ "$REMOVE_INSTALL_DIR" == "true" && -d "$INSTALL_DIR" ]]; then
        log_info "Removing installation directory: $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    elif [[ -d "$INSTALL_DIR" ]]; then
        log_info "Installation directory preserved: $INSTALL_DIR"
        log_info "To remove it manually: rm -rf $INSTALL_DIR"
    fi
}

# Show uninstallation summary
show_summary() {
    echo ""
    log_info "Uninstallation Summary:"
    echo "  ✓ Systemd service removed"
    echo "  ✓ Xray binary removed"
    [[ "$KEEP_CONFIG" == "true" ]] && echo "  ✓ Configuration files preserved" || echo "  ✓ Configuration files removed"
    echo "  ✓ Log files removed"
    echo "  ✓ Global xrf command removed"
    [[ "$REMOVE_INSTALL_DIR" == "true" ]] && echo "  ✓ Installation directory removed" || echo "  ✓ Installation directory preserved"
    echo ""
    log_info "xray-fusion has been successfully uninstalled!"

    if [[ "$KEEP_CONFIG" == "true" ]]; then
        echo ""
        log_info "Configuration files were preserved. To complete removal:"
        echo "  sudo rm -rf /usr/local/etc/xray"
    fi

    if [[ "$REMOVE_INSTALL_DIR" != "true" && -d "$INSTALL_DIR" ]]; then
        echo ""
        log_info "Installation directory was preserved: $INSTALL_DIR"
        echo "  To remove: sudo rm -rf $INSTALL_DIR"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-config)
                KEEP_CONFIG="true"
                shift
                ;;
            --remove-install-dir)
                REMOVE_INSTALL_DIR="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
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
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# Main function
main() {
    echo -e "${RED}"
    cat <<'EOF'
 ██╗  ██╗██████╗  █████╗ ██╗   ██╗      ███████╗██╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗
 ╚██╗██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝      ██╔════╝██║   ██║██╔════╝██║██╔═══██╗████╗  ██║
  ╚███╔╝ ██████╔╝███████║ ╚████╔╝       █████╗  ██║   ██║███████╗██║██║   ██║██╔██╗ ██║
  ██╔██╗ ██╔══██╗██╔══██║  ╚██╔╝        ██╔══╝  ██║   ██║╚════██║██║██║   ██║██║╚██╗██║
 ██╔╝ ██╗██║  ██║██║  ██║   ██║         ██║     ╚██████╔╝███████║██║╚██████╔╝██║ ╚████║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝         ╚═╝      ╚═════╝ ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
    echo -e "${NC}"
    echo "                    Xray Fusion - Uninstaller"
    echo ""

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Please use sudo."
    fi

    parse_args "$@"
    check_installation
    get_installation_info
    confirm_uninstallation
    download_uninstall_scripts
    remove_systemd_service

    # Try xrf uninstall first, fallback to manual cleanup
    if ! run_xrf_uninstall; then
        manual_cleanup
    fi

    remove_installation_directory
    show_summary

    log_info "Uninstallation completed successfully!"
}

# Run main function with all arguments
main "$@"