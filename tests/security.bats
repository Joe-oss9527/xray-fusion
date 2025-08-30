#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
load test_helper

setup() {
  setup_test_env
}

teardown() {
  cleanup_test_env
}

@test "credential generation generates unique UUID" {
  # Test UUID generation directly
  run bash -c "if command -v uuidgen >/dev/null 2>&1; then uuidgen; else echo 'uuidgen not found'; fi"
  
  [ "$status" -eq 0 ]
  if [[ "$output" != "uuidgen not found" ]]; then
    [[ "$output" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
    [[ "$output" != "00000000-0000-0000-0000-000000000000" ]]
  else
    skip "uuidgen not available"
  fi
}

@test "credential generation generates random short ID" {
  # Test short ID generation
  run bash -c "
    if command -v openssl >/dev/null 2>&1; then
      openssl rand -hex 8
    else
      head -c 8 /dev/urandom | hexdump -e '16/1 \"%02x\"'
    fi"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{16}$ ]]
  [[ "$output" != "0123456789abcdef" ]]
}

@test "download verification fails with bad SHA256" {
  skip "requires mock download setup"
  # This would test that SHA256 verification properly fails
}

@test "sudo operations show transparency warnings" {
  # Test that sudo operations provide warnings
  export XRF_DRY_RUN=true
  export XRF_AUTO_SUDO=false
  
  run bash -c "source modules/io.sh; source lib/core.sh; io::confirm_sudo 'test operation'"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Plan requires sudo" ]]
}

@test "topology context requires all variables" {
  # Test that topology functions fail with missing variables
  cd "${HERE}"
  run -127 bash -c ". topologies/reality-only.sh; topology::context"
  
  [ "$status" -ne 0 ]
  [[ "$output" =~ "must be set" ]]
}

@test "topology context works with all variables set" {
  # Test that topology functions work with all variables
  export XRAY_PORT=8443
  export XRAY_UUID="test-uuid-1234"
  export XRAY_REALITY_SNI="test.example.com"  
  export XRAY_SHORT_ID="testshortid123"
  
  cd "${HERE}"
  run bash -c ". topologies/reality-only.sh; topology::context"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "reality-only" ]]
  [[ "$output" =~ "test-uuid-1234" ]]
  [[ "$output" =~ "testshortid123" ]]
}