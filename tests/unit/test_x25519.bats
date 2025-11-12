#!/usr/bin/env bats
# Tests for lib/x25519.sh helpers

load ../test_helper

setup() {
  setup_test_env
  # shellcheck source=lib/x25519.sh
  . "${PROJECT_ROOT}/lib/x25519.sh"
}

teardown() {
  cleanup_test_env
}

@test "x25519::parse_keys extracts private and public values" {
  local output
  output=$(x25519::parse_keys $'Private key: AAAABBBBCCCCDDDD==\nPublic key: EEEEFFFFGGGGHHHH==')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "AAAABBBBCCCCDDDD==" ]
  [ "${public}" = "EEEEFFFFGGGGHHHH==" ]
}

@test "x25519::parse_keys tolerates uppercase labels and whitespace" {
  local output
  output=$(x25519::parse_keys $'  PUBLIC KEY :  QQQQRRRRSSSSTTTT==\r\n  private KEY:\tUUUUVVVVWWWWXXXX==')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "UUUUVVVVWWWWXXXX==" ]
  [ "${public}" = "QQQQRRRRSSSSTTTT==" ]
}

@test "x25519::parse_keys handles annotated output" {
  local output
  output=$(x25519::parse_keys $'Private key (base64): AAAABBBBCCCCDDDD== (x25519)\nPublic key => EEEEFFFFGGGGHHHH== (BASE64)')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "AAAABBBBCCCCDDDD==" ]
  [ "${public}" = "EEEEFFFFGGGGHHHH==" ]
}

@test "x25519::derive_public_key uses --key flag when available" {
  local fake_xray="${BATS_TEST_TMPDIR}/xray-bin"
  cat <<'SCRIPT' > "${fake_xray}"
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1}" == "x25519" ]]; then
  shift
  case "${1:-}" in
    --key)
      shift
      printf 'Public key: ZGVyaXZlZC1hYWFhPQ==\n'
      exit 0
      ;;
    --key=*)
      printf 'Public key: ZGVyaXZlZC1hYWFhPQ==\n'
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
fi
exit 1
SCRIPT
  chmod +x "${fake_xray}"

  local result
  result="$(x25519::derive_public_key "${fake_xray}" "aaaa=")"
  [ "${result}" = "ZGVyaXZlZC1hYWFhPQ==" ]
}

@test "x25519::derive_public_key falls back to -k flag" {
  local fake_xray="${BATS_TEST_TMPDIR}/xray-bin-fallback"
  cat <<'SCRIPT' > "${fake_xray}"
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1}" == "x25519" ]]; then
  shift
  case "${1:-}" in
    --key|-key)
      exit 1
      ;;
    -k)
      shift
      printf 'Public key: RmFsbGJhY2stYmJiYj0=\n'
      exit 0
      ;;
    -k=*)
      printf 'Public key: RmFsbGJhY2stYmJiYj0=\n'
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
fi
exit 1
SCRIPT
  chmod +x "${fake_xray}"

  local result
  result="$(x25519::derive_public_key "${fake_xray}" "bbbb=")"
  [ "${result}" = "RmFsbGJhY2stYmJiYj0=" ]
}

@test "x25519::derive_public_key returns failure when no output" {
  local fake_xray="${BATS_TEST_TMPDIR}/xray-empty"
  cat <<'SCRIPT' > "${fake_xray}"
#!/usr/bin/env bash
set -euo pipefail
exit 1
SCRIPT
  chmod +x "${fake_xray}"

  run x25519::derive_public_key "${fake_xray}" "cccc="
  [ "$status" -ne 0 ]
}
