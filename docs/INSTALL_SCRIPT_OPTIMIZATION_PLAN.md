# Install Script Optimization Plan (TDD)

> 基于 Claude 官方安装脚本最佳实践的多阶段优化计划
>
> **方法论**: Test-Driven Development (TDD)
> **参考**: https://storage.googleapis.com/.../bootstrap.sh

## 总览

```
Phase 1 (P0) → Phase 2 (P1) → Phase 3 (P1) → Phase 4 (P1) → Phase 5 (P2)
   ↓              ↓              ↓              ↓              ↓
安全验证      下载回退       网络重试       依赖前置       进度优化
(2-3天)       (2-3天)       (1-2天)       (1天)         (1天)
```

**总工期**: 7-10 天
**测试覆盖率目标**: 85%+

---

## Phase 1: 下载完整性验证 (P0 - 安全关键)

**目标**: 防止中间人攻击和损坏的下载文件

### 1.1 TDD Cycle 1: Git Commit 验证

#### 红灯 (Red) - 编写失败的测试
```bash
# tests/unit/test_download_verification.bats

@test "download::verify_commit - detects valid commit hash" {
  # Setup mock git repo
  local tmpdir="$(mktemp -d)"
  git -C "${tmpdir}" init
  git -C "${tmpdir}" commit --allow-empty -m "test"
  local commit="$(git -C "${tmpdir}" rev-parse HEAD)"

  # Test
  run download::verify_commit "${tmpdir}" "${commit}"
  assert_success

  rm -rf "${tmpdir}"
}

@test "download::verify_commit - rejects invalid commit hash" {
  local tmpdir="$(mktemp -d)"
  git -C "${tmpdir}" init
  git -C "${tmpdir}" commit --allow-empty -m "test"

  # Test with wrong hash
  run download::verify_commit "${tmpdir}" "0000000000000000000000000000000000000000"
  assert_failure
  assert_output --partial "commit hash mismatch"

  rm -rf "${tmpdir}"
}

@test "download::verify_commit - handles missing git repo" {
  local tmpdir="$(mktemp -d)"

  run download::verify_commit "${tmpdir}" "any-hash"
  assert_failure
  assert_output --partial "not a git repository"

  rm -rf "${tmpdir}"
}
```

#### 绿灯 (Green) - 最小实现
```bash
# lib/download.sh

##
# Verify git commit hash matches expected value
#
# Arguments:
#   $1 - Repository path (string, required)
#   $2 - Expected commit hash (string, required)
#
# Returns:
#   0 - Commit hash matches
#   1 - Hash mismatch or verification error
##
download::verify_commit() {
  local repo_path="${1}"
  local expected_hash="${2}"

  # Validate inputs
  [[ -n "${repo_path}" && -n "${expected_hash}" ]] || {
    core::log error "missing required arguments" '{"function":"verify_commit"}'
    return 1
  }

  # Check if git repo exists
  if [[ ! -d "${repo_path}/.git" ]]; then
    core::log error "not a git repository" "$(printf '{"path":"%s"}' "${repo_path}")"
    return 1
  fi

  # Get actual commit hash
  local actual_hash
  actual_hash="$(git -C "${repo_path}" rev-parse HEAD 2>/dev/null)" || {
    core::log error "failed to get commit hash" "$(printf '{"path":"%s"}' "${repo_path}")"
    return 1
  }

  # Compare hashes
  if [[ "${actual_hash}" != "${expected_hash}" ]]; then
    core::log error "commit hash mismatch" "$(printf '{"expected":"%s","actual":"%s"}' "${expected_hash}" "${actual_hash}")"
    return 1
  fi

  core::log debug "commit hash verified" "$(printf '{"hash":"%s"}' "${actual_hash}")"
  return 0
}
```

#### 重构 (Refactor)
- 提取哈希验证逻辑到单独函数
- 添加详细的错误上下文
- 统一日志格式

### 1.2 TDD Cycle 2: GPG 签名验证（可选）

#### 红灯 (Red)
```bash
# tests/unit/test_download_verification.bats

@test "download::verify_gpg_signature - accepts signed commit" {
  skip "需要 GPG 密钥环配置"

  local tmpdir="$(mktemp -d)"
  # Setup signed commit
  git -C "${tmpdir}" init
  git -C "${tmpdir}" config user.signingkey "test-key"
  git -C "${tmpdir}" commit --allow-empty -S -m "signed"

  run download::verify_gpg_signature "${tmpdir}"
  assert_success

  rm -rf "${tmpdir}"
}

@test "download::verify_gpg_signature - rejects unsigned commit" {
  local tmpdir="$(mktemp -d)"
  git -C "${tmpdir}" init
  git -C "${tmpdir}" commit --allow-empty -m "unsigned"

  run download::verify_gpg_signature "${tmpdir}"
  assert_failure

  rm -rf "${tmpdir}"
}

@test "download::verify_gpg_signature - handles missing gpg" {
  # Mock command -v gpg to fail
  function command() { return 1; }
  export -f command

  run download::verify_gpg_signature "/tmp/repo"
  assert_failure
  assert_output --partial "gpg not available"

  unset -f command
}
```

