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
  output=$(x25519::parse_keys $'Private key: AAAA=\nPublic key: BBBB=')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "AAAA=" ]
  [ "${public}" = "BBBB=" ]
}

@test "x25519::parse_keys tolerates uppercase labels and whitespace" {
  local output
  output=$(x25519::parse_keys $'  PUBLIC KEY :  CCCC=\r\n  private KEY:\tDDDD=')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "DDDD=" ]
  [ "${public}" = "CCCC=" ]
}

@test "x25519::parse_keys handles annotated labels" {
  local output
  output=$(x25519::parse_keys $'Private key (hex): EEEE=\nPublic key (display): FFFF=')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "EEEE=" ]
  [ "${public}" = "FFFF=" ]
}

@test "x25519::parse_keys handles multiline values" {
  local output
  output=$(x25519::parse_keys $'Private key:\n  GGGG=\nPublic key:\n  HHHH=')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "GGGG=" ]
  [ "${public}" = "HHHH=" ]
}

@test "x25519::parse_keys prefers base64 sections" {
  local output
  output=$(x25519::parse_keys $'Private key:\n  base64: MMMM=\n  hex: 41424344\nPublic key:\n  base64: NNNN=\n  hex: 45464748')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "MMMM=" ]
  [ "${public}" = "NNNN=" ]
}

@test "x25519::parse_keys handles inline key pairs" {
  local output
  output=$(x25519::parse_keys $'Private key: IIII= Public key: JJJJ=')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "IIII=" ]
  [ "${public}" = "JJJJ=" ]
}

@test "x25519::parse_keys strips ANSI sequences" {
  local output
  output=$(x25519::parse_keys $'\e[32mPrivate key:\e[0m \e[36mKKKK=\e[0m\n\e[33mPublic key:\e[0m \e[35mLLLL=\e[0m')
  local -a parsed=()
  readarray -t parsed <<< "${output}"
  local private="${parsed[0]:-}"
  local public="${parsed[1]:-}"
  [ "${private}" = "KKKK=" ]
  [ "${public}" = "LLLL=" ]
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
        [ "${1:-}" = "aaaa=" ]
        printf 'Public key: YmFzZTY0S0VZ\n'
        exit 0
        ;;
      --key=*)
        [ "${1#*=}" = "aaaa=" ]
        printf 'Public key: YmFzZTY0S0VZ\n'
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
  [ "${result}" = "YmFzZTY0S0VZ" ]
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
        [ "${1:-}" = "bbbb=" ]
        printf 'Public key: QkFTRTY0S0VZ\n'
        exit 0
        ;;
      -k=*)
        [ "${1#*=}" = "bbbb=" ]
        printf 'Public key: QkFTRTY0S0VZ\n'
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
  [ "${result}" = "QkFTRTY0S0VZ" ]
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
