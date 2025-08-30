#!/usr/bin/env bash
# Render Xray config from template, validate (optional), and reload service
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/modules/io.sh"
. "$HERE/modules/svc/svc.sh"

xray::prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
xray::etc()    { echo "${XRF_ETC:-/usr/local/etc}"; }
xray::confdir(){ echo "$(xray::etc)/xray"; }
xray::cfg()    { echo "$(xray::confdir)/config.json"; }
xray::bin()    { echo "$(xray::prefix)/bin/xray"; }

render() {
  local tmpl="${1:-$HERE/templates/xray/config.json.tmpl}"
  if ! command -v envsubst >/dev/null 2>&1; then
    core::log error "envsubst missing"; return 2
  fi
  io::ensure_dir "$(xray::confdir)" 0755
  if [[ "${XRF_DRY_RUN:-false}" == "true" ]]; then
    core::log info "Render preview" "$(printf '{"template":"%s"}' "$tmpl")"
    envsubst < "$tmpl" | jq . >/dev/null 2>&1 || { core::log error "JSON invalid after render"; return 3; }
    envsubst < "$tmpl" | sed -n '1,40p'
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  envsubst < "$tmpl" > "$tmp"
  if command -v jq >/dev/null 2>&1; then
    jq . < "$tmp" >/dev/null || { core::log error "JSON invalid" ; rm -f "$tmp"; return 3; }
  fi
  # optional: binary test
  if [[ -x "$(xray::bin)" && "${XRF_SKIP_XRAY_TEST:-false}" != "true" ]]; then
    "$(xray::bin)" -test -config "$tmp" >/dev/null || { core::log error "xray -test failed"; rm -f "$tmp"; return 4; }
  fi
  io::atomic_write "$(xray::cfg)" 0644 < "$tmp"
  rm -f "$tmp"
  core::log info "Config updated" "$(printf '{"path":"%s"}' "$(xray::cfg)")"
  # try reload service if present
  svc::reload xray || true
}

main() {
  core::init "$@"
  local tmpl="$HERE/templates/xray/config.json.tmpl"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template) tmpl="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  render "$tmpl"
}
main "$@"
