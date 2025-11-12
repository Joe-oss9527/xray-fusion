#!/usr/bin/env bash
# X25519 key utilities shared across install and status workflows

x25519::parse_keys() {
  local output="${1:-}"
  local private="" public=""
  local -a tokens=()

  while IFS= read -r line; do
    line="${line//$'\r'/}"
    [[ -z "${line//[[:space:]]/}" ]] && continue

    local lower="${line,,}"
    local sanitized="${line//[^A-Za-z0-9+/=]/ }"

    for token in ${sanitized}; do
      [[ -z "${token}" || ${#token} -lt 16 ]] && continue

      tokens+=("${token}")

      if [[ -z "${private}" && "${lower}" == *private* ]]; then
        private="${token}"
        break
      fi

      if [[ -z "${public}" && "${lower}" == *public* ]]; then
        public="${token}"
        break
      fi
    done
  done <<< "${output}"

  if [[ -z "${private}" ]]; then
    for token in "${tokens[@]}"; do
      [[ ${#token} -lt 16 ]] && continue
      private="${token}"
      break
    done
  fi

  if [[ -z "${public}" ]]; then
    local idx=0
    for token in "${tokens[@]}"; do
      [[ ${#token} -lt 16 ]] && continue
      if [[ ${idx} -eq 0 ]]; then
        # first candidate already used for private; skip if same as private
        idx=1
        if [[ -z "${private}" ]]; then
          private="${token}"
          continue
        fi
        if [[ "${token}" == "${private}" ]]; then
          continue
        fi
      fi
      public="${token}"
      break
    done
  fi

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
