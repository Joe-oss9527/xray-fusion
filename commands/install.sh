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
    XRAY_VISION_PORT="${XRAY_VISION_PORT:-443}"
    XRAY_REALITY_PORT="${XRAY_REALITY_PORT:-8443}"
    XRAY_DOMAIN="${XRAY_DOMAIN:-example.com}"
    XRAY_CERT_DIR="${XRAY_CERT_DIR:-/usr/local/etc/xray/certs}"
    XRAY_FALLBACK_PORT="${XRAY_FALLBACK_PORT:-8080}"
  else
    XRAY_PORT="${XRAY_PORT:-443}"
  fi
  
  # Step 4: Generate secure credentials
  ui::progress_step "Generating Credentials" "Creating secure random credentials"
  
  # Generate UUID(s) based on topology
  if [[ "${topology}" == "vision-reality" ]]; then
    # Generate separate UUIDs for Vision and Reality
    if [[ -z "${XRAY_UUID_VISION:-}" ]]; then
      if command -v "${XRF_PREFIX:-/usr/local}/bin/xray" >/dev/null 2>&1; then
        XRAY_UUID_VISION=$("${XRF_PREFIX:-/usr/local}/bin/xray" uuid)
        core::log info "Generated random Vision UUID" '{"generated":true}'
      elif command -v uuidgen >/dev/null 2>&1; then
        XRAY_UUID_VISION=$(uuidgen)
        core::log info "Generated random Vision UUID with uuidgen" '{"generated":true}'
      else
        core::log error "Cannot generate Vision UUID: neither xray nor uuidgen available"
        ui::progress_fail "Cannot generate Vision UUID: neither xray nor uuidgen available" "Generating Credentials"
        return 1
      fi
    fi
    
    if [[ -z "${XRAY_UUID_REALITY:-}" ]]; then
      if command -v "${XRF_PREFIX:-/usr/local}/bin/xray" >/dev/null 2>&1; then
        XRAY_UUID_REALITY=$("${XRF_PREFIX:-/usr/local}/bin/xray" uuid)
        core::log info "Generated random Reality UUID" '{"generated":true}'
      elif command -v uuidgen >/dev/null 2>&1; then
        XRAY_UUID_REALITY=$(uuidgen)
        core::log info "Generated random Reality UUID with uuidgen" '{"generated":true}'
      else
        core::log error "Cannot generate Reality UUID: neither xray nor uuidgen available"
        ui::progress_fail "Cannot generate Reality UUID: neither xray nor uuidgen available" "Generating Credentials"
        return 1
      fi
    fi
  else
    # Generate single UUID for reality-only topology
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
  export XRAY_SHORT_ID="${XRAY_SHORT_ID}"
  export XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}"
  export XRAY_REALITY_DEST="${XRAY_REALITY_DEST:-www.microsoft.com}"
  
  if [[ "${topology}" == "vision-reality" ]]; then
    export XRAY_VISION_PORT="${XRAY_VISION_PORT}"
    export XRAY_REALITY_PORT="${XRAY_REALITY_PORT}"
    export XRAY_UUID_VISION="${XRAY_UUID_VISION}"
    export XRAY_UUID_REALITY="${XRAY_UUID_REALITY}"
    export XRAY_DOMAIN="${XRAY_DOMAIN:-example.com}"
    export XRAY_CERT_DIR="${XRAY_CERT_DIR}"
    export XRAY_FALLBACK_PORT="${XRAY_FALLBACK_PORT}"
  else
    export XRAY_PORT="${XRAY_PORT}"
    export XRAY_UUID="${XRAY_UUID}"
  fi

  # Step 4.5: Prepare certificates for vision-reality topology  
  if [[ "${topology}" == "vision-reality" ]]; then
    ui::progress_step "Preparing Certificates" "Setting up TLS certificate for ${XRAY_DOMAIN}"
    
    # Load required modules
    # shellcheck source=modules/cert/cert.sh
    . "${HERE}/modules/cert/cert.sh"
    # shellcheck source=modules/io.sh  
    . "${HERE}/modules/io.sh"
    
    # Ensure cert directory exists
    io::ensure_dir "${XRAY_CERT_DIR}" 0755
    
    # Check if certificates already exist
    local cert_status cert_exists
    cert_status="$(cert::exists "${XRAY_CERT_DIR}" 2>/dev/null || echo '{"exists":false}')"
    cert_exists="$(echo "${cert_status}" | jq -r '.exists // false')"
    
    if [[ "${cert_exists}" == "true" ]]; then
      core::log info "Certificate found" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${XRAY_DOMAIN}" "${XRAY_CERT_DIR}")"
    elif [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      core::log info "Certificate acquisition would be automatic" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${XRAY_DOMAIN}" "${XRAY_CERT_DIR}")"
      # Create placeholder files for dry-run config validation
      touch "${XRAY_CERT_DIR}/fullchain.pem" "${XRAY_CERT_DIR}/privkey.pem" 2>/dev/null || true
    else
      # Automatic certificate acquisition using acme.sh
      core::log info "Acquiring certificate automatically" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${XRAY_DOMAIN}" "${XRAY_CERT_DIR}")"
      # Use domain-based email for certificate registration
      local email="${XRAY_EMAIL:-admin@${XRAY_DOMAIN}}"
      
      if cert::issue "${XRAY_DOMAIN}" "${email}" "${XRAY_CERT_DIR}"; then
        core::log info "Certificate acquired successfully" "$(printf '{"domain":"%s","cert_dir":"%s"}' "${XRAY_DOMAIN}" "${XRAY_CERT_DIR}")"
      else
        core::log error "Certificate acquisition failed" "$(printf '{"domain":"%s","error":"acme.sh failed"}' "${XRAY_DOMAIN}")"
        ui::progress_fail "Failed to acquire TLS certificate for ${XRAY_DOMAIN}. Ensure domain points to this server and port 80 is available." "Preparing Certificates"
        return 1
      fi
    fi
  fi

  # Step 5: Generate configuration files
  ui::progress_step "Creating Configuration" "Generating Xray config with Reality keypairs"
  
  if [[ "${topology}" == "vision-reality" ]]; then
    # Use vision-reality specific template
    XRAY_VISION_PORT="${XRAY_VISION_PORT}" \
    XRAY_REALITY_PORT="${XRAY_REALITY_PORT}" \
    XRAY_UUID_VISION="${XRAY_UUID_VISION}" \
    XRAY_UUID_REALITY="${XRAY_UUID_REALITY}" \
    XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}" \
    XRAY_REALITY_DEST="${XRAY_REALITY_DEST:-www.microsoft.com}" \
    XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}" \
    XRAY_SHORT_ID="${XRAY_SHORT_ID}" \
    XRAY_DOMAIN="${XRAY_DOMAIN:-}" \
    XRAY_CERT_DIR="${XRAY_CERT_DIR}" \
    XRAY_FALLBACK_PORT="${XRAY_FALLBACK_PORT}" \
    "${HERE}/services/xray/configure.sh" --topology "${topology}"
  else
    # Use default reality-only template
    XRAY_PORT="${XRAY_PORT}" \
    XRAY_UUID="${XRAY_UUID}" \
    XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}" \
    XRAY_REALITY_DEST="${XRAY_REALITY_DEST:-www.microsoft.com}" \
    XRAY_REALITY_SNI="${XRAY_REALITY_SNI:-www.microsoft.com}" \
    XRAY_SHORT_ID="${XRAY_SHORT_ID}" \
    "${HERE}/services/xray/configure.sh" --topology "${topology}"
  fi
  
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
    
    # For vision-reality topology, fix certificate ownership and set reload command
    if [[ "${topology}" == "vision-reality" && "${XRF_DRY_RUN:-false}" != "true" ]]; then
      # shellcheck source=modules/cert/cert.sh
      . "${HERE}/modules/cert/cert.sh"
      
      # Fix certificate ownership for xray user
      cert::fix_ownership "${XRAY_CERT_DIR}" "xray:xray"
      
      # Set certificate reload command for future renewals
      cert::set_reload_command "${XRAY_DOMAIN}" "${XRAY_CERT_DIR}" "systemctl reload xray"
    fi
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
