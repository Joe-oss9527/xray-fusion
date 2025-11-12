#!/usr/bin/env bash
# X25519 key utilities shared across install and status workflows

x25519::parse_keys() {
  local output="${1}" label value
  local private="" public=""

  while IFS=: read -r label value; do
    [[ -z "${label}" ]] && continue
    label="${label//:/}"
    label="${label//[[:space:]]/}"
    label="${label,,}"
    value="${value//[$'\r']/}"
    value="${value//[[:space:]]/}"
    case "${label}" in
      privatekey)
        [[ -z "${private}" && -n "${value}" ]] && private="${value}"
        ;;
      publickey)
        [[ -z "${public}" && -n "${value}" ]] && public="${value}"
        ;;
      *) ;;
    esac
  done <<< "${output}"

  printf '%s\n%s\n' "${private}" "${public}"
}

x25519::derive_public_key() {
  local xray_bin="${1}" private_key="${2}" output public="" flag

  for flag in --key -key -k; do
    output="$("${xray_bin}" x25519 "${flag}" "${private_key}" 2> /dev/null || true)"
    [[ -z "${output}" ]] && output="$("${xray_bin}" x25519 "${flag}=${private_key}" 2> /dev/null || true)"
    [[ -z "${output}" ]] && continue
    local -a parsed=()
    mapfile -t parsed < <(x25519::parse_keys "${output}")
    public="${parsed[1]:-}"
    if [[ -n "${public}" ]]; then
      printf '%s\n' "${public}"
      return 0
    fi
  done

  return 1
}
