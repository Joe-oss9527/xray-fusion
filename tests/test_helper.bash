#!/usr/bin/env bash

# Test helper functions for xray-fusion
export HERE="${BATS_TEST_DIRNAME}/.."
export PATH="${HERE}/bin:${PATH}"

# Setup test environment
setup_test_env() {
    export XRF_DRY_RUN=true
    export XRF_PREFIX="/tmp/xrf-test"
    export XRF_ETC="/tmp/xrf-test/etc"
    export XRF_VAR="/tmp/xrf-test/var"
    mkdir -p "${XRF_PREFIX}" "${XRF_ETC}" "${XRF_VAR}"
}

# Cleanup test environment  
cleanup_test_env() {
    rm -rf "/tmp/xrf-test" || true
}

# Check if command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Mock successful command
mock_success() {
    return 0
}

# Mock failed command
mock_failure() {
    return 1
}