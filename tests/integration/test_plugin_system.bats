#!/usr/bin/env bats
# Integration test for plugin system

load test_helper

setup() {
  setup_integration_env
  export HERE="${BATS_TEST_DIRNAME}/../.."
}

teardown() {
  cleanup_integration_env
}

@test "plugin system - enable and load plugin" {
  run bin/xrf plugin enable firewall
  [ "$status" -eq 0 ]

  # Verify symlink created
  [ -L "${HERE}/plugins/enabled/firewall.sh" ]

  # Verify plugin info works
  run bin/xrf plugin info firewall
  [ "$status" -eq 0 ]
  [[ "$output" == *"firewall"* ]]
}

@test "plugin system - disable plugin" {
  bin/xrf plugin enable logrotate-obs

  run bin/xrf plugin disable logrotate-obs
  [ "$status" -eq 0 ]

  # Verify symlink removed
  [ ! -e "${HERE}/plugins/enabled/logrotate-obs.sh" ]
}

@test "plugin system - invalid plugin rejected" {
  run bin/xrf plugin enable nonexistent-plugin
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
