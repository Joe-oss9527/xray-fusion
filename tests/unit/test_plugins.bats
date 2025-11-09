#!/usr/bin/env bats
# Unit tests for plugin system (lib/plugins.sh)

load ../test_helper

setup() {
  setup_test_env

  # Create test plugin directories
  export TEST_PLUGINS_DIR="${TEST_TMPDIR}/plugins"
  export XRF_PLUGINS="${TEST_PLUGINS_DIR}"

  mkdir -p "${TEST_PLUGINS_DIR}/available/test-plugin"
  mkdir -p "${TEST_PLUGINS_DIR}/enabled"
}

teardown() {
  cleanup_test_env
  unset TEST_PLUGINS_DIR XRF_PLUGINS
}

# Test: plugins::base
@test "plugins::base - returns correct base directory" {
  run plugins::base
  [ "$status" -eq 0 ]
  [[ "$output" == "${TEST_PLUGINS_DIR}" ]]
}

# Test: plugins::dir_available
@test "plugins::dir_available - returns available directory" {
  run plugins::dir_available
  [ "$status" -eq 0 ]
  [[ "$output" == "${TEST_PLUGINS_DIR}/available" ]]
}

# Test: plugins::dir_enabled
@test "plugins::dir_enabled - returns enabled directory" {
  run plugins::dir_enabled
  [ "$status" -eq 0 ]
  [[ "$output" == "${TEST_PLUGINS_DIR}/enabled" ]]
}

# Test: plugins::ensure_dirs
@test "plugins::ensure_dirs - creates directories" {
  rm -rf "${TEST_PLUGINS_DIR}/available" "${TEST_PLUGINS_DIR}/enabled"

  run plugins::ensure_dirs
  [ "$status" -eq 0 ]
  [ -d "${TEST_PLUGINS_DIR}/available" ]
  [ -d "${TEST_PLUGINS_DIR}/enabled" ]
}

# Test: plugins::validate_id
@test "plugins::validate_id - accepts valid ID" {
  run plugins::validate_id "test-plugin"
  [ "$status" -eq 0 ]
}

@test "plugins::validate_id - accepts ID with underscores" {
  run plugins::validate_id "test_plugin"
  [ "$status" -eq 0 ]
}

@test "plugins::validate_id - accepts alphanumeric ID" {
  run plugins::validate_id "plugin123"
  [ "$status" -eq 0 ]
}

@test "plugins::validate_id - rejects path traversal with .." {
  run plugins::validate_id "../malicious"
  [ "$status" -ne 0 ]
  [[ "$output" == *"path traversal"* ]]
}

@test "plugins::validate_id - rejects ID with slash" {
  run plugins::validate_id "test/plugin"
  [ "$status" -ne 0 ]
}

@test "plugins::validate_id - rejects special characters" {
  run plugins::validate_id "test@plugin"
  [ "$status" -ne 0 ]
}

@test "plugins::validate_id - rejects spaces" {
  run plugins::validate_id "test plugin"
  [ "$status" -ne 0 ]
}

# Test: plugins::enable
@test "plugins::enable - enables valid plugin" {
  # Create a test plugin
  cat > "${TEST_PLUGINS_DIR}/available/test-plugin/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="test-plugin"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Test plugin"
XRF_PLUGIN_HOOKS=()
EOF

  run plugins::enable "test-plugin"
  [ "$status" -eq 0 ]
  [ -L "${TEST_PLUGINS_DIR}/enabled/test-plugin.sh" ]
}

