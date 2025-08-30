#!/usr/bin/env bash
# Install Xray binary into FHS layout with atomic operations
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/io.sh"
. "$HERE/modules/pkg/pkg.sh"
# shellcheck source=modules/sec/verify.sh
. "$HERE/modules/sec/verify.sh"

xray::prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
xray::etc()    { echo "${XRF_ETC:-/usr/local/etc}"; }
xray::var()    { echo "${XRF_VAR:-/var/lib/xray-fusion}"; }

xray::bin()    { echo "$(xray::prefix)/bin/xray"; }
xray::confdir(){ echo "$(xray::etc)/xray"; }
xray::cfg()    { echo "$(xray::confdir)/config.json"; }

xray::install() {
  local version="${1:-latest}"
  local arch="$(uname -m)"
  local url=""
  local sha=""

  # Allow override by env (useful for testing or mirrors)
  if [[ -n "${XRAY_URL:-}" ]]; then
    url="$XRAY_URL"
  fi
  if [[ -n "${XRAY_SHA256:-}" ]]; then
    sha="$XRAY_SHA256"
  fi

  case "$arch" in
    x86_64|amd64) url="https://github.com/XTLS/Xray-core/releases/download/${version/v/}/Xray-linux-64.zip" ;;
    aarch64|arm64) url="https://github.com/XTLS/Xray-core/releases/download/${version/v/}/Xray-linux-arm64-v8a.zip" ;;
    *) core::log error "Unsupported arch" "{"arch":"$arch"}"; return 2 ;;
  esac

  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Plan install Xray" "$(printf '{"version":"%s","url":"%s","prefix":"%s"}' "$version" "$url" "$(xray::prefix)")"
    echo "Would download: $url"
    echo "Would install to: $(xray::bin)"
    return 0
  fi

  # Ensure deps
  pkg::ensure curl || true
  pkg::ensure unzip || true

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  core::log info "Downloading" "$(printf '{"url":"%s"}' "$url")"
  curl -fsSL "$url" -o "$tmpdir/xray.zip"
  # checksum
  if [[ -z "$sha" ]]; then sha="$(verify::fetch_dgst_sha256 "$url" || true)"; fi
  if [[ -n "$sha" ]]; then
    core::log info "Verifying SHA256" "$(printf '{"sha256":"%s"}' "$sha")"
    verify::sha256 "$tmpdir/xray.zip" "$sha" || { core::log error "checksum failed"; return 4; }
  else
    core::log warn "No SHA256 available (proceeding without verification)";
  fi
# optional: GPG signature verification
if [[ -n "${XRAY_GPG_KEYRING:-}" ]]; then
  local sig="$tmpdir/xray.zip.asc"
  local sig_url="${XRAY_SIG_URL:-${url}.asc}"
  core::log info "Downloading signature" "$(printf '{"sig_url":"%s"}' "$sig_url")"
  curl -fsSL "$sig_url" -o "$sig" || { core::log error "signature download failed"; return 5; }
  verify::gpg "$tmpdir/xray.zip" "$sig" "$XRAY_GPG_KEYRING" || { core::log error "gpg verify failed"; return 6; }
  core::log info "GPG verified" "{}"
fi

  if [[ "${XRAY_FETCH_ONLY:-false}" == "true" ]]; then core::log info "Fetch-only complete" "{}"; return 0; fi

  (cd "$tmpdir" && unzip -q xray.zip)

  io::ensure_dir "$(xray::prefix)/bin" 0755
  io::ensure_dir "$(xray::confdir)" 0755

  # Move binary
  io::install_file "$tmpdir/xray" "$(xray::bin)" 0755
  core::log info "Installed" "$(printf '{"bin":"%s"}' "$(xray::bin)")"
}

# Entry
# Usage: services/xray/install.sh [--version vX.Y.Z|latest]
main() {
  core::init "$@"
  local version="latest"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) version="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  xray::install "$version"
}
main "$@"