#### 绿灯 (Green)
```bash
# lib/download.sh

##
# Verify GPG signature of latest commit (optional)
#
# Arguments:
#   $1 - Repository path (string, required)
#
# Returns:
#   0 - Signature valid or GPG not available (graceful degradation)
#   1 - Signature invalid or verification error
##
download::verify_gpg_signature() {
  local repo_path="${1}"

  # Check if GPG is available
  if ! command -v gpg >/dev/null 2>&1; then
    core::log warn "gpg not available, skipping signature verification" '{}'
    return 0  # Graceful degradation
  fi

  # Check if git repo exists
  if [[ ! -d "${repo_path}/.git" ]]; then
    core::log error "not a git repository" "$(printf '{"path":"%s"}' "${repo_path}")"
    return 1
  fi

  # Verify commit signature
  if git -C "${repo_path}" verify-commit HEAD 2>/dev/null; then
    core::log info "GPG signature verified" '{}'
    return 0
  else
    core::log warn "GPG signature verification failed or commit not signed" '{}'
    return 0  # Don't fail on unsigned commits (optional verification)
  fi
}
```

### 1.3 集成到 install.sh

#### 红灯 (Red) - 集成测试
```bash
# tests/integration/test_install_download.bats

@test "install.sh - verifies downloaded repo integrity" {
  # Mock download with valid commit
  export XRF_REPO_URL="https://github.com/Joe-oss9527/xray-fusion.git"
  export XRF_BRANCH="main"
  export XRF_EXPECTED_COMMIT="$(curl -s https://api.github.com/repos/Joe-oss9527/xray-fusion/commits/main | jq -r .sha)"

  run bash install.sh --help  # Dry run to test download
  assert_success
}

@test "install.sh - rejects tampered downloads" {
  # Mock download with wrong commit
  export XRF_EXPECTED_COMMIT="0000000000000000000000000000000000000000"

  run bash install.sh --topology reality-only
  assert_failure
  assert_output --partial "commit hash mismatch"
}
```

#### 绿灯 (Green) - 修改 install.sh
```bash
# install.sh (修改 download_project 函数)

download_project() {
  log_info "从 ${REPO_URL} 下载 xray-fusion (分支: ${BRANCH})..."

  TMP_DIR="$(mktemp -d)"
  log_debug "使用临时目录: ${TMP_DIR}"

  # Set proxy if specified
  if [[ -n "${PROXY}" ]]; then
    export https_proxy="${PROXY}"
    export http_proxy="${PROXY}"
    log_info "使用代理: ${PROXY}"
  fi

  # Clone repository
  log_debug "开始克隆仓库..."
  if ! git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMP_DIR}/xray-fusion" 2>/dev/null; then
    log_error "从 ${REPO_URL} 下载失败"
    log_info "请检查网络连接或尝试使用代理"
    error_exit "下载失败"
  fi

  # === NEW: Verify download integrity ===

  # 1. Get actual commit hash
  local actual_commit
  actual_commit=$(git -C "${TMP_DIR}/xray-fusion" rev-parse HEAD 2>/dev/null)
  log_debug "下载的 commit: ${actual_commit}"

  # 2. Verify against expected commit (if provided)
  if [[ -n "${XRF_EXPECTED_COMMIT:-}" ]]; then
    if [[ "${actual_commit}" != "${XRF_EXPECTED_COMMIT}" ]]; then
      log_error "下载完整性验证失败：commit hash 不匹配"
      log_error "期望: ${XRF_EXPECTED_COMMIT}"
      log_error "实际: ${actual_commit}"
      error_exit "完整性验证失败"
    fi
    log_info "✓ Commit 验证通过"
  else
    log_debug "跳过 commit 验证（未指定 XRF_EXPECTED_COMMIT）"
  fi

  # 3. Verify GPG signature (optional)
  if command -v gpg >/dev/null 2>&1; then
    if git -C "${TMP_DIR}/xray-fusion" verify-commit HEAD 2>/dev/null; then
      log_info "✓ GPG 签名验证通过"
    else
      log_warn "GPG 签名验证失败或 commit 未签名"
    fi
  fi

  # === END: Verification ===

  # Verify download completeness
  if [[ ! -d "${TMP_DIR}/xray-fusion" ]] || [[ ! -f "${TMP_DIR}/xray-fusion/bin/xrf" ]]; then
    error_exit "下载的文件不完整或损坏"
  fi

  log_info "下载完成"
}
```

### 1.4 验收标准
- [ ] 所有单元测试通过 (`make test-unit`)
- [ ] 集成测试验证完整流程
- [ ] 错误场景覆盖：无效 hash、GPG 失败、网络错误
- [ ] 文档更新：README 说明 `XRF_EXPECTED_COMMIT` 环境变量

---

## Phase 2: 多种下载方式回退 (P1 - 可靠性)

**目标**: 支持 git clone → tarball(curl) → tarball(wget) 回退

### 2.1 TDD Cycle 1: Tarball 下载

#### 红灯 (Red)
```bash
# tests/unit/test_download_methods.bats

@test "download::via_tarball - downloads and extracts successfully" {
  local tmpdir="$(mktemp -d)"
  local url="https://github.com/Joe-oss9527/xray-fusion/archive/refs/heads/main.tar.gz"

  run download::via_tarball "${url}" "${tmpdir}" "main"
  assert_success
  assert [ -d "${tmpdir}/xray-fusion" ]
  assert [ -f "${tmpdir}/xray-fusion/bin/xrf" ]

  rm -rf "${tmpdir}"
}

@test "download::via_tarball - handles invalid URL" {
  local tmpdir="$(mktemp -d)"
  local url="https://invalid.url/archive.tar.gz"

  run download::via_tarball "${url}" "${tmpdir}" "main"
  assert_failure

  rm -rf "${tmpdir}"
}

@test "download::via_tarball - prefers curl over wget" {
  # Mock commands
  function curl() { echo "curl called"; return 0; }
  function wget() { echo "wget called"; return 0; }
  export -f curl wget

  local tmpdir="$(mktemp -d)"
  run download::via_tarball "http://test.url" "${tmpdir}" "main"
  assert_output --partial "curl called"

  unset -f curl wget
  rm -rf "${tmpdir}"
}
```

