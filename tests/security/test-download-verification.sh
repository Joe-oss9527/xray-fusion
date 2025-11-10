#!/usr/bin/env bash
# Test download verification logic (security test)
# This test verifies that verification happens BEFORE sourcing downloaded code

set -euo pipefail

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_DIR}"' EXIT

log_info() { echo "[INFO] ${*}"; }
log_error() { echo "[ERROR] ${*}" >&2; }
error_exit() { log_error "${*}"; exit 1; }

# Test 1: Verify that install.sh does NOT source lib/download.sh before verification
log_info "Test 1: Checking source order in install.sh"

# Search for source statements that reference downloaded code
if grep -n "source.*xray-fusion/lib/core\.sh" install.sh 2>/dev/null; then
  log_error "FAIL: install.sh sources lib/core.sh from downloaded code"
  exit 1
fi

if grep -n "source.*xray-fusion/lib/download\.sh" install.sh 2>/dev/null; then
  log_error "FAIL: install.sh sources lib/download.sh from downloaded code"
  exit 1
fi

log_info "✓ install.sh does NOT source downloaded code before verification"

# Test 2: Verify that verification happens before copying files
log_info "Test 2: Checking verification order"

# Extract line numbers
download_line=$(grep -n "Download with automatic fallback" install.sh | head -1 | cut -d: -f1)
verify_line=$(grep -n "Verify download integrity BEFORE sourcing" install.sh | head -1 | cut -d: -f1)
copy_line=$(grep -n 'cp -r.*TMP_DIR.*xray-fusion.*INSTALL_DIR' install.sh | head -1 | cut -d: -f1)

if [[ -z "${download_line}" || -z "${verify_line}" || -z "${copy_line}" ]]; then
  log_error "FAIL: Could not find key sections in install.sh"
  exit 1
fi

log_info "  Download starts at line: ${download_line}"
log_info "  Verification at line: ${verify_line}"
log_info "  Copy files at line: ${copy_line}"

if [[ ${verify_line} -lt ${download_line} ]]; then
  log_error "FAIL: Verification happens before download"
  exit 1
fi

if [[ ${copy_line} -lt ${verify_line} ]]; then
  log_error "FAIL: Files copied before verification"
  exit 1
fi

log_info "✓ Verification order is correct: download → verify → copy"

# Test 3: Verify that verification uses only system tools
log_info "Test 3: Checking verification implementation"

# Extract verification section
sed -n '/Verify download integrity BEFORE sourcing/,/END: Verification/p' install.sh > "${TEST_DIR}/verification.sh"

# Check that it uses only system commands (source, eval, or ". script")
if grep -E "^\s*(source|\\.\s+|eval)\s+" "${TEST_DIR}/verification.sh" | grep -v "^#" >/dev/null; then
  log_error "FAIL: Verification uses dangerous commands (source/./eval)"
  grep -E "^\s*(source|\\.\s+|eval)\s+" "${TEST_DIR}/verification.sh" | grep -v "^#"
  exit 1
fi

# Verify it uses system git/gpg
if ! grep -q "git -C" "${TEST_DIR}/verification.sh"; then
  log_error "FAIL: Verification does not use git"
  exit 1
fi

log_info "✓ Verification uses only safe system commands"

# Test 4: Verify error handling
log_info "Test 4: Checking error handling"

if ! grep -q "error_exit.*Integrity verification failed" install.sh; then
  log_error "FAIL: No error_exit for verification failure"
  exit 1
fi

log_info "✓ Error handling is correct"

log_info ""
log_info "======================================"
log_info "All security tests passed!"
log_info "======================================"
log_info "Summary:"
log_info "  ✓ No downloaded code sourced before verification"
log_info "  ✓ Verification happens after download, before installation"
log_info "  ✓ Verification uses only system tools (git, gpg)"
log_info "  ✓ Verification failures trigger error_exit"
