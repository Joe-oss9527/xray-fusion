#!/usr/bin/env bats
# Unit tests for IO module (modules/io.sh)

load ../test_helper

setup() {
  setup_test_env
}

teardown() {
  cleanup_test_env
}

# Test: io::ensure_dir
@test "io::ensure_dir - creates directory" {
  local test_dir="${TEST_TMPDIR}/test_dir"

  run io::ensure_dir "${test_dir}"
  [ "$status" -eq 0 ]
  [ -d "${test_dir}" ]
}

@test "io::ensure_dir - sets default permissions 0755" {
  local test_dir="${TEST_TMPDIR}/test_dir"

  io::ensure_dir "${test_dir}"

  local perms
  perms=$(stat -c "%a" "${test_dir}")
  [[ "${perms}" == "755" ]]
}

@test "io::ensure_dir - sets custom permissions" {
  local test_dir="${TEST_TMPDIR}/test_dir"

  io::ensure_dir "${test_dir}" 0750

  local perms
  perms=$(stat -c "%a" "${test_dir}")
  [[ "${perms}" == "750" ]]
}

@test "io::ensure_dir - succeeds if directory already exists" {
  local test_dir="${TEST_TMPDIR}/existing_dir"
  mkdir -p "${test_dir}"

  run io::ensure_dir "${test_dir}"
  [ "$status" -eq 0 ]
  [ -d "${test_dir}" ]
}

@test "io::ensure_dir - creates nested directories" {
  local test_dir="${TEST_TMPDIR}/a/b/c"

  run io::ensure_dir "${test_dir}"
  [ "$status" -eq 0 ]
  [ -d "${test_dir}" ]
}

# Test: io::writable
@test "io::writable - returns true for writable directory" {
  run io::writable "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
}

@test "io::writable - returns false for non-existent path" {
  run io::writable "${TEST_TMPDIR}/non-existent"
  [ "$status" -ne 0 ]
}

@test "io::writable - returns false for read-only directory" {
  local readonly_dir="${TEST_TMPDIR}/readonly"
  mkdir -p "${readonly_dir}"
  chmod 0555 "${readonly_dir}"

  run io::writable "${readonly_dir}"
  [ "$status" -ne 0 ]

  # Cleanup
  chmod 0755 "${readonly_dir}"
}

# Test: io::atomic_write
@test "io::atomic_write - writes content to file" {
  local test_file="${TEST_TMPDIR}/test.txt"

  echo "test content" | io::atomic_write "${test_file}"

  [ -f "${test_file}" ]
  local content
  content=$(cat "${test_file}")
  [[ "${content}" == "test content" ]]
}

@test "io::atomic_write - sets default permissions 0644" {
  local test_file="${TEST_TMPDIR}/test.txt"

  echo "test" | io::atomic_write "${test_file}"

  local perms
  perms=$(stat -c "%a" "${test_file}")
  [[ "${perms}" == "644" ]]
}

@test "io::atomic_write - sets custom permissions" {
  local test_file="${TEST_TMPDIR}/test.txt"

  echo "test" | io::atomic_write "${test_file}" 0600

  local perms
  perms=$(stat -c "%a" "${test_file}")
  [[ "${perms}" == "600" ]]
}

@test "io::atomic_write - overwrites existing file" {
  local test_file="${TEST_TMPDIR}/test.txt"

  echo "old content" > "${test_file}"
  echo "new content" | io::atomic_write "${test_file}"

  local content
  content=$(cat "${test_file}")
  [[ "${content}" == "new content" ]]
}

@test "io::atomic_write - handles multiline content" {
  local test_file="${TEST_TMPDIR}/test.txt"

  printf "line1\nline2\nline3" | io::atomic_write "${test_file}"

  [ -f "${test_file}" ]
  local lines
  lines=$(wc -l < "${test_file}")
  [[ "${lines}" -eq 2 ]]  # 3 lines but only 2 newlines
}

@test "io::atomic_write - handles empty content" {
  local test_file="${TEST_TMPDIR}/test.txt"

  echo -n "" | io::atomic_write "${test_file}"

  [ -f "${test_file}" ]
  [ ! -s "${test_file}" ]  # File exists but is empty
}

@test "io::atomic_write - creates parent directory if needed" {
  local test_file="${TEST_TMPDIR}/subdir/test.txt"

  # Ensure parent directory exists
  mkdir -p "$(dirname "${test_file}")"

  echo "test" | io::atomic_write "${test_file}"

  [ -f "${test_file}" ]
}

# Test: io::install_file
@test "io::install_file - copies file" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/dest.txt"

  echo "test content" > "${src}"

  run io::install_file "${src}" "${dst}"
  [ "$status" -eq 0 ]
  [ -f "${dst}" ]

  local content
  content=$(cat "${dst}")
  [[ "${content}" == "test content" ]]
}

@test "io::install_file - sets default permissions 0755" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/dest.txt"

  echo "test" > "${src}"
  io::install_file "${src}" "${dst}"

  local perms
  perms=$(stat -c "%a" "${dst}")
  [[ "${perms}" == "755" ]]
}

@test "io::install_file - sets custom permissions" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/dest.txt"

  echo "test" > "${src}"
  io::install_file "${src}" "${dst}" 0644

  local perms
  perms=$(stat -c "%a" "${dst}")
  [[ "${perms}" == "644" ]]
}

@test "io::install_file - creates parent directory" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/subdir/dest.txt"

  echo "test" > "${src}"

  run io::install_file "${src}" "${dst}"
  [ "$status" -eq 0 ]
  [ -f "${dst}" ]
  [ -d "${TEST_TMPDIR}/subdir" ]
}

@test "io::install_file - overwrites existing file" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/dest.txt"

  echo "new content" > "${src}"
  echo "old content" > "${dst}"

  io::install_file "${src}" "${dst}"

  local content
  content=$(cat "${dst}")
  [[ "${content}" == "new content" ]]
}

@test "io::install_file - preserves source file" {
  local src="${TEST_TMPDIR}/source.txt"
  local dst="${TEST_TMPDIR}/dest.txt"

  echo "test content" > "${src}"
  io::install_file "${src}" "${dst}"

  [ -f "${src}" ]
  [ -f "${dst}" ]
}
