#!/usr/bin/env bash
# X25519 key utilities shared across install and status workflows

x25519::strip_ansi() {
  local value="${1-}"
  local pattern=$'\e''\[[0-9;]*[A-Za-z]'

  while [[ "${value}" =~ ${pattern} ]]; do
    value="${value/${BASH_REMATCH[0]}/}"
  done

  printf '%s' "${value}"
}

x25519::consume_token() {
  local text="${1-}"

  if [[ "${text}" =~ ^[[:space:]]*([A-Za-z0-9+/=]{4,}) ]]; then
    local token="${BASH_REMATCH[1]}"
    local prefix="${BASH_REMATCH[0]}"
    local prefix_len="${#prefix}"
    printf '%s\n%s' "${token}" "${text:${prefix_len}}"
    return 0
  fi

  return 1
}

x25519::classify_label() {
  local label="${1-}"

  label="${label,,}"
  label="${label//[[:space:]]/}"
  label="${label//[^a-z]/}"

  if [[ "${label}" == *private*key* ]]; then
    printf 'private'
    return 0
  fi

  if [[ "${label}" == *public*key* ]]; then
    printf 'public'
    return 0
  fi

  return 1
}

x25519::parse_keys() {
  local output="${1}" line remainder expect="" classification
  local private="" public=""

  output="${output//$'\r'/}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="$(x25519::strip_ansi "${line}")"
    [[ -z "${line//[[:space:]]/}" ]] && continue

    remainder="${line}"

    if [[ -n "${expect}" ]]; then
      if [[ "${remainder}" != *:* ]]; then
        local consumed=""
        consumed="$(x25519::consume_token "${remainder}" 2> /dev/null || true)"
        if [[ -n "${consumed}" ]]; then
          local token="" rest=""
          token="${consumed%%$'\n'*}"
          if [[ "${consumed}" == *$'\n'* ]]; then
            rest="${consumed#*$'\n'}"
          fi
          if [[ "${expect}" == "private" && -z "${private}" ]]; then
            private="${token}"
          elif [[ "${expect}" == "public" && -z "${public}" ]]; then
            public="${token}"
          fi
          remainder="${rest}"
          expect=""
          continue
        fi

        # no token found on this line; move to next line
        continue
      fi

      # colon encountered before value; drop expectation and process labels
      expect=""
    fi

    while [[ "${remainder}" == *:* ]]; do
      local label="${remainder%%:*}"
      remainder="${remainder#*:}"

      local classification=""
      classification="$(x25519::classify_label "${label}" 2> /dev/null || true)"
      if [[ -z "${classification}" ]]; then
        continue
      fi

      local consumed=""
      consumed="$(x25519::consume_token "${remainder}" 2> /dev/null || true)"
      if [[ -n "${consumed}" ]]; then
        local token="" rest=""
        token="${consumed%%$'\n'*}"
        if [[ "${consumed}" == *$'\n'* ]]; then
          rest="${consumed#*$'\n'}"
        fi
        if [[ "${classification}" == "private" && -z "${private}" ]]; then
          private="${token}"
        elif [[ "${classification}" == "public" && -z "${public}" ]]; then
          public="${token}"
        fi
        remainder="${rest}"
        continue
      fi

      expect="${classification}"
      break
    done
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
