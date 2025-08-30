#!/usr/bin/env bash
# Render Xray config from template, validate (optional), and reload service
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/svc/svc.sh"
. "${HERE}/services/xray/common.sh"

render() {
  local tmpl="$1"
  local topology="$2"
  if ! command -v envsubst >/dev/null 2>&1; then
    core::log error "envsubst missing"; return 2
  fi
  io::ensure_dir "$(xray::confdir)" 0755
  
  # Build inbounds configuration
  local inbounds_config
  inbounds_config=$(build_inbounds_config "${topology}")
  export XRAY_INBOUNDS="${inbounds_config}"
  
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Render preview" "$(printf '{"template":"%s","topology":"%s"}' "${tmpl}" "${topology}")"
    envsubst < "${tmpl}" | jq . >/dev/null 2>&1 || { core::log error "JSON invalid after render"; return 3; }
    envsubst < "${tmpl}" | sed -n '1,40p'
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  chmod 600 "${tmp}"
  envsubst < "${tmpl}" > "${tmp}"
  if command -v jq >/dev/null 2>&1; then
    jq . < "${tmp}" >/dev/null || { core::log error "JSON invalid" ; rm -f "${tmp}"; return 3; }
  fi
  # optional: binary test
  if [[ -x "$(xray::bin)" && "${XRF_SKIP_XRAY_TEST:-false}" != "true" ]]; then
    "$(xray::bin)" -test -config "${tmp}" -format json || { core::log error "xray -test failed"; rm -f "${tmp}"; return 4; }
  fi
  io::atomic_write "$(xray::cfg)" 0644 < "${tmp}"
  rm -f "${tmp}"
  core::log info "Config updated" "$(printf '{"path":"%s"}' "$(xray::cfg)")"
  # try reload service if present and active
  if systemctl is-active --quiet xray 2>/dev/null; then
    svc::reload xray || true
  fi
}

build_inbounds_config() {
  local topology="$1"
  local inbounds=""
  
  case "${topology}" in
    "reality-only")
      inbounds=$(envsubst < "${HERE}/templates/xray/inbound-reality.json.tmpl")
      ;;
    "vision-reality")
      local vision_inbound
      local reality_inbound
      vision_inbound=$(envsubst < "${HERE}/templates/xray/inbound-vision.json.tmpl")
      reality_inbound=$(envsubst < "${HERE}/templates/xray/inbound-reality-dual.json.tmpl")
      inbounds="${vision_inbound},\n${reality_inbound}"
      ;;
    *)
      core::log error "Unknown topology: ${topology}"
      return 1
      ;;
  esac
  
  echo -e "${inbounds}"
}

get_template_for_topology() {
  echo "${HERE}/templates/xray/base.json.tmpl"
}

main() {
  core::init "$@"
  local topology="" tmpl=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --topology) topology="$2"; shift 2 ;;
      --template) tmpl="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  # If no template specified, determine from topology
  if [[ -z "${tmpl}" ]]; then
    if [[ -n "${topology}" ]]; then
      tmpl="$(get_template_for_topology "${topology}")"
    else
      core::log error "Either --topology or --template must be specified"
      return 1
    fi
  fi
  
  # Generate Reality private key if not set
  if [[ -z "${XRAY_PRIVATE_KEY:-}" ]]; then
    if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
      # In dry run mode, use placeholder keys for preview
      export XRAY_PRIVATE_KEY="fake_private_key_for_preview"
      export XRAY_PUBLIC_KEY="fake_public_key_for_preview"
      core::log info "Using placeholder Reality keypair for dry run" "$(printf '{"public_key":"%s"}' "${XRAY_PUBLIC_KEY}")"
      
      # Save placeholder public key (skip in dry run to avoid permission errors)
      if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
        local state_dir="${XRF_VAR:-/var/lib/xray-fusion}"
        mkdir -p "${state_dir}"
        echo "${XRAY_PUBLIC_KEY}" > "${state_dir}/reality_pubkey.tmp"
      fi
    elif [[ -x "$(xray::bin)" ]]; then
      local keypair
      keypair="$($(xray::bin) x25519 2>/dev/null)"
      if [[ -n "${keypair}" ]]; then
        XRAY_PRIVATE_KEY="$(echo "${keypair}" | grep "Private key:" | cut -d' ' -f3)"
        export XRAY_PRIVATE_KEY
        XRAY_PUBLIC_KEY="$(echo "${keypair}" | grep "Public key:" | cut -d' ' -f3)"
        export XRAY_PUBLIC_KEY
        core::log info "Generated Reality keypair" "$(printf '{"public_key":"%s"}' "${XRAY_PUBLIC_KEY}")"
        
        # Save public key to state directory for install.sh to access (skip in dry run)
        if [[ "${XRF_DRY_RUN:-false}" != "true" ]]; then
          local state_dir="${XRF_VAR:-/var/lib/xray-fusion}"
          mkdir -p "${state_dir}"
          echo "${XRAY_PUBLIC_KEY}" > "${state_dir}/reality_pubkey.tmp"
        fi
      fi
    fi
  fi
  
  render "${tmpl}" "${topology}"
}
main "$@"
