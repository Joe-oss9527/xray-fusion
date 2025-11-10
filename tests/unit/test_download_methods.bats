#!/usr/bin/env bats
# Unit tests for download methods (lib/download.sh)

load ../test_helper

setup() {
  setup_test_env
  # Source download module
  source "${PROJECT_ROOT}/lib/download.sh" 2>/dev/null || true

  # Create test fixtures
  export TEST_REPO_DIR="${TEST_TMPDIR}/test-repo"
  export TEST_DOWNLOAD_DIR="${TEST_TMPDIR}/download"
  mkdir -p "${TEST_REPO_DIR}" "${TEST_DOWNLOAD_DIR}"
}

teardown() {
  cleanup_test_env
}

# Helper: Create a fake tarball for testing
create_fake_tarball() {
  local branch="${1}"
  local dest="${2}"

  # Create a fake repo structure
  local fake_repo="${TEST_TMPDIR}/fake-repo"
  mkdir -p "${fake_repo}/bin"
  echo "#!/bin/bash" > "${fake_repo}/bin/xrf"
  chmod +x "${fake_repo}/bin/xrf"
  echo "test content" > "${fake_repo}/README.md"

  # Create tarball
  cd "${TEST_TMPDIR}"
  tar -czf "${dest}" -C "${TEST_TMPDIR}" --transform "s|^fake-repo|xray-fusion-${branch}|" fake-repo
  cd - >/dev/null
}

# ============================================================================
# download::via_tarball tests
# ============================================================================

@test "download::via_tarball - validates required arguments" {
  # Missing all arguments
  run download::via_tarball
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required arguments" ]]

  # Missing some arguments
  run download::via_tarball "http://test.url"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required arguments" ]]

  run download::via_tarball "http://test.url" "/tmp"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required arguments" ]]
}

@test "download::via_tarball - prefers curl over wget" {
  skip "Requires network mocking"

  # This test would require mocking curl/wget
  # In a real scenario, we'd use a test HTTP server
}

@test "download::via_tarball - fails when no download tool available" {
  # Mock command to simulate missing tools
  command() {
    case "${2:-}" in
      curl|wget) return 1 ;;
      *) builtin command "$@" ;;
    esac
  }
  export -f command

  run download::via_tarball "http://test.url" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "all download attempts failed" ]] || [[ "$output" =~ "download failed" ]]

  unset -f command
}

@test "download::via_tarball - extracts tarball correctly" {
  # Create a fake tarball
  local tarball="${TEST_DOWNLOAD_DIR}/archive.tar.gz"
  create_fake_tarball "main" "${tarball}"

  # Mock curl to use our fake tarball
  curl() {
    if [[ "$*" == *"-o"* ]]; then
      # Find output file (after -o flag)
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-o" ]]; then
          next_is_output=true
        fi
      done
      # Copy our fake tarball to the output location
      cp "${tarball}" "${output_file}"
      return 0
    fi
    return 1
  }
  export -f curl

  # Run the function
  run download::via_tarball "http://test.url/archive.tar.gz" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 0 ]

  # Verify extraction
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]
  [ -x "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/README.md" ]

  # Verify tarball cleanup
  [ ! -f "${TEST_DOWNLOAD_DIR}/archive.tar.gz" ]

  unset -f curl
}

@test "download::via_tarball - cleans up on extraction failure" {
  # Create an invalid tarball
  echo "not a valid tarball" > "${TEST_DOWNLOAD_DIR}/archive.tar.gz"

  # Mock curl to use our invalid tarball
  curl() {
    if [[ "$*" == *"-o"* ]]; then
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-o" ]]; then
          next_is_output=true
        fi
      done
      cp "${TEST_DOWNLOAD_DIR}/archive.tar.gz" "${output_file}"
      return 0
    fi
    return 1
  }
  export -f curl

  run download::via_tarball "http://test.url/archive.tar.gz" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "failed to extract" ]]

  # Verify cleanup
  [ ! -f "${TEST_DOWNLOAD_DIR}/archive.tar.gz" ]

  unset -f curl
}

@test "download::via_tarball - handles curl failure gracefully" {
  # Mock curl to always fail
  curl() {
    return 1
  }
  export -f curl

  run download::via_tarball "http://test.url/archive.tar.gz" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "curl download failed" ]] || [[ "$output" =~ "no download tool" ]]

  unset -f curl
}

@test "download::via_tarball - falls back to wget when curl unavailable" {
  # Create a fake tarball
  local tarball="${TEST_DOWNLOAD_DIR}/test-archive.tar.gz"
  create_fake_tarball "main" "${tarball}"

  # Hide curl by mocking it to fail
  curl() {
    return 127  # Command not found
  }
  export -f curl

  # Mock wget to use our fake tarball
  wget() {
    if [[ "$*" == *"-O"* ]]; then
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-O" ]]; then
          next_is_output=true
        fi
      done
      cp "${tarball}" "${output_file}"
      return 0
    fi
    return 1
  }
  export -f wget

  run download::via_tarball "http://test.url/archive.tar.gz" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 0 ]

  # Verify extraction
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]

  unset -f curl wget
}