#### 绿灯 (Green)
```bash
# lib/download.sh

##
# Download repository as tarball and extract
#
# Arguments:
#   $1 - Tarball URL (string, required)
#   $2 - Destination directory (string, required)
#   $3 - Branch name (string, required)
#
# Returns:
#   0 - Download and extraction successful
#   1 - Download or extraction failed
##
download::via_tarball() {
  local url="${1}"
  local dest_dir="${2}"
  local branch="${3}"

  local tarball="${dest_dir}/archive.tar.gz"

  # Try curl first
  if command -v curl >/dev/null 2>&1; then
    core::log debug "attempting download via curl" "$(printf '{"url":"%s"}' "${url}")"
    if curl -fsSL --connect-timeout 10 --max-time 300 "${url}" -o "${tarball}" 2>/dev/null; then
      core::log debug "download successful via curl" '{}'
    else
      core::log warn "curl download failed" '{}'
      rm -f "${tarball}"
      return 1
    fi
  # Fallback to wget
  elif command -v wget >/dev/null 2>&1; then
    core::log debug "attempting download via wget" "$(printf '{"url":"%s"}' "${url}")"
    if wget -q --timeout=10 "${url}" -O "${tarball}" 2>/dev/null; then
      core::log debug "download successful via wget" '{}'
    else
      core::log warn "wget download failed" '{}'
      rm -f "${tarball}"
      return 1
    fi
  else
    core::log error "no download tool available (curl/wget)" '{}'
    return 1
  fi

  # Extract tarball
  core::log debug "extracting tarball" '{}'
  if ! tar -xzf "${tarball}" -C "${dest_dir}" 2>/dev/null; then
    core::log error "failed to extract tarball" '{}'
    rm -f "${tarball}"
    return 1
  fi

  # Rename extracted directory
  local extracted_dir="${dest_dir}/xray-fusion-${branch}"
  if [[ -d "${extracted_dir}" ]]; then
    mv "${extracted_dir}" "${dest_dir}/xray-fusion"
  else
    core::log error "extracted directory not found" "$(printf '{"expected":"%s"}' "${extracted_dir}")"
    return 1
  fi

  # Cleanup tarball
  rm -f "${tarball}"

  core::log debug "tarball download complete" '{}'
  return 0
}
```

### 2.2 TDD Cycle 2: 多方法回退逻辑

#### 红灯 (Red)
```bash
# tests/unit/test_download_methods.bats

@test "download::with_fallback - tries all methods in order" {
  local tmpdir="$(mktemp -d)"
  local repo_url="https://github.com/Joe-oss9527/xray-fusion.git"
  local branch="main"

  # Mock git to fail, tarball to succeed
  function git() { return 1; }
  export -f git

  run download::with_fallback "${repo_url}" "${tmpdir}" "${branch}"
  assert_success
  assert_output --partial "git clone failed, trying tarball"

  unset -f git
  rm -rf "${tmpdir}"
}

@test "download::with_fallback - succeeds with git clone" {
  local tmpdir="$(mktemp -d)"
  local repo_url="https://github.com/Joe-oss9527/xray-fusion.git"
  local branch="main"

  run download::with_fallback "${repo_url}" "${tmpdir}" "${branch}"
  assert_success
  assert [ -d "${tmpdir}/xray-fusion/.git" ]  # Git repo preserved

  rm -rf "${tmpdir}"
}

@test "download::with_fallback - fails when all methods fail" {
  local tmpdir="$(mktemp -d)"

  # Mock all tools to fail
  function git() { return 1; }
  function curl() { return 1; }
  function wget() { return 1; }
  export -f git curl wget

  run download::with_fallback "http://invalid.url" "${tmpdir}" "main"
  assert_failure
  assert_output --partial "all download methods failed"

  unset -f git curl wget
  rm -rf "${tmpdir}"
}
```

#### 绿灯 (Green)
```bash
# lib/download.sh

##
# Download repository with automatic fallback
#
# Tries methods in order:
#   1. git clone (preserves .git history)
#   2. tarball via curl
#   3. tarball via wget
#
# Arguments:
#   $1 - Repository URL (string, required)
#   $2 - Destination directory (string, required)
#   $3 - Branch name (string, required)
#
# Returns:
#   0 - Download successful
#   1 - All download methods failed
##
download::with_fallback() {
  local repo_url="${1}"
  local dest_dir="${2}"
  local branch="${3}"

  # Method 1: Git clone (preferred)
  if command -v git >/dev/null 2>&1; then
    core::log debug "attempting git clone" "$(printf '{"url":"%s","branch":"%s"}' "${repo_url}" "${branch}")"
    if git clone --depth 1 --branch "${branch}" "${repo_url}" "${dest_dir}/xray-fusion" 2>/dev/null; then
      core::log info "git clone successful" '{}'
      return 0
    else
      core::log warn "git clone failed, trying tarball fallback" '{}'
    fi
  else
    core::log debug "git not available, skipping git clone" '{}'
  fi

  # Method 2 & 3: Tarball download (curl/wget)
  local tarball_url="${repo_url%.git}/archive/refs/heads/${branch}.tar.gz"
  core::log debug "attempting tarball download" "$(printf '{"url":"%s"}' "${tarball_url}")"

  if download::via_tarball "${tarball_url}" "${dest_dir}" "${branch}"; then
    core::log info "tarball download successful" '{}'
    return 0
  else
    core::log error "all download methods failed" '{}'
    return 1
  fi
}
```

