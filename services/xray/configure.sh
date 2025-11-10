#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/validators.sh"
. "${HERE}/lib/plugins.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/state.sh"
. "${HERE}/services/xray/common.sh"

core::log debug "configure.sh started" "$(printf '{"args":"%s"}' "$*")"

# Helper: Convert CSV to JSON array
json_array_from_csv() {
  local IFS=','
  read -ra a <<< "${1}"
  local o="["
  for n in "${a[@]}"; do
    n="$(echo "${n}" | xargs)"
    [[ -n "${n}" ]] && o="${o}\"${n}\","
  done
  printf '%s' "${o%,}]"
}

# Helper: Ensure reality destination format (hostname:port)
ensure_reality_dest() {
  local dest="${1}" sni="${2}"
  if [[ -z "${dest}" ]]; then dest="${sni%%,*}"; fi
  dest="$(echo "${dest}" | xargs)"
  if [[ "${dest}" != *:* ]]; then dest="${dest}:443"; fi
  printf '%s' "${dest}"
}

# Helper: Build shortIds pool array
build_shortids_pool() {
  local primary="${1}" secondary="${2:-}" tertiary="${3:-}"
  local pool="[\"\",\"${primary}\""
  [[ -n "${secondary}" ]] && pool="${pool},\"${secondary}\""
  [[ -n "${tertiary}" ]] && pool="${pool},\"${tertiary}\""
  pool="${pool}]"
  printf '%s' "${pool}"
}

