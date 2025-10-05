#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/lib/plugins.sh"
. "${HERE}/modules/state.sh"
. "${HERE}/modules/net/network.sh"
. "${HERE}/services/xray/common.sh"

main() {
  core::init "${@}"
  plugins::ensure_dirs
  plugins::load_enabled
  local st
  st="$(state::load)"
  local topo
  topo="$(echo "${st}" | jq -r '.name // .topology // "reality-only"')"
  local sni
  sni="$(echo "${st}" | jq -r '.xray.reality_sni // "www.microsoft.com"')"
  local sid
  sid="$(echo "${st}" | jq -r '.xray.short_id // empty')"
  local pbk
  pbk="$(echo "${st}" | jq -r '.xray.reality_public_key // empty')"
  # 确保shortId正确：如果为空，尝试从配置文件读取
  if [[ -z "${sid}" && -f "$(xray::active)/05_inbounds.json" ]]; then
    sid="$(jq -r '.inbounds[]?.streamSettings?.realitySettings?.shortIds?[1] // .inbounds[]?.streamSettings?.realitySettings?.shortIds?[0] // empty' "$(xray::active)/05_inbounds.json" 2> /dev/null | head -1)"
  fi
  local ip="${XRAY_SERVER_IP:-}"
  [[ -n "${ip}" ]] || ip="$(net::detect_public_ip || true)"
  [[ -n "${ip}" ]] || ip="YOUR_SERVER_IP"
  echo "========== LINKS =========="
  local links=()
  case "${topo}" in
    vision-reality)
      local vport rport uv ur dom
      vport="$(echo "${st}" | jq -r '.xray.vision_port // "8443"')"
      rport="$(echo "${st}" | jq -r '.xray.reality_port // "443"')"
      uv="$(echo "${st}" | jq -r '.xray.uuid_vision // empty')"
      ur="$(echo "${st}" | jq -r '.xray.uuid_reality // empty')"
      dom="$(echo "${st}" | jq -r '.xray.domain // empty')"
      if [[ -n "${dom}" && -n "${uv}" ]]; then
        local vlink="vless://${uv}@${dom}:${vport}?security=tls&flow=xtls-rprx-vision&sni=${dom}&fp=chrome#Vision-${dom}"
        echo "VISION : ${vlink}"
        links+=("${vlink}")
      fi
      if [[ -n "${ur}" && -n "${pbk}" && -n "${sid}" ]]; then
        local rlink="vless://${ur}@${ip}:${rport}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni%%,*}&fp=chrome&pbk=${pbk}&sid=${sid}&spx=%2F#REALITY-${ip}"
        echo "REALITY: ${rlink}"
        links+=("${rlink}")
      fi
      ;;
    *)
      local uuid port
      uuid="$(echo "${st}" | jq -r '.xray.uuid // empty')"
      port="$(echo "${st}" | jq -r '.xray.port // "443"')"
      if [[ -n "${uuid}" && -n "${pbk}" && -n "${sid}" ]]; then
        local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni%%,*}&fp=chrome&pbk=${pbk}&sid=${sid}&spx=%2F#REALITY-${ip}"
        echo "REALITY: ${link}"
        links+=("${link}")
      else
        echo "REALITY: vless://<UUID>@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni%%,*}&fp=chrome&pbk=<PUBLIC_KEY>&sid=<SHORT_ID>&spx=%2F#REALITY-${ip}"
      fi
      ;;
  esac
  # Emit plugin hook for each link
  for link in "${links[@]}"; do
    plugins::emit links_render "link=${link}" "topology=${topo}"
  done
  echo "=========================="
}
main "${@}"
