#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/pkg/pkg.sh"
. "${HERE}/modules/ui/progress.sh"
. "${HERE}/services/xray/topology.sh"

usage() {
cat <<EOF
Usage: xrf install [--version vX.Y.Z|latest] [--topology reality-only] [--dry]
Environment:
  XRF_PREFIX=/usr/local       # install prefix
  XRF_ETC=/usr/local/etc      # config dir base
  XRF_VAR=/var/lib/xray-fusion
  XRF_DRY_RUN=true|false
EOF
}

HERE2="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE2}/modules/state.sh"
main() {
  core::init "$@"
  local version="latest" topology="reality-only"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) version="$2"; shift 2 ;;
      --topology) topology="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) shift ;;
    esac
  done

  # Initialize progress tracking (8 major steps)
  ui::progress_init 8
  
  # Step 1: Ensure runtime dependencies
  ui::progress_step "Installing Dependencies" "Setting up required packages"
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan deps" '{"apt":["curl","unzip","jq","gettext-base"],"dnf":["curl","unzip","jq","gettext"]}'
  else
    if [[ "$(pkg::detect)" == "apt" ]]; then
      pkg::refresh || true
      pkg::ensure curl; pkg::ensure unzip; pkg::ensure jq; pkg::ensure gettext-base
    elif [[ "$(pkg::detect)" == "dnf" ]]; then
      pkg::refresh || true
      pkg::ensure curl; pkg::ensure unzip; pkg::ensure jq; pkg::ensure gettext
    fi
  fi

  # Step 2: Download and install Xray binary
  ui::progress_step "Downloading Xray" "Installing Xray ${version}"
  "${HERE}/services/xray/install.sh" --version "${version}"
  
  # Validate topology
  if ! xray_topology::validate "${topology}"; then
    core::log error "Invalid topology: ${topology}"
    core::log info "Available topologies: $(xray_topology::list_available | tr '\n' ' ')"
    exit 1
  fi
  
  # Step 3: Configure topology settings
  ui::progress_step "Configuring Topology" "Setting up ${topology} parameters"
  if [[ "${topology}" == "vision-reality" ]]; then
    XRAY_PORT="${XRAY_PORT:-443}"
    XRAY_DOMAIN="${XRAY_DOMAIN:-example.com}"
  else
    XRAY_PORT="${XRAY_PORT:-8443}"
  fi
  
  # Step 4: Generate secure credentials
  ui::progress_step "Generating Credentials" "Creating secure random credentials"
  if [[ -z "${XRAY_UUID:-}" ]]; then
    if command -v "${XRF_PREFIX:-/usr/local}/bin/xray" >/dev/null 2>&1; then
      XRAY_UUID=$("${XRF_PREFIX:-/usr/local}/bin/xray" uuid)
      core::log info "Generated random UUID" '{"generated":true}'
    elif command -v uuidgen >/dev/null 2>&1; then
      XRAY_UUID=$(uuidgen)
      core::log info "Generated random UUID with uuidgen" '{"generated":true}'
    else
      core::log error "Cannot generate UUID: neither xray nor uuidgen available"
      ui::progress_fail "Cannot generate UUID: neither xray nor uuidgen available" "Generating Credentials"
      return 1
    fi
  fi
  
  if [[ -z "${XRAY_SHORT_ID:-}" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      XRAY_SHORT_ID=$(openssl rand -hex 8)
      core::log info "Generated random short ID" '{"generated":true}'
    else
      # Fallback to /dev/urandom
      XRAY_SHORT_ID=$(head -c 8 /dev/urandom | hexdump -e '16/1 "%02x"')
      core::log info "Generated random short ID with urandom" '{"generated":true}'
    fi
  fi

  # Set any remaining required topology variables
  export XRAY_PORT="${XRAY_PORT}"
  export XRAY_UUID="${XRAY_UUID}"
  export XRAY_SHORT_ID="${XRAY_SHORT_ID}"
  export XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}"
  export XRAY_REALITY_DEST="${XRAY_REALITY_DEST:-www.microsoft.com}"
  if [[ "${topology}" == "vision-reality" ]]; then
    export XRAY_DOMAIN="${XRAY_DOMAIN:-example.com}"
  fi

  # Step 5: Generate configuration files
  ui::progress_step "Creating Configuration" "Generating Xray config with Reality keypairs"
  XRAY_PORT="${XRAY_PORT}" \
  XRAY_UUID="${XRAY_UUID}" \
  XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}" \
  XRAY_REALITY_DEST="${XRAY_REALITY_DEST:-www.microsoft.com}" \
  XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}" \
  XRAY_SHORT_ID="${XRAY_SHORT_ID}" \
  XRAY_DOMAIN="${XRAY_DOMAIN:-}" \
  "${HERE}/services/xray/configure.sh"
  
  # Read Reality public key from temporary file if it exists
  local state_dir="${XRF_VAR:-/var/lib/xray-fusion}"
  if [[ -f "${state_dir}/reality_pubkey.tmp" ]]; then
    local pubkey
    pubkey="$(cat "${state_dir}/reality_pubkey.tmp")"
    export XRAY_PUBLIC_KEY="${pubkey}"
    rm -f "${state_dir}/reality_pubkey.tmp"  # Clean up temporary file
  fi
  
  # Step 6: Prepare topology context
  ui::progress_step "Building Context" "Preparing ${topology} deployment context"
  local ctx
  ctx=$(xray_topology::get_context "${topology}")
  
  # Step 7: Install and configure system service
  ui::progress_step "Installing Service" "Setting up systemd service with dedicated user"
  if command -v systemctl >/dev/null 2>&1; then 
    "${HERE}/services/xray/systemd-unit.sh" install
  elif command -v rc-service >/dev/null 2>&1; then 
    "${HERE}/services/xray/openrc-unit.sh" install
  else
    core::log warn "No supported init system found - service not installed"
  fi
  
  # Save installation state
  local ver="unknown"
  if command -v "${XRF_PREFIX:-/usr/local}/bin/xray" >/dev/null 2>&1; then
    ver=$("${XRF_PREFIX:-/usr/local}/bin/xray" -version 2>/dev/null | awk 'NR==1{print $2}')
  fi
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local state; state=$(jq -n --arg topo "${topology}" --arg ver "${ver}" --argjson ctx "${ctx}" --arg ts "${now}" '{topology:$topo, version:$ver, installed_at:$ts} + $ctx')
  state::save "${state}"
  
  # Step 8: Generate client connection information
  ui::progress_step "Finalizing" "Generating client connection links and QR codes"
  "${HERE}/services/xray/client-links.sh" "${topology}"
  
  # Show completion and summary
  ui::progress_complete "${topology}" "${ver}"
  ui::show_summary "${topology}" "${ver}"
}

main "$@"
