#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/args.sh"
. "${HERE}/lib/plugins.sh"
. "${HERE}/modules/state.sh"
. "${HERE}/services/xray/common.sh"

usage() {
  cat << EOF
Usage: xrf install [options]

EOF
  args::show_help

  cat << EOF

Xray Configuration Variables:
  XRAY_SNIFFING=false|true
  # reality-only
  XRAY_PORT=443 XRAY_UUID=<uuid> XRAY_SNI=www.microsoft.com[,alt] XRAY_REALITY_DEST=www.microsoft.com XRAY_PRIVATE_KEY=<X25519> XRAY_SHORT_ID=<hex>
  # vision-reality
  XRAY_VISION_PORT=8443 XRAY_REALITY_PORT=443 XRAY_FALLBACK_PORT=8080 XRAY_UUID_VISION=<uuid> XRAY_UUID_REALITY=<uuid> XRAY_CERT_DIR=/usr/local/etc/xray/certs XRAY_PRIVATE_KEY=<X25519> XRAY_SHORT_ID=<hex>
EOF
}

main() {
  core::init "${@}"
  plugins::ensure_dirs
  plugins::load_enabled

  # Initialize and parse arguments
  args::init
  local rc=0
  args::parse "$@" || rc=$?

  if [[ ${rc} -eq 10 ]]; then
    usage
    exit 0
  elif [[ ${rc} -ne 0 ]]; then
    usage
    exit 1
  fi

  # Export arguments as environment variables
  args::export_vars

  # Enable plugins if specified
  if [[ -n "${PLUGINS}" ]]; then
    core::log info "enabling plugins" "$(printf '{"plugins":"%s"}' "${PLUGINS}")"
    IFS=',' read -ra plugin_list <<< "${PLUGINS}"
    for plugin in "${plugin_list[@]}"; do
      plugin="$(echo "${plugin}" | xargs)" # trim whitespace
      if [[ -n "${plugin}" ]]; then
        "${HERE}/commands/plugin.sh" enable "${plugin}"
      fi
    done
    # Reload enabled plugins after enabling new ones
    plugins::load_enabled
  fi

  plugins::emit install_pre "topology=${TOPOLOGY}" "version=${VERSION}"
  "${HERE}/services/xray/install.sh" --version "${VERSION}"

  if [[ "${TOPOLOGY}" == "vision-reality" ]]; then
    core::log debug "configuring vision-reality topology" "$(printf '{"XRAY_DOMAIN":"%s"}' "${XRAY_DOMAIN:-unset}")"
    : "${XRAY_VISION_PORT:=8443}" : "${XRAY_REALITY_PORT:=443}" : "${XRAY_CERT_DIR:=/usr/local/etc/xray/certs}" : "${XRAY_FALLBACK_PORT:=8080}"
    if [[ -z "${XRAY_UUID_VISION:-}" ]]; then XRAY_UUID_VISION="$("$(xray::bin)" uuid 2> /dev/null || uuidgen)"; fi
    if [[ -z "${XRAY_UUID_REALITY:-}" ]]; then XRAY_UUID_REALITY="$("$(xray::bin)" uuid 2> /dev/null || uuidgen)"; fi
  else
    : "${XRAY_PORT:=443}"
    if [[ -z "${XRAY_UUID:-}" ]]; then XRAY_UUID="$("$(xray::bin)" uuid 2> /dev/null || uuidgen)"; fi
  fi
  : "${XRAY_SNI:=www.microsoft.com}"
  if [[ -z "${XRAY_REALITY_DEST:-}" ]]; then
    XRAY_REALITY_DEST="${XRAY_SNI%%,*}"
  fi
  if [[ "${XRAY_REALITY_DEST}" != *:* ]]; then
    XRAY_REALITY_DEST="${XRAY_REALITY_DEST}:443"
  fi
  # Generate shortIds pool (3-5 shortIds for multi-client scenarios)
  # Uses reliable hex conversion: xxd (simple) → od (POSIX) → openssl (fallback)

  # Primary shortId (backward compatible)
  if [[ -z "${XRAY_SHORT_ID:-}" ]]; then
    if command -v xxd > /dev/null 2>&1; then
      XRAY_SHORT_ID="$(head -c 8 /dev/urandom | xxd -p -c 16)"
    elif command -v od > /dev/null 2>&1; then
      XRAY_SHORT_ID="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
    else
      XRAY_SHORT_ID="$(openssl rand -hex 8)"
    fi
  fi

  # Additional shortIds for future client differentiation (optional)
  if [[ -z "${XRAY_SHORT_ID_2:-}" ]]; then
    if command -v xxd > /dev/null 2>&1; then
      XRAY_SHORT_ID_2="$(head -c 8 /dev/urandom | xxd -p -c 16)"
    elif command -v od > /dev/null 2>&1; then
      XRAY_SHORT_ID_2="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
    else
      XRAY_SHORT_ID_2="$(openssl rand -hex 8)"
    fi
  fi

  if [[ -z "${XRAY_SHORT_ID_3:-}" ]]; then
    if command -v xxd > /dev/null 2>&1; then
      XRAY_SHORT_ID_3="$(head -c 8 /dev/urandom | xxd -p -c 16)"
    elif command -v od > /dev/null 2>&1; then
      XRAY_SHORT_ID_3="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
    else
      XRAY_SHORT_ID_3="$(openssl rand -hex 8)"
    fi
  fi

  # Validate all generated shortIds (hex format, even length, max 16 chars)
  # Use shared validator from lib/validators.sh
  for sid_var in XRAY_SHORT_ID XRAY_SHORT_ID_2 XRAY_SHORT_ID_3; do
    if [[ -n "${!sid_var:-}" ]] && ! validators::shortid "${!sid_var}"; then
      core::log error "invalid shortId format" "$(printf '{"var":"%s","value":"%s","requirements":"hex,even_length,max_16"}' "${sid_var}" "${!sid_var}")"
      exit 1
    fi
  done

  # Generate private/public key pair if not provided
  if [[ -z "${XRAY_PRIVATE_KEY:-}" && -x "$(xray::bin)" ]]; then
    local kp
    kp="$("$(xray::bin)" x25519 2> /dev/null || true)"
    XRAY_PRIVATE_KEY="$(echo "${kp}" | awk '/PrivateKey:/ {print $2}')"
    XRAY_PUBLIC_KEY="$(echo "${kp}" | awk '/Password:/ {print $2}')"
    unset kp
  fi

  export XRAY_SNIFFING="${XRAY_SNIFFING:-false}"
  export XRAY_UUID XRAY_UUID_VISION XRAY_UUID_REALITY XRAY_SHORT_ID XRAY_SHORT_ID_2 XRAY_SHORT_ID_3 XRAY_SNI XRAY_REALITY_DEST \
    XRAY_PORT XRAY_VISION_PORT XRAY_REALITY_PORT XRAY_DOMAIN XRAY_CERT_DIR XRAY_FALLBACK_PORT \
    XRAY_PRIVATE_KEY XRAY_PUBLIC_KEY

  plugins::emit install_post "topology=${TOPOLOGY}" "version=${VERSION}"
  "${HERE}/services/xray/configure.sh" --topology "${TOPOLOGY}"

  # Install and start systemd service
  "${HERE}/services/xray/systemd-unit.sh" install

  local ver="unknown"
  [[ -x "$(xray::bin)" ]] && ver="$("$(xray::bin)" -version 2> /dev/null | awk 'NR==1{print $2}')"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local st
  if [[ "${TOPOLOGY}" == "vision-reality" ]]; then
    st=$(jq -n --arg name "vision-reality" --arg ver "${ver}" --arg ts "${now}" \
      --arg vport "${XRAY_VISION_PORT}" --arg rport "${XRAY_REALITY_PORT}" \
      --arg vuuid "${XRAY_UUID_VISION}" --arg ruuid "${XRAY_UUID_REALITY}" \
      --arg domain "${XRAY_DOMAIN}" --arg sni "${XRAY_SNI}" --arg sid "${XRAY_SHORT_ID:-}" --arg pbk "${XRAY_PUBLIC_KEY:-}" \
      '{name:$name,version:$ver,installed_at:$ts,xray:{vision_port:($vport|tonumber),reality_port:($rport|tonumber),uuid_vision:$vuuid,uuid_reality:$ruuid,domain:$domain,reality_sni:$sni,short_id:$sid,reality_public_key:$pbk}}')
  else
    st=$(jq -n --arg name "reality-only" --arg ver "${ver}" --arg ts "${now}" \
      --arg port "${XRAY_PORT}" --arg uuid "${XRAY_UUID}" --arg sni "${XRAY_SNI}" --arg sid "${XRAY_SHORT_ID:-}" --arg pbk "${XRAY_PUBLIC_KEY:-}" \
      '{name:$name,version:$ver,installed_at:$ts,xray:{port:($port|tonumber),uuid:$uuid,reality_sni:$sni,short_id:$sid,reality_public_key:$pbk}}')
  fi
  state::save "${st}"

  "${HERE}/services/xray/client-links.sh" "${TOPOLOGY}"
  core::log info "Install complete" "$(printf '{"topology":"%s","version":"%s"}' "${TOPOLOGY}" "${ver}")"
}
main "${@}"
