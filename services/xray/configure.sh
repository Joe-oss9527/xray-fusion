#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"; . "${HERE}/lib/plugins.sh"; . "${HERE}/modules/io.sh"; . "${HERE}/modules/state.sh"; . "${HERE}/services/xray/common.sh"

validate_shortid(){ [[ "${#1}" -le 16 && $(( ${#1}%2 )) -eq 0 && "${1}" =~ ^[0-9a-fA-F]+$ ]]; }
json_array_from_csv(){ local IFS=','; read -ra a <<<"${1}"; local o="["; for n in "${a[@]}"; do n="$(echo "${n}"|xargs)"; [[ -n "${n}" ]] && o="${o}\"${n}\","; done; printf '%s' "${o%,}]"; }
ensure_reality_dest(){
  local dest="${1}" sni="${2}"
  if [[ -z "${dest}" ]]; then dest="${sni%%,*}"; fi
  dest="$(echo "${dest}" | xargs)"
  if [[ "${dest}" != *:* ]]; then dest="${dest}:443"; fi
  printf '%s' "${dest}"
}
digest_confdir(){ local d="${1}"; if command -v jq >/dev/null 2>&1; then (for f in "${d}"/*.json; do jq -S -c . "${f}"; done) | sha256sum | awk '{print $1}'; else cat "${d}"/*.json | sha256sum | awk '{print $1}'; fi; }

render_release(){
  local topology="${1}" rel="$(xray::releases)"; io::ensure_dir "${rel}" 0755
  local ts; ts="$(date -u +%Y%m%d%H%M%S)"; local d="${rel}/${ts}"; io::ensure_dir "${d}" 0750

  : "${XRAY_LOG_LEVEL:=warning}"; : "${XRAY_SNIFFING:=false}"
  plugins::ensure_dirs; plugins::load_enabled; plugins::emit configure_pre "topology=${topology}" "release_dir=${d}"

  # Logging
  printf '{"log":{"access":"none","error":"none","loglevel":"%s"}}' "${XRAY_LOG_LEVEL}" | io::atomic_write "${d}/00_log.json" 0640
  # Outbounds
  printf '{"outbounds":[{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]}' | io::atomic_write "${d}/06_outbounds.json" 0640

  local sniff_bool; sniff_bool=$([[ "${XRAY_SNIFFING}" == "true" ]] && echo true || echo false)

  case "${topology}" in
    reality-only)
      : "${XRAY_PORT:=443}" : "${XRAY_UUID:?}" : "${XRAY_SNI:=www.microsoft.com}" : "${XRAY_SHORT_ID:?}" : "${XRAY_PRIVATE_KEY:?}" : "${XRAY_PUBLIC_KEY:?}"
      XRAY_REALITY_DEST="$(ensure_reality_dest "${XRAY_REALITY_DEST:-}" "${XRAY_SNI}")"
      [[ -n "${XRAY_PRIVATE_KEY}" ]] || { core::log error "XRAY_PRIVATE_KEY required"; exit 2; }
      local sn; sn="$(json_array_from_csv "${XRAY_SNI}")"
      cat >"${d}/05_inbounds.json" <<JSON
{"inbounds":[{"tag":"reality","listen":"0.0.0.0","port":${XRAY_PORT},"protocol":"vless",
"settings":{"clients":[{"id":"${XRAY_UUID}","flow":"xtls-rprx-vision"}],"decryption":"none"},
"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${XRAY_REALITY_DEST}","xver":0,"serverNames":${sn},"privateKey":"${XRAY_PRIVATE_KEY}","shortIds":["","${XRAY_SHORT_ID}"],"spiderX":"/"}},
"sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls","quic"]}}]}
JSON
      ;;
    vision-reality)
      : "${XRAY_VISION_PORT:=8443}" : "${XRAY_REALITY_PORT:=443}" : "${XRAY_UUID_VISION:?}" : "${XRAY_UUID_REALITY:?}" : "${XRAY_DOMAIN:?}" : "${XRAY_CERT_DIR:=/usr/local/etc/xray/certs}" : "${XRAY_FALLBACK_PORT:=8080}" : "${XRAY_SNI:=www.microsoft.com}" : "${XRAY_SHORT_ID:?}" : "${XRAY_PRIVATE_KEY:?}" : "${XRAY_PUBLIC_KEY:?}"

      # Check for required TLS certificates first
      if [[ ! -f "${XRAY_CERT_DIR}/fullchain.pem" || ! -f "${XRAY_CERT_DIR}/privkey.pem" ]]; then
        core::log error "vision-reality topology requires TLS certificates" "$(printf '{"cert_dir":"%s","domain":"%s","suggestion":"Use cert-acme plugin or provide certificates manually"}' "${XRAY_CERT_DIR}" "${XRAY_DOMAIN}")"
        exit 2
      fi

      XRAY_REALITY_DEST="$(ensure_reality_dest "${XRAY_REALITY_DEST:-}" "${XRAY_SNI}")"
      [[ -n "${XRAY_PRIVATE_KEY}" ]] || { core::log error "XRAY_PRIVATE_KEY required"; exit 2; }
      local sn2; sn2="$(json_array_from_csv "${XRAY_SNI}")"
      cat >"${d}/05_inbounds.json" <<JSON
{"inbounds":[
{"tag":"vision","listen":"0.0.0.0","port":${XRAY_VISION_PORT},"protocol":"vless",
 "settings":{"clients":[{"id":"${XRAY_UUID_VISION}","flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"alpn":"h2","dest":${XRAY_FALLBACK_PORT}},{"dest":${XRAY_FALLBACK_PORT}}]},
 "streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"rejectUnknownSni":true,"minVersion":"1.2","alpn":["h2","http/1.1"],"certificates":[{"certificateFile":"${XRAY_CERT_DIR}/fullchain.pem","keyFile":"${XRAY_CERT_DIR}/privkey.pem","ocspStapling":3600}]}}, 
 "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls"]}},
{"tag":"reality","listen":"0.0.0.0","port":${XRAY_REALITY_PORT},"protocol":"vless",
 "settings":{"clients":[{"id":"${XRAY_UUID_REALITY}","flow":"xtls-rprx-vision"}],"decryption":"none"},
 "streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${XRAY_REALITY_DEST}","xver":0,"serverNames":${sn2},"privateKey":"${XRAY_PRIVATE_KEY}","shortIds":["","${XRAY_SHORT_ID}"],"spiderX":"/"}},
 "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls","quic"]}}]}
JSON
      ;;
    *) core::log error "unknown topology" "$(printf '{"topology":"%s"}' "${topology}")"; exit 3;;
  esac

  printf '{"routing":{"domainStrategy":"IPIfNonMatch","rules":[]}}' | io::atomic_write "${d}/09_routing.json" 0640
  chmod 0750 "${d}" || true; chown root:xray "${d}" 2>/dev/null || true
  for f in "${d}"/*.json; do chown root:xray "${f}" 2>/dev/null || true; chmod 0640 "${f}" || true; done

  plugins::emit configure_post "topology=${topology}" "release_dir=${d}"
  echo "${d}"
}

deploy_release(){
  local d="${1}"
  if [[ -x "$(xray::bin)" && "${XRF_SKIP_XRAY_TEST:-false}" != "true" ]]; then
    local test_output
    if ! test_output="$("$(xray::bin)" -test -confdir "${d}" -format json 2>&1)"; then
      local esc
      esc="${d//\"/\\\"}"
      core::log error "xray config test failed" "$(printf '{"confdir":"%s"}' "${esc}")"
      printf '%s\n' "${test_output}" >&2
      return 1
    fi
  fi
  local newdg; newdg="$(digest_confdir "${d}")"; local olddg=""; [[ -f "$(state::digest)" ]] && olddg="$(cat "$(state::digest)")"
  if [[ -n "${olddg}" && "${olddg}" == "${newdg}" ]]; then core::log info "no changes; skip reload" "$(printf '{"digest":"%s"}' "${newdg}")"; return 0; fi
  io::ensure_dir "$(xray::confbase)" 0755; io::ensure_dir "$(xray::releases)" 0755
  ln -sfn "${d}" "$(xray::active).new"; mv -Tf "$(xray::active).new" "$(xray::active)"
  echo "${newdg}" | io::atomic_write "$(state::digest)" 0644
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet xray 2>/dev/null; then systemctl reload-or-restart xray || systemctl restart xray || true; fi
  plugins::emit deploy_post "active_dir=$(xray::active)"
  core::log info "deployed" "$(printf '{"active":"%s"}' "$(xray::active)")"
}

deploy_with_lock(){
  local topology="${1}"
  local d
  d="$(render_release "${topology}")"
  deploy_release "${d}"
}

main(){
  core::init "${@}"
  local topology="reality-only"
  while [[ $# -gt 0 ]]; do case "${1}" in --topology) topology="${2}"; shift 2;; *) shift;; esac; done
  plugins::ensure_dirs; plugins::load_enabled
  core::with_flock "$(state::lock)" deploy_with_lock "${topology}"
}
main "${@}"
