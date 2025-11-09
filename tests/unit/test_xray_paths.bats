#!/usr/bin/env bats
# Unit tests for Xray path functions (services/xray/common.sh)

load ../test_helper

setup() {
  setup_test_env
  # Source xray/common.sh
  source "${PROJECT_ROOT}/services/xray/common.sh"
}

teardown() {
  cleanup_test_env
}

# Test: xray::prefix
@test "xray::prefix - returns default prefix" {
  unset XRF_PREFIX
  run xray::prefix
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local" ]]
}

@test "xray::prefix - respects XRF_PREFIX environment variable" {
  export XRF_PREFIX="/custom/prefix"
  run xray::prefix
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/prefix" ]]
}

@test "xray::prefix - handles empty XRF_PREFIX" {
  export XRF_PREFIX=""
  run xray::prefix
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local" ]]
}

# Test: xray::etc
@test "xray::etc - returns default etc" {
  unset XRF_ETC
  run xray::etc
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/etc" ]]
}

@test "xray::etc - respects XRF_ETC environment variable" {
  export XRF_ETC="/custom/etc"
  run xray::etc
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/etc" ]]
}

@test "xray::etc - handles empty XRF_ETC" {
  export XRF_ETC=""
  run xray::etc
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/etc" ]]
}

# Test: xray::confbase
@test "xray::confbase - returns correct path with default etc" {
  unset XRF_ETC
  run xray::confbase
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/etc/xray" ]]
}

@test "xray::confbase - uses custom XRF_ETC" {
  export XRF_ETC="/custom/etc"
  run xray::confbase
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/etc/xray" ]]
}

@test "xray::confbase - constructs path correctly" {
  export XRF_ETC="${TEST_TMPDIR}/etc"
  local expected="${TEST_TMPDIR}/etc/xray"

  run xray::confbase
  [ "$status" -eq 0 ]
  [[ "$output" == "${expected}" ]]
}

# Test: xray::releases
@test "xray::releases - returns correct path with default" {
  unset XRF_ETC
  run xray::releases
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/etc/xray/releases" ]]
}

@test "xray::releases - uses custom XRF_ETC" {
  export XRF_ETC="/custom/etc"
  run xray::releases
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/etc/xray/releases" ]]
}

@test "xray::releases - constructs nested path correctly" {
  export XRF_ETC="${TEST_TMPDIR}/etc"
  local expected="${TEST_TMPDIR}/etc/xray/releases"

  run xray::releases
  [ "$status" -eq 0 ]
  [[ "$output" == "${expected}" ]]
}

# Test: xray::active
@test "xray::active - returns correct path with default" {
  unset XRF_ETC
  run xray::active
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/etc/xray/active" ]]
}

@test "xray::active - uses custom XRF_ETC" {
  export XRF_ETC="/custom/etc"
  run xray::active
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/etc/xray/active" ]]
}

@test "xray::active - constructs path correctly" {
  export XRF_ETC="${TEST_TMPDIR}/etc"
  local expected="${TEST_TMPDIR}/etc/xray/active"

  run xray::active
  [ "$status" -eq 0 ]
  [[ "$output" == "${expected}" ]]
}

# Test: xray::bin
@test "xray::bin - returns correct path with default prefix" {
  unset XRF_PREFIX
  run xray::bin
  [ "$status" -eq 0 ]
  [[ "$output" == "/usr/local/bin/xray" ]]
}

@test "xray::bin - uses custom XRF_PREFIX" {
  export XRF_PREFIX="/custom/prefix"
  run xray::bin
  [ "$status" -eq 0 ]
  [[ "$output" == "/custom/prefix/bin/xray" ]]
}

@test "xray::bin - constructs path correctly" {
  export XRF_PREFIX="${TEST_TMPDIR}"
  local expected="${TEST_TMPDIR}/bin/xray"

  run xray::bin
  [ "$status" -eq 0 ]
  [[ "$output" == "${expected}" ]]
}

# Integration tests: path consistency
@test "all paths use consistent XRF_PREFIX" {
  export XRF_PREFIX="${TEST_TMPDIR}/custom"
  export XRF_ETC="${TEST_TMPDIR}/custom/etc"

  local prefix_result
  local etc_result
  local confbase_result
  local bin_result

  prefix_result=$(xray::prefix)
  etc_result=$(xray::etc)
  confbase_result=$(xray::confbase)
  bin_result=$(xray::bin)

  [[ "${prefix_result}" == "${TEST_TMPDIR}/custom" ]]
  [[ "${etc_result}" == "${TEST_TMPDIR}/custom/etc" ]]
  [[ "${confbase_result}" == "${TEST_TMPDIR}/custom/etc/xray" ]]
  [[ "${bin_result}" == "${TEST_TMPDIR}/custom/bin/xray" ]]
}

@test "all paths have correct hierarchy" {
  export XRF_PREFIX="${TEST_TMPDIR}/usr/local"
  export XRF_ETC="${TEST_TMPDIR}/usr/local/etc"

  local confbase
  local releases
  local active

  confbase=$(xray::confbase)
  releases=$(xray::releases)
  active=$(xray::active)

  # Check hierarchy
  [[ "${releases}" == "${confbase}/releases" ]]
  [[ "${active}" == "${confbase}/active" ]]
}
