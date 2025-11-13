#!/usr/bin/env bash
# X25519 key utilities shared across install and status workflows

x25519::parse_keys() {
  local output="${1}" line lower value expect=""
  local private="" public=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line//$'\r'/}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    lower="${line,,}"

    if [[ ${expect} == "private" || ${expect} == "public" ]]; then
      value="${line//[[:space:]]/}"
      value="${value//[^A-Za-z0-9+/=]/}"
      if [[ ${#value} -ge 32 ]]; then
        if [[ ${expect} == "private" && -z "${private}" ]]; then
          private="${value}"
        elif [[ ${expect} == "public" && -z "${public}" ]]; then
          public="${value}"
        fi
        expect=""
        continue
      fi
    fi

    if [[ "${lower}" == *private*key* ]]; then
      value="${line#*:}"
      if [[ "${value}" != "${line}" ]]; then
        value="${value//[[:space:]]/}"
        value="${value//[^A-Za-z0-9+/=]/}"
        if [[ ${#value} -ge 32 && -z "${private}" ]]; then
          private="${value}"
          expect=""
          continue
        fi
      fi
      expect="private"
      continue
    fi

    if [[ "${lower}" == *public*key* ]]; then
      value="${line#*:}"
      if [[ "${value}" != "${line}" ]]; then
        value="${value//[[:space:]]/}"
        value="${value//[^A-Za-z0-9+/=]/}"
        if [[ ${#value} -ge 32 && -z "${public}" ]]; then
          public="${value}"
          expect=""
          continue
        fi
      fi
      expect="public"
      continue
    fi
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