# ============================================================================
# download::with_fallback tests
# ============================================================================

@test "download::with_fallback - validates required arguments" {
  run download::with_fallback
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required arguments" ]]

  run download::with_fallback "http://test.url"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required arguments" ]]
}

@test "download::with_fallback - succeeds with git clone" {
  # Create a real git repo
  cd "${TEST_REPO_DIR}"
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false
  mkdir -p bin
  echo "#!/bin/bash" > bin/xrf
  chmod +x bin/xrf
  git add .
  git commit -m "initial" >/dev/null 2>&1
  cd - >/dev/null

  # Test with real git clone
  run download::with_fallback "file://${TEST_REPO_DIR}" "${TEST_DOWNLOAD_DIR}" "master"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git clone successful" ]] || [[ "$output" == "" ]]

  # Verify .git exists (git clone preserves history)
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion/.git" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]
}

@test "download::with_fallback - falls back to tarball when git fails" {
  # Create a fake tarball
  local tarball="${TEST_DOWNLOAD_DIR}/test-archive.tar.gz"
  create_fake_tarball "main" "${tarball}"

  # Mock git to fail
  git() {
    if [[ "$1" == "clone" ]]; then
      return 1
    fi
    builtin command git "$@"
  }
  export -f git

  # Mock curl to use our fake tarball
  curl() {
    if [[ "$*" == *"-o"* ]]; then
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-o" ]]; then
          next_is_output=true
        fi
      done
      cp "${tarball}" "${output_file}"
      return 0
    fi
    return 1
  }
  export -f curl

  run download::with_fallback "https://github.com/test/repo.git" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git clone failed" ]] || [[ "$output" =~ "tarball" ]]

  # Verify download (no .git directory for tarball)
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion" ]
  [ ! -d "${TEST_DOWNLOAD_DIR}/xray-fusion/.git" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]

  unset -f git curl
}

@test "download::with_fallback - fails when all methods fail" {
  # Mock all tools to fail
  git() {
    [[ "$1" == "clone" ]] && return 1
    builtin command git "$@"
  }
  curl() { return 1; }
  wget() { return 1; }
  export -f git curl wget

  run download::with_fallback "https://github.com/test/repo.git" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "all download methods failed" ]] || [[ "$output" =~ "failed" ]]

  unset -f git curl wget
}

@test "download::with_fallback - skips git when not available" {
  # Create a fake tarball
  local tarball="${TEST_DOWNLOAD_DIR}/test-archive.tar.gz"
  create_fake_tarball "main" "${tarball}"

  # Mock command to hide git
  command() {
    case "${2:-}" in
      git) return 1 ;;
      *) builtin command "$@" ;;
    esac
  }
  export -f command

  # Mock curl to use our fake tarball
  curl() {
    if [[ "$*" == *"-o"* ]]; then
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-o" ]]; then
          next_is_output=true
        fi
      done
      cp "${tarball}" "${output_file}"
      return 0
    fi
    return 1
  }
  export -f curl

  run download::with_fallback "https://github.com/test/repo.git" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git not available" ]] || [[ "$output" =~ "skipping git" ]] || [[ "$output" == "" ]]

  # Verify tarball download
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion" ]
  [ ! -d "${TEST_DOWNLOAD_DIR}/xray-fusion/.git" ]

  unset -f command curl
}

# ============================================================================
# Integration tests
# ============================================================================

@test "download methods - complete fallback chain" {
  # Create a fake tarball as last resort
  local tarball="${TEST_DOWNLOAD_DIR}/fallback-archive.tar.gz"
  create_fake_tarball "main" "${tarball}"

  # Track which method was called
  export METHOD_CALLED=""

  # Mock git to fail
  git() {
    if [[ "$1" == "clone" ]]; then
      METHOD_CALLED="${METHOD_CALLED}git,"
      return 1
    fi
    builtin command git "$@"
  }

  # Mock curl to fail
  curl() {
    METHOD_CALLED="${METHOD_CALLED}curl,"
    return 1
  }

  # Mock wget to succeed
  wget() {
    if [[ "$*" == *"-O"* ]]; then
      METHOD_CALLED="${METHOD_CALLED}wget"
      local output_file=""
      local next_is_output=false
      for arg in "$@"; do
        if [[ "${next_is_output}" == "true" ]]; then
          output_file="${arg}"
          break
        fi
        if [[ "${arg}" == "-O" ]]; then
          next_is_output=true
        fi
      done
      cp "${tarball}" "${output_file}"
      return 0
    fi
    return 1
  }

  export -f git curl wget

  run download::with_fallback "https://github.com/test/repo.git" "${TEST_DOWNLOAD_DIR}" "main"
  [ "$status" -eq 0 ]

  # Verify all methods were tried in order
  [[ "${METHOD_CALLED}" == "git,curl,wget" ]] || [[ "${METHOD_CALLED}" == "git,wget" ]]

  # Verify successful download
  [ -d "${TEST_DOWNLOAD_DIR}/xray-fusion" ]
  [ -f "${TEST_DOWNLOAD_DIR}/xray-fusion/bin/xrf" ]

  unset -f git curl wget
  unset METHOD_CALLED
}
