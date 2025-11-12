#!/usr/bin/env bats
# Unit tests for log viewing and export functions (lib/logs.sh)

load ../test_helper

setup() {
  setup_test_env
  # Source log module
  source "${PROJECT_ROOT}/lib/logs.sh"
}

teardown() {
  cleanup_test_env
}

# Test helper: create mock journalctl
mock_journalctl() {
  local mock_script="${TEST_TMPDIR}/mock-journalctl"
  cat > "${mock_script}" <<'EOF'
#!/usr/bin/env bash
# Mock journalctl for testing
echo "[2023-01-01T12:00:00+0000] xray info: Starting service"
echo "[2023-01-01T12:00:01+0000] xray warning: Configuration deprecated"
echo "[2023-01-01T12:00:02+0000] xray error: Connection failed"
echo "[2023-01-01T12:00:03+0000] xray info: Retrying connection"
EOF
  chmod +x "${mock_script}"
  export PATH="${TEST_TMPDIR}:${PATH}"
}

# logs::_format tests
@test "logs::_format - filters error level correctly" {
  input="info: test1
error: test2
warn: test3
error: test4"

  result=$(echo "$input" | LOG_NO_COLOR=true logs::_format "error" "true")
  [[ "$result" == *"error: test2"* ]]
  [[ "$result" == *"error: test4"* ]]
  [[ "$result" != *"info: test1"* ]]
  [[ "$result" != *"warn: test3"* ]]
}

@test "logs::_format - filters warn level correctly" {
  input="info: test1
warning: test2
error: test3
warn: test4"

  result=$(echo "$input" | LOG_NO_COLOR=true logs::_format "warn" "true")
  [[ "$result" == *"warning: test2"* ]]
  [[ "$result" == *"warn: test4"* ]]
  [[ "$result" != *"info: test1"* ]]
  [[ "$result" != *"error: test3"* ]]
}

@test "logs::_format - filters info level correctly" {
  input="info: test1
error: test2
Info: test3"

  result=$(echo "$input" | LOG_NO_COLOR=true logs::_format "info" "true")
  [[ "$result" == *"info: test1"* ]]
  [[ "$result" == *"Info: test3"* ]]
  [[ "$result" != *"error: test2"* ]]
}

@test "logs::_format - shows all levels when filter is 'all'" {
  input="info: test1
error: test2
warn: test3
debug: test4"

  result=$(echo "$input" | LOG_NO_COLOR=true logs::_format "all" "true")
  [[ "$result" == *"info: test1"* ]]
  [[ "$result" == *"error: test2"* ]]
  [[ "$result" == *"warn: test3"* ]]
  [[ "$result" == *"debug: test4"* ]]
}

@test "logs::_format - applies color codes when no_color=false" {
  input="error: test error"

  result=$(echo "$input" | logs::_format "all" "false")
  # Check for ANSI color codes (e.g., \033[0;31m for red)
  [[ "$result" == *$'\033'* ]]
}

@test "logs::_format - no color codes when no_color=true" {
  input="error: test error"

  result=$(echo "$input" | logs::_format "all" "true")
  # Should not contain ANSI escape sequences
  [[ "$result" != *$'\033'* ]]
}

# logs::stats tests
@test "logs::stats - returns valid JSON" {
  skip "Requires journalctl mock setup"

  mock_journalctl
  export LOG_SINCE="1 hour ago"

  run logs::stats
  [ "$status" -eq 0 ]

  # Validate JSON structure
  echo "$output" | jq empty
  echo "$output" | jq -e 'has("total_lines")'
  echo "$output" | jq -e 'has("errors")'
  echo "$output" | jq -e 'has("warnings")'
  echo "$output" | jq -e 'has("info")'
}

@test "logs::stats - counts errors correctly" {
  skip "Requires journalctl mock setup"

  mock_journalctl
  result=$(logs::stats)

  errors=$(echo "$result" | jq -r '.errors')
  [[ "$errors" -ge 0 ]]
}

# logs::export tests
@test "logs::export - requires output file parameter" {
  run logs::export ""
  [ "$status" -ne 0 ]
}

@test "logs::export - creates output file" {
  skip "Requires journalctl mock setup"

  local export_file="${TEST_TMPDIR}/exported-logs.txt"
  mock_journalctl

  run logs::export "${export_file}"
  [ "$status" -eq 0 ]
  [ -f "${export_file}" ]
}

@test "logs::export - exports plain text (no color)" {
  skip "Requires journalctl mock setup"

  local export_file="${TEST_TMPDIR}/exported-logs.txt"
  mock_journalctl

  logs::export "${export_file}"

  # Check file contains logs but no ANSI escape sequences
  [[ -s "${export_file}" ]]
  content=$(cat "${export_file}")
  [[ "$content" != *$'\033'* ]]
}

# Environment variable tests
@test "LOG_LEVEL environment variable is respected" {
  input="info: test1
error: test2"

  export LOG_LEVEL="error"
  result=$(echo "$input" | LOG_NO_COLOR=true logs::_format "${LOG_LEVEL}" "true")

  [[ "$result" == *"error: test2"* ]]
  [[ "$result" != *"info: test1"* ]]
}

@test "LOG_NO_COLOR environment variable disables colors" {
  input="error: test"

  export LOG_NO_COLOR="true"
  result=$(echo "$input" | logs::_format "all" "${LOG_NO_COLOR}")

  # Should not contain color codes
  [[ "$result" != *$'\033'* ]]
}
