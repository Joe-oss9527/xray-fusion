#!/usr/bin/env bash
# Common Xray paths and utilities
# NOTE: This file is sourced. Strict mode is set by core::init() from the calling script
xray::prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
xray::etc() { echo "${XRF_ETC:-/usr/local/etc}"; }
xray::confbase() { echo "$(xray::etc)/xray"; }
xray::releases() { echo "$(xray::confbase)/releases"; }
xray::active() { echo "$(xray::confbase)/active"; }
xray::bin() { echo "$(xray::prefix)/bin/xray"; }

##
# Generate a random shortId for Xray Reality
#
# Creates a 16-character hexadecimal string using reliable tools.
# Tries xxd → od → openssl (in order of preference).
#
# Output:
#   16-character hexadecimal string to stdout
#
# Returns:
#   0 - Success
#   1 - All tools failed (should never happen, openssl is always available)
#
# Example:
#   shortid=$(xray::generate_shortid)
#   # Output: a1b2c3d4e5f67890
##
xray::generate_shortid() {
  local result=""

  if command -v xxd > /dev/null 2>&1; then
    result="$(head -c 8 /dev/urandom | xxd -p -c 16)"
  elif command -v od > /dev/null 2>&1; then
    result="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
  elif command -v openssl > /dev/null 2>&1; then
    result="$(openssl rand -hex 8)"
  else
    # This should never happen as openssl is a project dependency
    echo "ERROR: no suitable tool found for shortId generation" >&2
    return 1
  fi

  # Output the result
  echo "${result}"
  return 0
}
