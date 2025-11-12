#!/usr/bin/env bats
# Unit tests for services/xray/client-links.sh

load ../test_helper

setup() {
  setup_test_env
  mkdir -p "${XRF_VAR}"
}

teardown() {
  cleanup_test_env
}

write_state() {
  local json="${1}"
  cat <<JSON > "${XRF_VAR}/state.json"
${json}
JSON
}

@test "client-links emits populated reality-only link" {
  write_state '{
    "name": "reality-only",
    "xray": {
      "port": 443,
      "uuid": "11111111-2222-3333-4444-555555555555",
      "reality_sni": "www.microsoft.com",
      "short_id": "abcd1234ef567890",
      "reality_public_key": "Base64PublicKey=="
    }
  }'

  run env XRAY_SERVER_IP=203.0.113.10 "${PROJECT_ROOT}/services/xray/client-links.sh" reality-only

  [ "$status" -eq 0 ]
  assert_contains "${output}" "REALITY: vless://11111111-2222-3333-4444-555555555555@203.0.113.10:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=Base64PublicKey==&sid=abcd1234ef567890&spx=%2F#REALITY-203.0.113.10"
  [[ "${output}" != *"<UUID>"* ]]
  [[ "${output}" != *"<PUBLIC_KEY>"* ]]
  [[ "${output}" != *"<SHORT_ID>"* ]]
}