# Helper: Calculate config directory digest
digest_confdir() {
  local d="${1}"
  if command -v jq > /dev/null 2>&1; then
    (for f in "${d}"/*.json; do jq -S -c . "${f}"; done) | sha256sum | awk '{print $1}'
  else
    cat "${d}"/*.json | sha256sum | awk '{print $1}'
  fi
}

# Prepare release directory with timestamp
xray::prepare_release_dir() {
  local rel ts d
  rel="$(xray::releases)"
  io::ensure_dir "${rel}" 0755
  ts="$(date -u +%Y%m%d%H%M%S)"
  d="${rel}/${ts}"
  io::ensure_dir "${d}" 0750
  printf '%s' "${d}"
}

# Write base configuration files (log, outbounds, routing)
xray::write_base_configs() {
  local release_dir="${1}"
  local log_level="${XRAY_LOG_LEVEL:-warning}"

  # Logging configuration
  printf '{"log":{"access":"none","error":"none","loglevel":"%s"}}' "${log_level}" |
    io::atomic_write "${release_dir}/00_log.json" 0640

  # Outbounds configuration
  printf '{"outbounds":[{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]}' |
    io::atomic_write "${release_dir}/06_outbounds.json" 0640

  # Routing configuration
  printf '{"routing":{"domainStrategy":"IPIfNonMatch","rules":[]}}' |
    io::atomic_write "${release_dir}/09_routing.json" 0640

  core::log debug "base configs written" "$(printf '{"dir":"%s"}' "${release_dir}")"
}

# Render Reality-only inbound configuration
xray::render_reality_inbound() {
  local release_dir="${1}"
  local sniff_bool="${2}"

  # Validate required variables
  : "${XRAY_PORT:=443}" : "${XRAY_UUID:?}" : "${XRAY_SNI:=www.microsoft.com}"
  : "${XRAY_SHORT_ID:?}" : "${XRAY_PRIVATE_KEY:?}"

  [[ -n "${XRAY_PRIVATE_KEY}" ]] || {
    core::log error "XRAY_PRIVATE_KEY required"
    exit 2
  }

  # Prepare configuration values
  local reality_dest server_names shortids_pool
  reality_dest="$(ensure_reality_dest "${XRAY_REALITY_DEST:-}" "${XRAY_SNI}")"
  server_names="$(json_array_from_csv "${XRAY_SNI}")"
  shortids_pool="$(build_shortids_pool "${XRAY_SHORT_ID}" "${XRAY_SHORT_ID_2:-}" "${XRAY_SHORT_ID_3:-}")"

  # Write inbound configuration
  cat > "${release_dir}/05_inbounds.json" << JSON
{"inbounds":[{"tag":"reality","listen":"0.0.0.0","port":${XRAY_PORT},"protocol":"vless",
"settings":{"clients":[{"id":"${XRAY_UUID}","flow":"xtls-rprx-vision"}],"decryption":"none"},
"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${reality_dest}","xver":0,"serverNames":${server_names},"privateKey":"${XRAY_PRIVATE_KEY}","shortIds":${shortids_pool},"spiderX":"/"}},
"sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls","quic"]}}]}
JSON

  core::log debug "reality-only inbound config written" "$(printf '{"port":%d}' "${XRAY_PORT}")"
}

# Render Vision + Reality dual inbound configuration
xray::render_vision_reality_inbounds() {
  local release_dir="${1}"
  local sniff_bool="${2}"

  # Validate required variables
  : "${XRAY_VISION_PORT:=8443}" : "${XRAY_REALITY_PORT:=443}"
  : "${XRAY_UUID_VISION:?}" : "${XRAY_UUID_REALITY:?}" : "${XRAY_DOMAIN:?}"
  : "${XRAY_CERT_DIR:=/usr/local/etc/xray/certs}" : "${XRAY_FALLBACK_PORT:=8080}"
  : "${XRAY_SNI:=www.microsoft.com}" : "${XRAY_SHORT_ID:?}" : "${XRAY_PRIVATE_KEY:?}"

  core::log debug "vision-reality variables set" "$(printf '{"vision_port":"%s","reality_port":"%s","domain":"%s"}' \
    "${XRAY_VISION_PORT}" "${XRAY_REALITY_PORT}" "${XRAY_DOMAIN}")"

  # Check for required TLS certificates
  if [[ ! -f "${XRAY_CERT_DIR}/fullchain.pem" || ! -f "${XRAY_CERT_DIR}/privkey.pem" ]]; then
    core::log error "vision-reality requires TLS certificates" "$(printf '{"cert_dir":"%s","suggestion":"Use: --plugins cert-auto"}' \
      "${XRAY_CERT_DIR}")"
    exit 2
  fi

  [[ -n "${XRAY_PRIVATE_KEY}" ]] || {
    core::log error "XRAY_PRIVATE_KEY required"
    exit 2
  }

  # Prepare configuration values
  local reality_dest server_names shortids_pool
  reality_dest="$(ensure_reality_dest "${XRAY_REALITY_DEST:-}" "${XRAY_SNI}")"
  server_names="$(json_array_from_csv "${XRAY_SNI}")"
  shortids_pool="$(build_shortids_pool "${XRAY_SHORT_ID}" "${XRAY_SHORT_ID_2:-}" "${XRAY_SHORT_ID_3:-}")"

  # Write dual inbound configuration
  cat > "${release_dir}/05_inbounds.json" << JSON
{"inbounds":[
{"tag":"vision","listen":"0.0.0.0","port":${XRAY_VISION_PORT},"protocol":"vless",
 "settings":{"clients":[{"id":"${XRAY_UUID_VISION}","flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"alpn":"h2","dest":${XRAY_FALLBACK_PORT}},{"dest":${XRAY_FALLBACK_PORT}}]},
 "streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"minVersion":"1.3","rejectUnknownSni":true,"alpn":["h2","http/1.1"],"certificates":[{"certificateFile":"${XRAY_CERT_DIR}/fullchain.pem","keyFile":"${XRAY_CERT_DIR}/privkey.pem"}]}},
 "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls"]}},
{"tag":"reality","listen":"0.0.0.0","port":${XRAY_REALITY_PORT},"protocol":"vless",
 "settings":{"clients":[{"id":"${XRAY_UUID_REALITY}","flow":"xtls-rprx-vision"}],"decryption":"none"},
 "streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${reality_dest}","xver":0,"serverNames":${server_names},"privateKey":"${XRAY_PRIVATE_KEY}","shortIds":${shortids_pool},"spiderX":"/"}},
 "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls","quic"]}}]}
JSON

  core::log debug "vision-reality inbounds config written" "$(printf '{"vision_port":%d,"reality_port":%d}' \
    "${XRAY_VISION_PORT}" "${XRAY_REALITY_PORT}")"
}

# Set permissions for configuration directory and files
xray::set_config_permissions() {
  local release_dir="${1}"

  core::log debug "setting permissions" "$(printf '{"dir":"%s"}' "${release_dir}")"

  chmod 0750 "${release_dir}" || true
  chown root:xray "${release_dir}" 2> /dev/null || true

  for f in "${release_dir}"/*.json; do
    [[ -f "${f}" ]] || continue
    chown root:xray "${f}" 2> /dev/null || true
    chmod 0640 "${f}" || true
    core::log debug "config file permissions set" "$(printf '{"file":"%s"}' "${f}")"
  done
}

# Main function: Orchestrate Xray configuration rendering
render_release() {
  local topology="${1}"

  # Step 1: Prepare release directory
  local d
  d="$(xray::prepare_release_dir)"
  core::log debug "release directory created" "$(printf '{"dir":"%s"}' "${d}")"

  # Step 2: Initialize plugin system and emit pre-configure hooks
  : "${XRAY_LOG_LEVEL:=warning}"
  : "${XRAY_SNIFFING:=false}"
  plugins::ensure_dirs
  plugins::load_enabled
  plugins::emit configure_pre "topology=${topology}" "release_dir=${d}"

  # Step 3: Write base configuration files
  xray::write_base_configs "${d}"

  # Step 4: Determine sniffing mode
  local sniff_bool
  sniff_bool=$([[ "${XRAY_SNIFFING}" == "true" ]] && echo true || echo false)

  # Step 5: Render topology-specific inbound configuration
  case "${topology}" in
    reality-only)
      xray::render_reality_inbound "${d}" "${sniff_bool}"
      ;;
    vision-reality)
      xray::render_vision_reality_inbounds "${d}" "${sniff_bool}"
      ;;
    *)
      core::log error "unknown topology" "$(printf '{"topology":"%s"}' "${topology}")"
      exit 3
      ;;
  esac

  # Step 6: Set permissions on config directory and files
  xray::set_config_permissions "${d}"

  # Step 7: Emit post-configure hooks
  core::log debug "emitting configure_post" "$(printf '{"topology":"%s","release_dir":"%s"}' "${topology}" "${d}")"
  plugins::emit configure_post "topology=${topology}" "release_dir=${d}"

  # Step 8: Return release directory path to stdout
  core::log debug "render_release complete" "$(printf '{"release_dir":"%s"}' "${d}")"
  printf '%s\n' "${d}"
}

deploy_release() {
  local d="${1}"
  core::log debug "deploy_release started" "$(printf '{"release_dir":"%s"}' "${d}")"

  # Security: Validate directory path to prevent injection attacks
  if [[ ! "${d}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
    core::log error "invalid directory path" "$(printf '{"path":"%s"}' "${d}")"
    return 1
  fi

  if [[ ! -d "${d}" ]]; then
    core::log error "directory does not exist" "$(printf '{"path":"%s"}' "${d}")"
    return 1
  fi

  if [[ -x "$(xray::bin)" ]]; then
    local xray_bin test_output
    xray_bin="$(xray::bin)"

    if ! test_output="$("${xray_bin}" -test -confdir "${d}" -format json 2>&1)"; then
      core::log error "xray config test failed" "$(printf '{"confdir":"%s","test_output":"%s"}' "${d//\"/\\\"}" "${test_output}")"
      printf '%s\n' "${test_output}" >&2
      return 1
    fi
    core::log debug "xray config test passed" "$(printf '{"confdir":"%s"}' "${d}")"
  fi
  local newdg
  newdg="$(digest_confdir "${d}")"
  local olddg=""
  [[ -f "$(state::digest)" ]] && olddg="$(cat "$(state::digest)")"
  if [[ -n "${olddg}" && "${olddg}" == "${newdg}" ]]; then
    core::log info "no changes; skip reload" "$(printf '{"digest":"%s"}' "${newdg}")"
    return 0
  fi
  io::ensure_dir "$(xray::confbase)" 0755
  io::ensure_dir "$(xray::releases)" 0755
  ln -sfn "${d}" "$(xray::active).new"
  mv -Tf "$(xray::active).new" "$(xray::active)"
  echo "${newdg}" | io::atomic_write "$(state::digest)" 0644
  if command -v systemctl > /dev/null 2>&1 && systemctl is-active --quiet xray 2> /dev/null; then systemctl reload-or-restart xray || systemctl restart xray || true; fi
  plugins::emit deploy_post "active_dir=$(xray::active)"
  core::log info "deployed" "$(printf '{"active":"%s"}' "$(xray::active)")"
}

deploy_with_lock() {
  local topology="${1}"
  local d
  d="$(render_release "${topology}")"
  deploy_release "${d}"
}

main() {
  core::init "${@}"
  local topology="reality-only"
  while [[ $# -gt 0 ]]; do case "${1}" in --topology)
    topology="${2}"
    shift 2
    ;;
  *) shift ;; esac done

  # Security: Validate topology parameter
  case "${topology}" in
    "reality-only" | "vision-reality") ;;
    *)
      core::log error "invalid topology" "$(printf '{"topology":"%s","valid_options":"reality-only,vision-reality"}' "${topology}")"
      exit 1
      ;;
  esac
  plugins::ensure_dirs
  plugins::load_enabled
  core::with_flock "$(state::lock)" deploy_with_lock "${topology}"
}
main "${@}"