### 2.3 集成到 install.sh

```bash
# install.sh (替换 download_project 函数)

download_project() {
  log_info "从 ${REPO_URL} 下载 xray-fusion (分支: ${BRANCH})..."

  TMP_DIR="$(mktemp -d)"
  log_debug "使用临时目录: ${TMP_DIR}"

  # Set proxy if specified
  if [[ -n "${PROXY}" ]]; then
    export https_proxy="${PROXY}"
    export http_proxy="${PROXY}"
    log_info "使用代理: ${PROXY}"
  fi

  # Source download module
  if [[ -f "${HERE:-/usr/local/xray-fusion}/lib/download.sh" ]]; then
    source "${HERE:-/usr/local/xray-fusion}/lib/download.sh"

    # Use fallback download method
    if ! download::with_fallback "${REPO_URL}" "${TMP_DIR}" "${BRANCH}"; then
      error_exit "下载失败（已尝试所有方法）"
    fi
  else
    # Legacy fallback: direct git clone
    log_debug "开始克隆仓库（旧方法）..."
    if ! git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMP_DIR}/xray-fusion" 2>/dev/null; then
      log_error "从 ${REPO_URL} 下载失败"
      log_info "请检查网络连接或尝试使用代理"
      error_exit "下载失败"
    fi
  fi

  # Verify download integrity (from Phase 1)
  local actual_commit
  if [[ -d "${TMP_DIR}/xray-fusion/.git" ]]; then
    actual_commit=$(git -C "${TMP_DIR}/xray-fusion" rev-parse HEAD 2>/dev/null)
    log_debug "下载的 commit: ${actual_commit}"

    if [[ -n "${XRF_EXPECTED_COMMIT:-}" && "${actual_commit}" != "${XRF_EXPECTED_COMMIT}" ]]; then
      log_error "下载完整性验证失败：commit hash 不匹配"
      error_exit "完整性验证失败"
    fi
  else
    log_debug "跳过 commit 验证（tarball 下载无 .git）"
  fi

  # Verify download completeness
  if [[ ! -d "${TMP_DIR}/xray-fusion" ]] || [[ ! -f "${TMP_DIR}/xray-fusion/bin/xrf" ]]; then
    error_exit "下载的文件不完整或损坏"
  fi

  log_info "下载完成"
}
```

### 2.4 验收标准
- [ ] 单元测试覆盖所有下载方法
- [ ] 集成测试验证回退逻辑
- [ ] 手动测试：禁用 git/curl/wget 各种组合
- [ ] 文档更新：说明回退机制

---

## Phase 3: 网络重试机制 (P1 - 可靠性)

**目标**: 实现指数退避重试，提高网络不稳定环境下的成功率

### 3.1 TDD Cycle 1: 通用重试函数

#### 红灯 (Red)
```bash
# tests/unit/test_network_retry.bats

@test "network::retry - succeeds on first try" {
  function test_command() { echo "success"; return 0; }
  export -f test_command

  run network::retry 3 2 test_command
  assert_success
  assert_output "success"

  unset -f test_command
}

@test "network::retry - succeeds after 2 failures" {
  # Mock command that fails twice then succeeds
  function flaky_command() {
    local state_file="/tmp/retry_test_$$"
    local count=0
    [[ -f "${state_file}" ]] && count=$(cat "${state_file}")
    count=$((count + 1))
    echo "${count}" > "${state_file}"

    if [[ ${count} -lt 3 ]]; then
      echo "attempt ${count} failed" >&2
      return 1
    else
      echo "attempt ${count} succeeded"
      rm -f "${state_file}"
      return 0
    fi
  }
  export -f flaky_command

  run network::retry 5 1 flaky_command
  assert_success
  assert_output --partial "attempt 3 succeeded"

  unset -f flaky_command
}

@test "network::retry - fails after max retries" {
  function failing_command() { return 1; }
  export -f failing_command

  run network::retry 3 1 failing_command
  assert_failure

  unset -f failing_command
}

@test "network::retry - implements exponential backoff" {
  function slow_command() { sleep 0.1; return 1; }
  export -f slow_command

  local start=$(date +%s)
  run network::retry 4 1 slow_command
  local end=$(date +%s)
  local duration=$((end - start))

  # Expected: 1s + 2s + 4s + 8s = 15s (approximate)
  assert [ ${duration} -ge 7 ]  # At least 1+2+4 seconds

  unset -f slow_command
}
```

#### 绿灯 (Green)
```bash
# lib/network.sh

##
# Retry command with exponential backoff
#
# Arguments:
#   $1 - Max retries (number, required)
#   $2 - Initial delay in seconds (number, required)
#   $@ - Command to execute (string, required)
#
# Output:
#   Command stdout/stderr
#
# Returns:
#   0 - Command succeeded
#   1 - Command failed after max retries
#
# Example:
#   network::retry 3 2 curl -fsSL https://example.com
##
network::retry() {
  local max_retries="${1}"; shift
  local initial_delay="${1}"; shift
  local attempt=0
  local delay="${initial_delay}"

  while [[ ${attempt} -lt ${max_retries} ]]; do
    attempt=$((attempt + 1))

    core::log debug "attempt ${attempt}/${max_retries}" "$(printf '{"command":"%s"}' "${*}")"

    # Execute command
    if "${@}"; then
      core::log debug "command succeeded" "$(printf '{"attempt":%d}' ${attempt})"
      return 0
    fi

    # Check if we should retry
    if [[ ${attempt} -lt ${max_retries} ]]; then
      core::log warn "command failed, retrying in ${delay}s" "$(printf '{"attempt":%d,"max_retries":%d}' ${attempt} ${max_retries})"
      sleep "${delay}"
      delay=$((delay * 2))  # Exponential backoff
    fi
  done

  core::log error "command failed after ${max_retries} attempts" '{}'
  return 1
}
```

