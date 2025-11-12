#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${HERE}/lib/core.sh"
. "${HERE}/modules/io.sh"
. "${HERE}/modules/user/user.sh"
. "${HERE}/services/xray/common.sh"
. "${HERE}/services/xray/install_utils.sh"

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
    local dgst_content
    core::log debug "downloading checksum file with retry" "$(printf '{"url":"%s.dgst"}' "${url}")"
    # Retry checksum download up to 3 times with exponential backoff
    if dgst_content="$(core::retry 3 curl -fsSL "${url}.dgst" 2>&1)"; then
      core::log debug "checksum file downloaded successfully" "{}"
      sha="$(xray::extract_sha256_from_dgst "${dgst_content}")"
    else
      core::log warn "checksum download failed after retries" "$(printf '{"dgst_url":"%s.dgst"}' "${url}")"
    fi
  fi

  # Security: Validate SHA256 format regardless of source
  if [[ -n "${sha}" ]]; then
    if ! xray::validate_sha256_format "${sha}"; then
      core::log error "invalid SHA256 format" "$(printf '{"sha256":"%s","source":"dgst_file"}' "${sha}")"
      exit 5
    fi
  else
    core::log error "missing SHA256 checksum" "$(printf '{"dgst_url":"%s.dgst","hint":"Network issue or file unavailable"}' "${url}")"
    core::log info "workaround: manually verify and set checksum" "$(printf '{"example":"XRAY_SHA256=<64-char-hex> xrf install ...","get_checksum":"curl -fsSL %s.dgst"}' "${url}")"
    exit 5
  fi

  # Verify file checksum
  if ! xray::verify_file_checksum "${tmp}/xray.zip" "${sha}"; then
    exit 6
  fi

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
