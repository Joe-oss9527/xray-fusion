#!/usr/bin/env bats
# Unit tests for lib/error_codes.sh

load ../test_helper

setup() {
  setup_test_env
  # Source the error codes module
  source "${PROJECT_ROOT}/lib/error_codes.sh"
}

teardown() {
  cleanup_test_env
}

# ==============================================================================
# error_codes::show Tests
# ==============================================================================

@test "error_codes::show - text format output" {
  export XRF_JSON="false"

  run error_codes::show "XRF-TEST-001" "Test error" "Test reason" "Test resolution" "Test examples"
  [ "$status" -eq 1 ]  # Always returns error status

  # Check output contains key elements
  [[ "${output}" == *"XRF-TEST-001"* ]]
  [[ "${output}" == *"Test error"* ]]
  [[ "${output}" == *"Reason:"* ]]
  [[ "${output}" == *"Test reason"* ]]
  [[ "${output}" == *"Resolution:"* ]]
  [[ "${output}" == *"Test resolution"* ]]
  [[ "${output}" == *"Examples:"* ]]
  [[ "${output}" == *"Test examples"* ]]
  [[ "${output}" == *"Learn more:"* ]]
}

@test "error_codes::show - JSON format output" {
  export XRF_JSON="true"

  run error_codes::show "XRF-TEST-001" "Test error" "Test reason" "Test resolution" ""
  [ "$status" -eq 1 ]

  # Check JSON structure
  [[ "${output}" == *'"error_code": "XRF-TEST-001"'* ]]
  [[ "${output}" == *'"title": "Test error"'* ]]
  [[ "${output}" == *'"reason": "Test reason"'* ]]
  [[ "${output}" == *'"resolution": "Test resolution"'* ]]
}

@test "error_codes::show - requires all mandatory parameters" {
  run error_codes::show "XRF-TEST-001" "Test error" "Test reason"
  [ "$status" -ne 0 ]
}

# ==============================================================================
# error_codes::invalid_domain Tests
# ==============================================================================

@test "error_codes::invalid_domain - basic usage" {
  export XRF_JSON="false"

  run error_codes::invalid_domain "192.168.1.1"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-CONFIG-001"* ]]
  [[ "${output}" == *"192.168.1.1"* ]]
  [[ "${output}" == *"Invalid domain"* ]]
}

@test "error_codes::invalid_domain - with specific reason" {
  export XRF_JSON="false"

  run error_codes::invalid_domain "192.168.1.1" "RFC 1918 private IP"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"RFC 1918 private IP"* ]]
}

@test "error_codes::invalid_domain - includes examples" {
  export XRF_JSON="false"

  run error_codes::invalid_domain "test.local"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"xrf install"* ]]
  [[ "${output}" == *"--topology"* ]]
}

# ==============================================================================
# error_codes::invalid_topology Tests
# ==============================================================================

@test "error_codes::invalid_topology - basic usage" {
  export XRF_JSON="false"

  run error_codes::invalid_topology "invalid-topo"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-CONFIG-002"* ]]
  [[ "${output}" == *"invalid-topo"* ]]
  [[ "${output}" == *"Invalid topology"* ]]
}

@test "error_codes::invalid_topology - suggests valid options" {
  export XRF_JSON="false"

  run error_codes::invalid_topology "wrong"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"reality-only"* ]]
  [[ "${output}" == *"vision-reality"* ]]
}

# ==============================================================================
# error_codes::missing_parameter Tests
# ==============================================================================

@test "error_codes::missing_parameter - basic usage" {
  export XRF_JSON="false"

  run error_codes::missing_parameter "domain"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-CONFIG-003"* ]]
  [[ "${output}" == *"--domain"* ]]
  [[ "${output}" == *"Missing required parameter"* ]]
}

@test "error_codes::missing_parameter - with context" {
  export XRF_JSON="false"

  run error_codes::missing_parameter "domain" "vision-reality topology"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"vision-reality topology"* ]]
}

# ==============================================================================
# error_codes::port_conflict Tests
# ==============================================================================

@test "error_codes::port_conflict - basic usage" {
  export XRF_JSON="false"

  run error_codes::port_conflict "443"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-NETWORK-001"* ]]
  [[ "${output}" == *"443"* ]]
  [[ "${output}" == *"Port conflict"* ]]
}

