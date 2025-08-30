#!/usr/bin/env bash
# Secure download helpers: SHA256 verification, remote .dgst parsing

verify::sha256() {
  # verify::sha256 <file> <expected>
  local file="$1" expected="$2"
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum not available" >&2; return 2
  fi
  local got; got="$(sha256sum "$file" | awk '{print $1}')"
  if [[ "$got" != "$expected" ]]; then
    echo "SHA256 mismatch: expected=$expected got=$got" >&2
    return 1
  fi
}

verify::fetch_dgst_sha256() {
  # verify::fetch_dgst_sha256 <url_to_zip>
  local url="$1"
  local dgst_url
  dgst_url="${XRAY_SHA256_URL:-${url}.dgst}"
  if command -v curl >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    if curl -fsSL "$dgst_url" -o "$tmp"; then
# Accept multiple formats:
# - SHA256=<hex>
# - SHA256 (file) = <hex>
# - <hex>  <file>
local val
val="$(
  awk '
    match($0,/^SHA256=([0-9A-Fa-f]{64})/,m){print m[1]; exit}
    match($0,/^SHA256 \([^)]+\) = ([0-9A-Fa-f]{64})/,m){print m[1]; exit}
    match($0,/^([0-9A-Fa-f]{64})[[:space:]]+/,m){print m[1]; exit}
  ' "$tmp"
)"

      if [[ -n "$val" ]]; then
        echo "$val"
        rm -f "$tmp"
        return 0
      fi
    fi
    rm -f "$tmp"
  fi
  return 1
}


verify::gpg() {
  # verify::gpg <file> <sig_file> <keyring>
  local file="$1" sig="$2" keyring="$3"
  if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg not available" >&2
    return 2
  }
  if [[ ! -s "$sig" ]]; then
    echo "signature file not found: $sig" >&2
    return 3
  fi
  if [[ -n "$keyring" && -f "$keyring" ]]; then
    gpg --no-default-keyring --keyring "$keyring" --verify "$sig" "$file"
  else
    gpg --verify "$sig" "$file"
  fi
}