@test "plugins::enable - fails for non-existent plugin" {
  run plugins::enable "non-existent"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "plugins::enable - rejects invalid plugin ID" {
  run plugins::enable "../malicious"
  [ "$status" -eq 2 ]
}

# Test: plugins::disable
@test "plugins::disable - disables enabled plugin" {
  # Create and enable a plugin
  cat > "${TEST_PLUGINS_DIR}/available/test-plugin/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="test-plugin"
XRF_PLUGIN_VERSION="1.0.0"
EOF

  plugins::enable "test-plugin" >/dev/null

  run plugins::disable "test-plugin"
  [ "$status" -eq 0 ]
  [ ! -e "${TEST_PLUGINS_DIR}/enabled/test-plugin.sh" ]
}

@test "plugins::disable - fails for non-enabled plugin" {
  run plugins::disable "not-enabled"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not enabled"* ]]
}

@test "plugins::disable - rejects invalid plugin ID" {
  run plugins::disable "../malicious"
  [ "$status" -eq 2 ]
}

# Test: plugins::load_enabled
@test "plugins::load_enabled - loads valid plugin" {
  # Create a valid plugin
  cat > "${TEST_PLUGINS_DIR}/available/valid-plugin/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="valid-plugin"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_DESC="Valid test plugin"
XRF_PLUGIN_HOOKS=(configure_pre configure_post)
EOF

  plugins::enable "valid-plugin" >/dev/null

  run plugins::load_enabled
  [ "$status" -eq 0 ]

  # Check that plugin was loaded
  [[ "${__PLUG_IDS[*]}" == *"valid-plugin"* ]]
}

@test "plugins::load_enabled - skips plugin without XRF_PLUGIN_ID" {
  # Create an invalid plugin (missing ID)
  cat > "${TEST_PLUGINS_DIR}/available/invalid-plugin/plugin.sh" << 'EOF'
XRF_PLUGIN_VERSION="1.0.0"
# Missing XRF_PLUGIN_ID
EOF

  plugins::enable "invalid-plugin" >/dev/null

  run plugins::load_enabled
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing XRF_PLUGIN_ID"* ]]
}

# Test: plugins::fn_prefix
@test "plugins::fn_prefix - converts hyphens to underscores" {
  run plugins::fn_prefix "test-plugin"
  [ "$status" -eq 0 ]
  [[ "$output" == "test_plugin" ]]
}

@test "plugins::fn_prefix - preserves underscores" {
  run plugins::fn_prefix "test_plugin"
  [ "$status" -eq 0 ]
  [[ "$output" == "test_plugin" ]]
}

# Test: plugins::emit
@test "plugins::emit - calls plugin hook function" {
  # Create a plugin with a hook
  cat > "${TEST_PLUGINS_DIR}/available/hook-test/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="hook-test"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_HOOKS=(test_event)

hook_test::test_event() {
  echo "hook called with args: $*"
}
EOF

  plugins::enable "hook-test" >/dev/null
  plugins::load_enabled >/dev/null

  run plugins::emit "test_event" "arg1" "arg2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hook called with args: arg1 arg2"* ]]
}

@test "plugins::emit - skips plugins without matching hook" {
  # Create a plugin without the hook
  cat > "${TEST_PLUGINS_DIR}/available/no-hook/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="no-hook"
XRF_PLUGIN_VERSION="1.0.0"
XRF_PLUGIN_HOOKS=(other_event)

no_hook::other_event() {
  echo "should not be called"
}
EOF

  plugins::enable "no-hook" >/dev/null
  plugins::load_enabled >/dev/null

  run plugins::emit "test_event"
  [ "$status" -eq 0 ]
  [[ "$output" != *"should not be called"* ]]
}

# Test: plugins::info
@test "plugins::info - displays plugin information" {
  # Create a test plugin
  cat > "${TEST_PLUGINS_DIR}/available/info-test/plugin.sh" << 'EOF'
XRF_PLUGIN_ID="info-test"
XRF_PLUGIN_VERSION="2.0.0"
XRF_PLUGIN_DESC="Test plugin for info"
XRF_PLUGIN_HOOKS=(hook1 hook2)
EOF

  run plugins::info "info-test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id: info-test"* ]]
  [[ "$output" == *"version: 2.0.0"* ]]
  [[ "$output" == *"desc: Test plugin for info"* ]]
  [[ "$output" == *"hooks: hook1 hook2"* ]]
}

@test "plugins::info - fails for non-existent plugin" {
  run plugins::info "non-existent"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "plugins::info - rejects invalid plugin ID" {
  run plugins::info "../malicious"
  [ "$status" -eq 2 ]
}
