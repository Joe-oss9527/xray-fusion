#!/usr/bin/env bats
# Unit tests for core functions (lib/core.sh)

load ../test_helper

setup() {
  setup_test_env
}

teardown() {
  cleanup_test_env
}

@test "core::ts - returns ISO 8601 timestamp" {
  run core::ts
  [ "$status" -eq 0 ]
  # Check format: YYYY-MM-DDTHH:MM:SSZ
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "core::log - outputs to stderr in text mode" {
  XRF_JSON=false
  run core::log info "test message"
  [ "$status" -eq 0 ]
  # Log should go to stderr (captured in output by bats)
  [[ "$output" == *"test message"* ]]
}

@test "core::log - outputs JSON in JSON mode" {
  XRF_JSON=true
  run core::log info "test message"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"level":"info"'* ]]
  [[ "$output" == *'"msg":"test message"'* ]]
}

@test "core::log - filters debug messages unless XRF_DEBUG=true" {
  XRF_DEBUG=false
  run core::log debug "debug message"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "core::log - shows debug messages when XRF_DEBUG=true" {
  XRF_DEBUG=true
  run core::log debug "debug message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"debug message"* ]]
}

@test "core::retry - succeeds on first attempt" {
  run core::retry 3 true
  [ "$status" -eq 0 ]
}

@test "core::retry - fails after max attempts" {
  run core::retry 2 false
  [ "$status" -eq 1 ]
}

@test "core::retry - succeeds after retries" {
  # Create a file that acts as a counter
  counter_file="${TEST_TMPDIR}/counter"
  echo "0" > "${counter_file}"

  # Function that fails twice then succeeds
  flaky_cmd() {
    local count=$(cat "${counter_file}")
    count=$((count + 1))
    echo "${count}" > "${counter_file}"
    [ "${count}" -ge 3 ]
  }

  run core::retry 5 flaky_cmd
  [ "$status" -eq 0 ]
}