### 3.2 TDD Cycle 2: 集成到下载函数

#### 红灯 (Red)
```bash
# tests/unit/test_download_methods.bats

@test "download::via_tarball - retries on network failure" {
  # Mock curl to fail twice then succeed
  local call_count=0
  function curl() {
    call_count=$((call_count + 1))
    if [[ ${call_count} -lt 3 ]]; then
      echo "curl: connection failed" >&2
      return 1
    else
      # Simulate successful download
      echo "tarball content" > "${4}"  # $4 is the -o output file
      return 0
    fi
  }
  export -f curl

  local tmpdir="$(mktemp -d)"
  run download::via_tarball_with_retry "http://test.url" "${tmpdir}" "main" 3 1
  assert_success

  unset -f curl
  rm -rf "${tmpdir}"
}
```

#### 绿灯 (Green)
```bash
# lib/download.sh

##
# Download tarball with retry logic
#
# Arguments:
#   $1 - URL (string, required)
#   $2 - Destination directory (string, required)
#   $3 - Branch name (string, required)
#   $4 - Max retries (number, default: 3)
#   $5 - Initial delay (number, default: 2)
#
# Returns:
#   0 - Download successful
#   1 - Download failed after retries
##
download::via_tarball_with_retry() {
  local url="${1}"
  local dest_dir="${2}"
  local branch="${3}"
  local max_retries="${4:-3}"
  local initial_delay="${5:-2}"

  # Wrapper function for retry
  _download_once() {
    download::via_tarball "${url}" "${dest_dir}" "${branch}"
  }

  # Use network::retry
  if ! network::retry "${max_retries}" "${initial_delay}" _download_once; then
    core::log error "tarball download failed after retries" '{}'
    return 1
  fi

  return 0
}
```

### 3.3 修改 install.sh

```bash
# install.sh

download_project() {
  # ... (前面的代码相同)

  # Source modules
  [[ -f "${HERE:-/usr/local/xray-fusion}/lib/network.sh" ]] && \
    source "${HERE:-/usr/local/xray-fusion}/lib/network.sh"
  [[ -f "${HERE:-/usr/local/xray-fusion}/lib/download.sh" ]] && \
    source "${HERE:-/usr/local/xray-fusion}/lib/download.sh"

  # Download with retry (3 attempts, 2s initial delay)
  if ! network::retry 3 2 download::with_fallback "${REPO_URL}" "${TMP_DIR}" "${BRANCH}"; then
    error_exit "下载失败（已尝试 3 次）"
  fi

  # ... (后面的验证代码相同)
}
```

### 3.4 验收标准
- [ ] 单元测试覆盖重试逻辑
- [ ] 验证指数退避行为（1s, 2s, 4s, 8s）
- [ ] 集成测试：模拟网络不稳定
- [ ] 文档更新：说明重试参数

---

## Phase 4: 依赖检查前置 (P1 - 可靠性)

**目标**: Fail-fast 原则，尽早发现依赖问题

### 4.1 TDD Cycle: 早期依赖检查

#### 红灯 (Red)
```bash
# tests/unit/test_dependency_check.bats

@test "deps::check_critical - succeeds when tools available" {
  run deps::check_critical
  assert_success
}

@test "deps::check_critical - fails when no downloader available" {
  # Mock all downloaders to be missing
  function command() {
    case "${2}" in
      curl|wget|git) return 1 ;;
      *) return 0 ;;
    esac
  }
  export -f command

  run deps::check_critical
  assert_failure
  assert_output --partial "需要至少一个下载工具"

  unset -f command
}

@test "deps::check_critical - detects missing systemctl" {
  function command() {
    [[ "${2}" == "systemctl" ]] && return 1
    return 0
  }
  export -f command

  run deps::check_critical
  assert_failure
  assert_output --partial "systemctl"

  unset -f command
}
```

#### 绿灯 (Green)
```bash
# lib/dependencies.sh

##
# Check critical dependencies before proceeding
#
# Verifies:
#   - At least one downloader (git/curl/wget)
#   - systemctl (for service management)
#   - Basic POSIX utilities
#
# Returns:
#   0 - All critical dependencies available
#   1 - Missing critical dependencies
##
deps::check_critical() {
  local missing=()

  # Check downloader availability
  local has_downloader=false
  for tool in git curl wget; do
    if command -v "${tool}" >/dev/null 2>&1; then
      has_downloader=true
      core::log debug "found downloader" "$(printf '{"tool":"%s"}' "${tool}")"
      break
    fi
  done

  if [[ "${has_downloader}" == "false" ]]; then
    core::log error "需要至少一个下载工具: git, curl, 或 wget" '{}'
    return 1
  fi

  # Check systemctl
  if ! command -v systemctl >/dev/null 2>&1; then
    core::log error "systemctl not found (systemd required)" '{}'
    missing+=("systemctl")
  fi

  # Check basic utilities
  for tool in mktemp tar gzip; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      core::log warn "missing utility" "$(printf '{"tool":"%s"}' "${tool}")"
      missing+=("${tool}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    core::log error "missing critical dependencies" "$(printf '{"tools":"%s"}' "${missing[*]}")"
    return 1
  fi

  core::log debug "all critical dependencies available" '{}'
  return 0
}

##
# Check optional dependencies
#
# Returns:
#   0 - Always succeeds (logs warnings for missing tools)
##
deps::check_optional() {
  local optional_tools="jq openssl gpg"
  local missing=()

  for tool in ${optional_tools}; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing+=("${tool}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    core::log warn "missing optional tools (will be installed later)" "$(printf '{"tools":"%s"}' "${missing[*]}")"
  fi

  return 0
}
```

