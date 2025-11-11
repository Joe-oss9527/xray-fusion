#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/user/user.sh"
. "${HERE}/services/xray/common.sh"

need() { command -v "${1}" > /dev/null 2>&1 || {
  core::log error "missing dependency" "$(printf '{"bin":"%s"}' "${1}")"
  exit 3
}; }

xray::install() {
  local version="${1:-latest}" arch_u url url_tmpl sha
  need curl
  need unzip
  arch_u="$(uname -m)"
  case "${arch_u}" in
    x86_64 | amd64) url_tmpl="Xray-linux-64.zip" ;;
    aarch64 | arm64) url_tmpl="Xray-linux-arm64-v8a.zip" ;;
    *)
      core::log error "unsupported arch" "$(printf '{"arch":"%s"}' "${arch_u}")"
      exit 2
      ;;
  esac

  # Security: Validate version parameter format
  if [[ "${version}" != "latest" ]]; then
    if [[ ! "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      core::log error "invalid version format" "$(printf '{"version":"%s"}' "${version}")"
      exit 1
    fi
  fi

  if [[ "${version}" == "latest" ]]; then
    version=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    [[ -n "${version}" && "${version}" != "null" ]] || {
      core::log error "resolve latest failed" "{}"
      exit 1
    }

    # Security: Validate resolved version format
    if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      core::log error "invalid resolved version format" "$(printf '{"version":"%s"}' "${version}")"
      exit 1
    fi
  fi
  [[ "${version}" =~ ^v ]] || version="v${version}"

  url="${XRAY_URL:-https://github.com/XTLS/Xray-core/releases/download/${version}/${url_tmpl}}"
  sha="${XRAY_SHA256:-}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  core::log info "downloading xray" "$(printf '{"url":"%s","version":"%s"}' "${url}" "${version}")"
  if ! curl -fsSL "${url}" -o "${tmp}/xray.zip"; then
    core::log error "download failed" "$(printf '{"url":"%s","hint":"Check network or try: XRAY_URL=<mirror-url>"}' "${url}")"
    exit 4
  fi

  if [[ -z "${sha}" ]]; then
    # SHA256 extraction: handle multiple .dgst formats safely
    # Format 1: SHA256 (file) = hash  (priority - avoids SHA512 confusion)
    # Format 2: hash filename         (fallback for plain checksums)
    local dgst_content
    dgst_content="$(curl -fsSL "${url}.dgst" 2> /dev/null)" || true
    if [[ -n "${dgst_content}" ]]; then
      # Try labeled SHA256 first
      sha="$(echo "${dgst_content}" | grep -i 'SHA256' | grep -oE '[0-9A-Fa-f]{64}' | head -1)" || true
      # Fallback to plain hash at line start
      if [[ -z "${sha}" ]]; then
        sha="$(echo "${dgst_content}" | grep -oE '^[0-9A-Fa-f]{64}' | head -1)" || true
      fi
    fi
  fi

  # Security: Validate SHA256 format regardless of source
  if [[ -n "${sha}" ]]; then
    if [[ ! "${sha}" =~ ^[0-9A-Fa-f]{64}$ ]]; then
      core::log error "invalid SHA256 format" "$(printf '{"sha256":"%s","source":"dgst_file"}' "${sha}")"
      exit 5
    fi
  else
    core::log error "missing SHA256 checksum" "$(printf '{"dgst_url":"%s.dgst","hint":"Set XRAY_SHA256 env var or check network connectivity"}' "${url}")"
    exit 5
  fi
  got="$(sha256sum "${tmp}/xray.zip" | awk '{print $1}')"
  [[ "${got}" == "${sha}" ]] || {
    core::log error "SHA256 mismatch" "$(printf '{"expected":"%s","got":"%s"}' "${sha}" "${got}")"
    exit 6
  }

  (cd "${tmp}" && unzip -q xray.zip)
  io::ensure_dir "$(xray::prefix)/bin" 0755
  io::install_file "${tmp}/xray" "$(xray::bin)" 0755
  user::ensure_system_user xray xray
  core::log info "installed" "$(printf '{"bin":"%s"}' "$(xray::bin)")"
}

main() {
  core::init "${@}"
  local version="latest"
  while [[ $# -gt 0 ]]; do case "${1}" in --version)
    version="${2}"
    shift 2
    ;;
  *) shift ;; esac done
  xray::install "${version}"
}
main "${@}"
