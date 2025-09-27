#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"; . "${HERE}/modules/io.sh"; . "${HERE}/modules/user/user.sh"; . "${HERE}/services/xray/common.sh"

need(){ command -v "${1}" >/dev/null 2>&1 || { core::log error "missing dependency" "$(printf '{"bin":"%s"}' "${1}")"; exit 3; }; }

xray::install(){
  local version="${1:-latest}" arch_u url url_tmpl sha
  need curl; need unzip
  arch_u="$(uname -m)"
  case "${arch_u}" in
    x86_64|amd64) url_tmpl="Xray-linux-64.zip" ;;
    aarch64|arm64) url_tmpl="Xray-linux-arm64-v8a.zip" ;;
    *) core::log error "unsupported arch" "$(printf '{"arch":"%s"}' "${arch_u}")"; exit 2 ;;
  esac

  if [[ "${version}" == "latest" ]]; then
    version=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    [[ -n "${version}" && "${version}" != "null" ]] || { core::log error "resolve latest failed" "{}"; exit 1; }
  fi
  [[ "${version}" =~ ^v ]] || version="v${version}"

  url="${XRAY_URL:-https://github.com/XTLS/Xray-core/releases/download/${version}/${url_tmpl}}"
  sha="${XRAY_SHA256:-}"

  tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
  core::log info "download" "$(printf '{"url":"%s"}' "${url}")"; curl -fsSL "${url}" -o "${tmp}/xray.zip"

  if [[ -z "${sha}" ]]; then
    sha="$(curl -fsSL "${url}.dgst" 2>/dev/null | awk 'match($0,/^SHA2?-?256[= ] *([0-9A-Fa-f]{64})/,m){print m[1]; exit} match($0,/^SHA256 \([^)]+\) = ([0-9A-Fa-f]{64})/,m){print m[1]; exit} match($0,/^([0-9A-Fa-f]{64})[[:space:]]+/,m){print m[1]; exit}')" || true
  fi
  [[ -n "${sha}" ]] || { core::log error "missing SHA256 (set XRAY_SHA256 to override)" "{}"; exit 5; }
  got="$(sha256sum "${tmp}/xray.zip" | awk '{print $1}')"; [[ "${got}" == "${sha}" ]] || { core::log error "SHA256 mismatch" "$(printf '{"expected":"%s","got":"%s"}' "${sha}" "${got}")"; exit 6; }

  (cd "${tmp}" && unzip -q xray.zip)
  io::ensure_dir "$(xray::prefix)/bin" 0755; io::install_file "${tmp}/xray" "$(xray::bin)" 0755
  user::ensure_system_user xray xray
  core::log info "installed" "$(printf '{"bin":"%s"}' "$(xray::bin)")"
}

main(){ core::init "${@}"; local version="latest"; while [[ $# -gt 0 ]]; do case "${1}" in --version) version="${2}"; shift 2;; *) shift;; esac; done; xray::install "${version}"; }
main "${@}"