### 4.2 修改 install.sh 执行顺序

```bash
# install.sh (main 函数)

main() {
  # Banner
  echo -e "${GREEN}"
  cat << 'EOF'
 ██╗  ██╗██████╗  █████╗ ██╗   ██╗      ███████╗██╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗
 ...
EOF
  echo -e "${NC}"
  echo "                    Xray Fusion - One-Click Installer"
  echo ""

  # === PHASE 1: Early checks (before any downloads) ===
  log_info "[1/7] 检查运行环境..."
  early_checks  # ROOT, systemd, architecture

  log_info "[2/7] 检查核心依赖..."
  # Source dependency module
  TMP_DIR="$(mktemp -d)"
  source_args_module  # Need logging functions

  # Check dependencies early (fail-fast)
  if [[ -f "${HERE:-/usr/local/xray-fusion}/lib/dependencies.sh" ]]; then
    source "${HERE:-/usr/local/xray-fusion}/lib/dependencies.sh"
    deps::check_critical || error_exit "缺少关键依赖，无法继续"
    deps::check_optional
  else
    # Fallback: basic check
    local has_downloader=false
    for tool in git curl wget; do
      command -v "${tool}" >/dev/null 2>&1 && has_downloader=true && break
    done
    [[ "${has_downloader}" == "true" ]] || error_exit "需要 git/curl/wget 之一"
  fi

  # === PHASE 2: Parse arguments ===
  log_info "[3/7] 解析参数..."
  parse_args "${@}"
  setup_environment

  # === PHASE 3: System checks ===
  log_info "[4/7] 检查系统配置..."
  check_system

  # === PHASE 4: Install dependencies ===
  log_info "[5/7] 安装缺失的依赖包..."
  install_dependencies

  # === PHASE 5: Download project ===
  log_info "[6/7] 下载 xray-fusion..."
  download_project

  # === PHASE 6: Install ===
  log_info "[7/7] 安装并配置..."
  install_xray_fusion
  run_xray_install

  # === PHASE 7: Summary ===
  show_summary
  log_info "安装完成！"
}
```

### 4.3 验收标准
- [ ] 依赖检查在参数解析之前执行
- [ ] 缺少关键依赖时立即失败（不浪费时间）
- [ ] 清晰的进度指示（[N/M] 步骤）
- [ ] 文档更新：依赖列表

---

## Phase 5: 进度反馈优化 (P2 - 体验)

**目标**: 清晰的安装进度指示，参考 Claude 风格的简洁输出

### 5.1 TDD Cycle: 进度日志函数

#### 红灯 (Red)
```bash
# tests/unit/test_progress_logging.bats

@test "log_step - formats step indicator correctly" {
  run log_step 1 7 "检查运行环境"
  assert_success
  assert_output --regexp '\[1/7\].*检查运行环境'
}

@test "log_step - handles different total steps" {
  run log_step 10 15 "最后一步"
  assert_success
  assert_output --regexp '\[10/15\].*最后一步'
}

@test "log_substep - indents correctly" {
  run log_substep "子任务"
  assert_success
  assert_output --regexp '  [•✓✗].*子任务'
}
```

#### 绿灯 (Green)
```bash
# install.sh (添加到日志函数部分)

##
# Log installation step with progress indicator
#
# Arguments:
#   $1 - Current step number
#   $2 - Total steps
#   $3 - Step description
##
log_step() {
  local current="${1}"
  local total="${2}"
  local desc="${3}"
  echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
}

##
# Log sub-step with indentation
#
# Arguments:
#   $1 - Sub-step description
#   $2 - Status icon (optional): • (default), ✓, ✗
##
log_substep() {
  local desc="${1}"
  local icon="${2:-•}"

  case "${icon}" in
    success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
    error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
    *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
  esac
}

##
# Show spinner for long-running tasks
#
# Usage:
#   show_spinner "Task description" &
#   SPINNER_PID=$!
#   long_running_command
#   kill ${SPINNER_PID} 2>/dev/null
##
show_spinner() {
  local desc="${1}"
  local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local i=0

  while true; do
    printf "\r  ${BLUE}${chars:$i:1}${NC} %s" "${desc}"
    i=$(( (i + 1) % ${#chars} ))
    sleep 0.1
  done
}
```

### 5.2 修改 main 函数使用新日志