@test "error_codes::port_conflict - with process name" {
  export XRF_JSON="false"

  run error_codes::port_conflict "443" "nginx"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"nginx"* ]]
}

# ==============================================================================
# error_codes::cert_not_found Tests
# ==============================================================================

@test "error_codes::cert_not_found - basic usage" {
  export XRF_JSON="false"

  run error_codes::cert_not_found "/path/to/cert.pem"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-CERT-001"* ]]
  [[ "${output}" == *"/path/to/cert.pem"* ]]
  [[ "${output}" == *"Certificate not found"* ]]
}

# ==============================================================================
# error_codes::invalid_uuid Tests
# ==============================================================================

@test "error_codes::invalid_uuid - basic usage" {
  export XRF_JSON="false"

  run error_codes::invalid_uuid "not-a-uuid"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-CONFIG-004"* ]]
  [[ "${output}" == *"not-a-uuid"* ]]
  [[ "${output}" == *"Invalid UUID"* ]]
}

@test "error_codes::invalid_uuid - suggests correct format" {
  export XRF_JSON="false"

  run error_codes::invalid_uuid "invalid"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"8-4-4-4-12"* ]]
  [[ "${output}" == *"hexadecimal"* ]]
}

# ==============================================================================
# error_codes::xray_config_invalid Tests
# ==============================================================================

@test "error_codes::xray_config_invalid - basic usage" {
  export XRF_JSON="false"

  run error_codes::xray_config_invalid "test error output"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-XRAY-001"* ]]
  [[ "${output}" == *"configuration"* ]]
}

# ==============================================================================
# error_codes::missing_dependency Tests
# ==============================================================================

@test "error_codes::missing_dependency - basic usage" {
  export XRF_JSON="false"

  run error_codes::missing_dependency "curl"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-SYSTEM-001"* ]]
  [[ "${output}" == *"curl"* ]]
  [[ "${output}" == *"Missing system dependency"* ]]
}

@test "error_codes::missing_dependency - with purpose" {
  export XRF_JSON="false"

  run error_codes::missing_dependency "jq" "JSON parsing"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"JSON parsing"* ]]
}

# ==============================================================================
# error_codes::plugin_not_found Tests
# ==============================================================================

@test "error_codes::plugin_not_found - basic usage" {
  export XRF_JSON="false"

  run error_codes::plugin_not_found "nonexistent"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"XRF-PLUGIN-001"* ]]
  [[ "${output}" == *"nonexistent"* ]]
  [[ "${output}" == *"Plugin not found"* ]]
}

# ==============================================================================
# Integration Tests
# ==============================================================================

@test "integration - text vs JSON output consistency" {
  # Test same error in both formats
  export XRF_JSON="false"
  run error_codes::invalid_domain "192.168.1.1"
  local text_output="${output}"

  export XRF_JSON="true"
  run error_codes::invalid_domain "192.168.1.1"
  local json_output="${output}"

  # Both should contain domain value
  [[ "${text_output}" == *"192.168.1.1"* ]]
  [[ "${json_output}" == *"192.168.1.1"* ]]

  # JSON should be valid JSON (contains braces)
  [[ "${json_output}" == *"{"* ]]
  [[ "${json_output}" == *"}"* ]]
}

@test "integration - all error codes are unique" {
  # Extract error codes from common error functions
  local codes=()

  # Collect error codes
  export XRF_JSON="true"

  run error_codes::invalid_domain "test"
  codes+=("$(echo "${output}" | grep -o 'XRF-[A-Z]*-[0-9]*' | head -1)")

  run error_codes::invalid_topology "test"
  codes+=("$(echo "${output}" | grep -o 'XRF-[A-Z]*-[0-9]*' | head -1)")

  run error_codes::missing_parameter "test"
  codes+=("$(echo "${output}" | grep -o 'XRF-[A-Z]*-[0-9]*' | head -1)")

  run error_codes::port_conflict "443"
  codes+=("$(echo "${output}" | grep -o 'XRF-[A-Z]*-[0-9]*' | head -1)")

  # Check all codes are unique
  local unique_codes
  unique_codes=$(printf '%s\n' "${codes[@]}" | sort -u | wc -l)
  local total_codes=${#codes[@]}

  [ "${unique_codes}" -eq "${total_codes}" ]
}