```bash
# install.sh (main 函数 - 最终版本)

main() {
  # Banner
  echo -e "${GREEN}"
  cat << 'EOF'
 ██╗  ██╗██████╗  █████╗ ██╗   ██╗      ███████╗██╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗
 ...
EOF
  echo -e "${NC}"
  echo ""

  # Setup
  TMP_DIR="$(mktemp -d)"
  source_args_module

  # Phase 1: Early checks
  log_step 1 7 "检查运行环境"
  early_checks
  log_substep "ROOT 权限" "✓"
  log_substep "systemd 可用" "✓"
  log_substep "架构支持 ($(uname -m))" "✓"

  # Phase 2: Dependency check
  log_step 2 7 "检查核心依赖"
  if [[ -f "${HERE:-/usr/local/xray-fusion}/lib/dependencies.sh" ]]; then
    source "${HERE:-/usr/local/xray-fusion}/lib/dependencies.sh"
    if deps::check_critical && deps::check_optional; then
      log_substep "下载工具可用" "✓"
      log_substep "系统工具就绪" "✓"
    else
      error_exit "依赖检查失败"
    fi
  fi

  # Phase 3: Parse arguments
  log_step 3 7 "解析配置参数"
  parse_args "${@}"
  setup_environment
  log_substep "拓扑: ${TOPOLOGY}" "✓"
  [[ -n "${DOMAIN}" ]] && log_substep "域名: ${DOMAIN}" "✓"

  # Phase 4: System checks
  log_step 4 7 "检查系统兼容性"
  check_system
  log_substep "操作系统兼容" "✓"

  # Phase 5: Install dependencies
  log_step 5 7 "安装必需依赖包"
  install_dependencies  # Internally uses log_substep

  # Phase 6: Download (with spinner for slow networks)
  log_step 6 7 "下载 xray-fusion"
  log_substep "仓库: ${REPO_URL##*/}"
  log_substep "分支: ${BRANCH}"

  # Show spinner during download
  if [[ "${XRF_DEBUG}" != "true" ]]; then
    show_spinner "正在下载..." &
    SPINNER_PID=$!
  fi

  download_project

  [[ -n "${SPINNER_PID:-}" ]] && kill ${SPINNER_PID} 2>/dev/null
  printf "\r"  # Clear spinner line
  log_substep "下载完成" "✓"

  # Phase 7: Install
  log_step 7 7 "安装并配置 Xray"
  install_xray_fusion
  log_substep "文件复制完成" "✓"

  run_xray_install
  log_substep "服务启动成功" "✓"

  echo ""
  show_summary

  echo ""
  log_info "${GREEN}✓${NC} 安装完成！"
}
```

### 5.3 验收标准
- [ ] 清晰的步骤编号（[N/M]）
- [ ] 子步骤使用图标（• ✓ ✗）
- [ ] 长时间任务显示 spinner（可选）
- [ ] 错误输出突出显示
- [ ] 最终输出简洁明了

---

## 测试策略

### 单元测试 (Unit Tests)
```bash
# 运行所有单元测试
make test-unit

# 运行特定模块测试
bats tests/unit/test_download_verification.bats
bats tests/unit/test_download_methods.bats
bats tests/unit/test_network_retry.bats
bats tests/unit/test_dependency_check.bats
```

### 集成测试 (Integration Tests)
```bash
# 完整安装流程测试
bats tests/integration/test_install_flow.bats

# 模拟故障场景
XRF_TEST_FAIL_GIT=true bats tests/integration/test_install_fallback.bats
XRF_TEST_NETWORK_SLOW=true bats tests/integration/test_install_retry.bats
```

### 手动测试 (Manual Tests)
```bash
# 1. 测试完整性验证
export XRF_EXPECTED_COMMIT="wrong-hash"
bash install.sh --topology reality-only  # 应该失败

# 2. 测试下载回退
# 禁用 git
sudo mv /usr/bin/git /usr/bin/git.bak
bash install.sh --topology reality-only  # 应该使用 tarball

# 3. 测试网络重试
# 使用 tc (traffic control) 模拟网络延迟
sudo tc qdisc add dev eth0 root netem delay 1000ms loss 30%
bash install.sh --topology reality-only  # 应该重试成功

# 4. 测试依赖检查
# 在最小容器中测试
docker run -it --rm debian:12-slim bash
# 复制 install.sh 并运行，验证依赖检查和自动安装
```

---

## CI/CD 集成

### GitHub Actions Workflow
```yaml
# .github/workflows/test-install-script.yml

name: Test Install Script

on:
  pull_request:
    paths:
      - 'install.sh'
      - 'lib/download.sh'
      - 'lib/network.sh'
      - 'lib/dependencies.sh'
      - 'tests/**'

jobs:
  test-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run unit tests
        run: make test-unit

  test-integration:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-20.04, debian-12, debian-11]
    steps:
      - uses: actions/checkout@v3

      - name: Test install script
        run: |
          bash install.sh --topology reality-only --debug

  test-fallback:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Test without git
        run: |
          sudo mv /usr/bin/git /usr/bin/git.bak || true
          bash install.sh --topology reality-only --debug
          sudo mv /usr/bin/git.bak /usr/bin/git || true

      - name: Test with network issues
        run: |
          # Simulate slow network
          export XRF_TEST_NETWORK_SLOW=true
          bash install.sh --topology reality-only --debug
```

---

## 文档更新

### README.md 更新
```markdown
## 安装

### 一键安装（推荐）

#### 基本安装
```bash
curl -fsSL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- --topology reality-only
```

#### 高级选项
```bash
# 指定版本和域名
curl -fsSL install.sh | bash -s -- \
  --topology vision-reality \
  --domain your.domain.com \
  --version v1.8.1 \
  --plugins cert-auto

# 使用代理
curl -fsSL install.sh | bash -s -- \
  --topology reality-only \
  --proxy http://proxy.example.com:8080

# 验证下载完整性（推荐）
export XRF_EXPECTED_COMMIT="abc123..."  # 从 GitHub releases 获取
curl -fsSL install.sh | bash -s -- --topology reality-only
```

### 环境变量

#### 下载配置
- `XRF_REPO_URL`: 仓库 URL（默认: 官方仓库）
- `XRF_BRANCH`: 分支名（默认: main）
- `XRF_EXPECTED_COMMIT`: 期望的 commit hash（用于完整性验证）
- `XRF_INSTALL_DIR`: 安装目录（默认: /usr/local/xray-fusion）

#### 网络配置
- `http_proxy` / `https_proxy`: HTTP 代理
- `XRF_RETRY_MAX`: 最大重试次数（默认: 3）
- `XRF_RETRY_DELAY`: 初始重试延迟秒数（默认: 2）

#### 调试选项
- `XRF_DEBUG=true`: 启用详细日志
- `XRF_JSON=true`: JSON 格式日志

### 依赖要求

#### 核心依赖（至少一个）
- `git` (推荐，保留完整历史)
- `curl` 或 `wget` (备用下载方式)

#### 系统要求
- `systemd` (服务管理)
- `tar`, `gzip` (解压缩)
- `mktemp` (临时文件)

#### 可选依赖（会自动安装）
- `jq` (JSON 处理)
- `openssl` (加密)
- `gpg` (签名验证)

### 故障排除

#### 下载失败
安装脚本会自动尝试多种下载方式：
1. git clone (首选)
2. tarball via curl
3. tarball via wget

如果所有方式都失败，请检查：
- 网络连接
- 防火墙设置
- 尝试使用代理: `--proxy http://...`

#### 完整性验证失败
如果出现 "commit hash mismatch" 错误：
- 检查 `XRF_EXPECTED_COMMIT` 是否正确
- 移除该环境变量以跳过验证（不推荐）
- 检查是否有中间人攻击风险

#### 依赖缺失
脚本会自动安装缺失的依赖包。如果自动安装失败：
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl wget git jq openssl

# CentOS/RHEL
sudo yum install -y curl wget git jq openssl
```
```

### CLAUDE.md ADR 更新
```markdown
### ADR-011: 安装脚本多重下载回退（2025-11-XX）
**问题**: 单一下载方式（git clone）在网络受限环境下失败率高

**决策**: 实现多重下载方式自动回退机制

**实现**:
1. git clone (首选，保留 .git 历史)
2. tarball via curl (备选)
3. tarball via wget (最后备选)

**理由**:
- 可靠性：提高网络不稳定环境下的成功率
- 灵活性：支持不同的网络环境和工具可用性
- 参考实现：Claude 官方安装脚本使用类似策略

---

### ADR-012: 网络操作指数退避重试（2025-11-XX）
**问题**: 临时网络故障导致安装失败

**决策**: 实现指数退避重试机制（1s, 2s, 4s, 8s）

**理由**:
- 容错性：避免临时网络波动导致的失败
- 标准实践：符合 HTTP 503 Retry-After 最佳实践
- 用户体验：减少因网络抖动导致的重新安装

---

### ADR-013: Fail-Fast 依赖检查（2025-11-XX）
**问题**: 依赖缺失在安装后期才发现，浪费时间

**决策**: 在下载和安装前进行完整依赖检查

**理由**:
- 快速失败：立即发现问题，不浪费用户时间
- 清晰反馈：明确指出缺失的依赖和安装方法
- 参考实践：Claude 官方脚本在执行前验证所有依赖
```

---

## 实施时间表

### Week 1
- **Day 1-2**: Phase 1 (下载完整性验证)
  - 编写测试用例
  - 实现验证逻辑
  - 集成到 install.sh

- **Day 3-4**: Phase 2 (多种下载方式回退)
  - tarball 下载实现
  - 回退逻辑测试
  - 集成测试

- **Day 5**: Phase 3 (网络重试机制)
  - 重试函数实现
  - 指数退避测试

### Week 2
- **Day 6**: Phase 4 (依赖检查前置)
  - 依赖检查模块
  - 调整执行顺序

- **Day 7**: Phase 5 (进度反馈优化)
  - 进度日志函数
  - UI 优化

- **Day 8-9**: 集成测试和文档
  - 完整流程测试
  - 更新文档
  - CI/CD 配置

- **Day 10**: Code Review 和发布
  - 内部 review
  - 准备 release notes
  - 合并到 main

---

## 成功指标

### 代码质量
- [ ] 测试覆盖率 ≥ 85%
- [ ] ShellCheck 无警告
- [ ] 所有测试通过

### 可靠性
- [ ] 网络不稳定环境下成功率 > 95%
- [ ] 支持 3 种下载方式
- [ ] 自动重试 3 次

### 用户体验
- [ ] 安装时间 < 5 分钟（正常网络）
- [ ] 清晰的进度指示
- [ ] 友好的错误提示

### 文档完整性
- [ ] README 更新
- [ ] ADR 记录
- [ ] 测试文档

---

## 回滚计划

如果某个阶段出现严重问题：

1. **回退到上一个稳定版本**
   ```bash
   git revert <commit-hash>
   ```

2. **使用特性开关临时禁用新功能**
   ```bash
   export XRF_USE_LEGACY_DOWNLOAD=true
   ```

3. **保留旧代码作为备选**
   ```bash
   # 在新实现中保留回退路径
   if [[ "${XRF_USE_LEGACY_DOWNLOAD}" == "true" ]]; then
     # Old implementation
   else
     # New implementation
   fi
   ```

---

**最后更新**: 2025-11-10
**负责人**: Claude Code Agent
**状态**: 待审批
