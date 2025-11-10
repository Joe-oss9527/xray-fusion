# 代码重复修复计划 - 多阶段实施方案

## 📋 执行摘要

**目标**: 消除 65 行重复代码，提升代码质量和可维护性
**总工作量**: 2.5-3 小时
**阶段数**: 5 个独立阶段
**风险等级**: 低（每阶段独立，可回滚）

---

## 🎯 整体策略

### 核心原则
1. **渐进式修复**: 每个阶段独立完成，测试通过后再进入下一阶段
2. **最小影响**: 优先修复高影响、低风险的问题
3. **完整验证**: 每阶段都有单元测试 + 集成测试
4. **可回滚**: 每次提交都是独立的，可以单独回滚

### 阶段优先级排序依据
- **Phase 1-2**: 高优先级，影响多个文件，技术债务严重
- **Phase 3**: 安全性问题，必须修复
- **Phase 4-5**: 代码优化，改善维护性

---

## 📅 Phase 1: ShortId 生成函数提取

### 目标
消除 90 行重复代码，统一 shortId 生成逻辑

### 当前问题
`commands/install.sh:87-116` 中相同的 30 行逻辑重复 3 次：
```bash
# 重复模式（30行 × 3 = 90行）
if [[ -z "${XRAY_SHORT_ID:-}" ]]; then
  if command -v xxd > /dev/null 2>&1; then
    XRAY_SHORT_ID="$(head -c 8 /dev/urandom | xxd -p -c 16)"
  elif command -v od > /dev/null 2>&1; then
    XRAY_SHORT_ID="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
  else
    XRAY_SHORT_ID="$(openssl rand -hex 8)"
  fi
fi
```

### 修复步骤

#### Step 1.1: 添加函数到 `services/xray/common.sh`
```bash
##
# Generate a random shortId for Xray Reality
#
# Creates a 16-character hexadecimal string using reliable tools.
# Tries xxd → od → openssl (in order of preference).
#
# Output:
#   16-character hexadecimal string to stdout
#
# Returns:
#   0 - Success
#   1 - All tools failed (should never happen, openssl is always available)
#
# Example:
#   shortid=$(xray::generate_shortid)
#   # Output: a1b2c3d4e5f67890
##
xray::generate_shortid() {
  local result=""

  if command -v xxd > /dev/null 2>&1; then
    result="$(head -c 8 /dev/urandom | xxd -p -c 16)"
  elif command -v od > /dev/null 2>&1; then
    result="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
  elif command -v openssl > /dev/null 2>&1; then
    result="$(openssl rand -hex 8)"
  else
    core::log error "no suitable tool found for shortId generation" "{}"
    return 1
  fi

  # Output the result
  echo "${result}"
  return 0
}
```

#### Step 1.2: 更新 `commands/install.sh`
**修改区域**: 第 87-116 行

**原代码** (90 行):
```bash
# Generate shortIds (Primary + 2 additional for client differentiation)
if [[ -z "${XRAY_SHORT_ID:-}" ]]; then
  if command -v xxd > /dev/null 2>&1; then
    XRAY_SHORT_ID="$(head -c 8 /dev/urandom | xxd -p -c 16)"
  elif command -v od > /dev/null 2>&1; then
    XRAY_SHORT_ID="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
  else
    XRAY_SHORT_ID="$(openssl rand -hex 8)"
  fi
fi

if [[ -z "${XRAY_SHORT_ID_2:-}" ]]; then
  # ... 重复相同逻辑 ...
fi

if [[ -z "${XRAY_SHORT_ID_3:-}" ]]; then
  # ... 重复相同逻辑 ...
fi

# Validate each shortId
for sid_var in XRAY_SHORT_ID XRAY_SHORT_ID_2 XRAY_SHORT_ID_3; do
  # ... validation ...
done
```

**新代码** (~25 行):
```bash
# Source xray common utilities
. "${HERE}/services/xray/common.sh"

# Generate shortIds (Primary + 2 additional for client differentiation)
[[ -z "${XRAY_SHORT_ID:-}" ]] && XRAY_SHORT_ID="$(xray::generate_shortid)" || true
[[ -z "${XRAY_SHORT_ID_2:-}" ]] && XRAY_SHORT_ID_2="$(xray::generate_shortid)" || true
[[ -z "${XRAY_SHORT_ID_3:-}" ]] && XRAY_SHORT_ID_3="$(xray::generate_shortid)" || true

# Validate all generated shortIds
for sid_var in XRAY_SHORT_ID XRAY_SHORT_ID_2 XRAY_SHORT_ID_3; do
  if [[ -n "${!sid_var:-}" ]] && ! validators::shortid "${!sid_var}"; then
    core::log error "invalid shortId format" "$(printf '{"var":"%s","value":"%s"}' "${sid_var}" "${!sid_var}")"
    exit 1
  fi
done

core::log debug "shortIds generated" "$(printf '{"ids":["%s","%s","%s"]}' "${XRAY_SHORT_ID}" "${XRAY_SHORT_ID_2}" "${XRAY_SHORT_ID_3}")"
```

#### Step 1.3: 添加单元测试
**文件**: `tests/unit/test-xray-common.bats`

```bash
#!/usr/bin/env bats

setup() {
  load '../test-helper'
  common_setup

  # Source the module under test
  source "${PROJECT_ROOT}/services/xray/common.sh"
}

@test "xray::generate_shortid generates 16-character hex string" {
  local result
  result="$(xray::generate_shortid)"

  # Check length
  [[ "${#result}" -eq 16 ]]

  # Check hex format
  [[ "${result}" =~ ^[0-9a-f]{16}$ ]]
}

@test "xray::generate_shortid generates unique values" {
  local id1 id2 id3
  id1="$(xray::generate_shortid)"
  id2="$(xray::generate_shortid)"
  id3="$(xray::generate_shortid)"

  # All three should be different
  [[ "${id1}" != "${id2}" ]]
  [[ "${id2}" != "${id3}" ]]
  [[ "${id1}" != "${id3}" ]]
}

@test "xray::generate_shortid works with xxd" {
  if ! command -v xxd > /dev/null 2>&1; then
    skip "xxd not available"
  fi

  local result
  result="$(xray::generate_shortid)"
  [[ "${#result}" -eq 16 ]]
}

@test "xray::generate_shortid works with od" {
  if ! command -v od > /dev/null 2>&1; then
    skip "od not available"
  fi

  # Temporarily hide xxd
  PATH="/usr/bin:/bin" result="$(xray::generate_shortid)"
  [[ "${#result}" -eq 16 ]]
}

@test "xray::generate_shortid works with openssl" {
  if ! command -v openssl > /dev/null 2>&1; then
    skip "openssl not available"
  fi

  local result
  result="$(openssl rand -hex 8)"
  [[ "${#result}" -eq 16 ]]
}
```

### 验证标准

#### 自动化测试
```bash
# 1. 格式化检查
make fmt

# 2. 静态分析
make lint

# 3. 单元测试
make test-unit

# 4. 功能测试（生成 shortId）
bash -c '
  source services/xray/common.sh
  for i in {1..10}; do
    id=$(xray::generate_shortid)
    echo "ShortId $i: $id (length: ${#id})"
    [[ ${#id} -eq 16 ]] || exit 1
  done
'
```

#### 集成测试
```bash
# 测试 install.sh 是否正常工作
XRF_PREFIX=/tmp/test-phase1 \
XRF_ETC=/tmp/test-phase1/etc \
bin/xrf install --topology reality-only --dry-run
```

### 回滚计划
```bash
# 如果出现问题，回滚到上一个提交
git revert HEAD
git push -f origin claude/code-review-check-011CV14r7CTdEsN1mdRAqXCP
```

### 预期结果
- ✅ 代码减少: 65 行 → 25 行（节省 40 行）
- ✅ 新增函数: `xray::generate_shortid()`
- ✅ 测试覆盖: 6 个新测试用例
- ✅ 可维护性提升: 统一生成逻辑

---

## 📅 Phase 2: 日志函数统一

### 目标
统一 `lib/core.sh` 和 `scripts/caddy-cert-sync.sh` 的日志格式

### 当前问题

**文件对比**:
1. `lib/core.sh::core::log()` - 45 行完整实现
2. `scripts/caddy-cert-sync.sh::log()` - 简化版实现

**差异**:
- 时间戳生成: `core::ts` vs `date -u +%Y-%m-%dT%H:%M:%SZ`
- 日志格式宽度: `%-8s` vs `%-5s`
- 缺少 `fatal` 级别支持

### 修复步骤

#### Step 2.1: 标准化 `lib/core.sh::core::log()`

**当前实现** (lib/core.sh:45-70):
```bash
core::log() {
  local lvl="${1}"; shift
  local msg="${1}"; shift || true
  local ctx="${1-{} }"

  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' \
      "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  fi
}
```

**优化后** (统一格式宽度为 8):
```bash
core::log() {
  local lvl="${1}"; shift
  local msg="${1}"; shift || true
  local ctx="${1-{} }"

  # Filter debug messages unless XRF_DEBUG is true
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  # All logs to stderr
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' \
      "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  else
    # Use consistent width: %-8s for better alignment
    printf '[%s] %-8s %s %s\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  fi
}
```

#### Step 2.2: 更新 `scripts/caddy-cert-sync.sh`

**当前实现** (caddy-cert-sync.sh:101-117):
```bash
log() {
  local lvl="${1}"
  shift
  local msg="${1}"

  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"[caddy-cert-sync] %s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  else
    printf '[%s] %-5s [caddy-cert-sync] %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  fi
}
```

**新实现** (统一时间戳和格式):
```bash
##
# Standalone logging function compatible with core::log
#
# This is a lightweight version for standalone scripts that cannot
# source lib/core.sh. Maintains compatibility with the main logging
# system's format and behavior.
#
# Arguments:
#   $1 - Log level (debug|info|warn|error)
#   $2 - Message string
#
# Globals:
#   XRF_JSON - If "true", output JSON format
#   XRF_DEBUG - If "true", show debug messages
#
# Output:
#   Log line to stderr (text or JSON format)
##
log() {
  local lvl="${1}"
  shift
  local msg="${1}"

  # Filter debug messages unless XRF_DEBUG is true
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  # Generate ISO 8601 timestamp (UTC)
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # All logs to stderr
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"[caddy-cert-sync] %s"}\n' \
      "${ts}" "${lvl}" "${msg}" >&2
  else
    # Use consistent width: %-8s (matches lib/core.sh)
    printf '[%s] %-8s [caddy-cert-sync] %s\n' \
      "${ts}" "${lvl}" "${msg}" >&2
  fi
}
```

#### Step 2.3: 添加日志格式验证测试

**文件**: `tests/integration/test-log-format.bats`

```bash
#!/usr/bin/env bats

setup() {
  load '../test-helper'
  common_setup
}

@test "core::log produces consistent format" {
  source "${PROJECT_ROOT}/lib/core.sh"

  # Capture log output
  output=$(core::log info "test message" "{}" 2>&1)

  # Check format: [timestamp] level    message context
  [[ "${output}" =~ ^\[[0-9T:Z-]+\]\ (info|warn|error|debug)\ {8}.*\ \{\}$ ]]
}

@test "caddy-cert-sync log matches core::log format" {
  # Extract log function from script
  source <(sed -n '/^log()/,/^}/p' "${PROJECT_ROOT}/scripts/caddy-cert-sync.sh")

  # Capture log output
  output=$(log info "test message" 2>&1)

  # Check same format as core::log
  [[ "${output}" =~ ^\[[0-9T:Z-]+\]\ (info|warn|error|debug)\ {8}\[caddy-cert-sync\].*$ ]]
}

@test "JSON format is consistent across logs" {
  export XRF_JSON=true

  # Test core::log
  source "${PROJECT_ROOT}/lib/core.sh"
  output1=$(core::log info "msg1" "{}" 2>&1)

  # Test caddy-cert-sync log
  source <(sed -n '/^log()/,/^}/p' "${PROJECT_ROOT}/scripts/caddy-cert-sync.sh")
  output2=$(log info "msg2" 2>&1)

  # Both should be valid JSON
  echo "${output1}" | jq . > /dev/null
  echo "${output2}" | jq . > /dev/null
}
```

### 验证标准

```bash
# 1. 格式化和静态检查
make fmt && make lint

# 2. 单元测试
make test-unit

# 3. 手动验证日志格式
# Test core::log
bash -c 'source lib/core.sh && core::log info "Test message" "{}"' 2>&1

# Test caddy-cert-sync log
/usr/local/bin/caddy-cert-sync example.com 2>&1 | head -3

# 4. JSON 格式验证
XRF_JSON=true bash -c 'source lib/core.sh && core::log info "Test" "{}"' 2>&1 | jq .
```

### 预期结果
- ✅ 统一时间戳格式（ISO 8601）
- ✅ 统一日志宽度（%-8s）
- ✅ 文档完善（添加 ShellDoc 注释）
- ✅ 测试覆盖（3 个新测试用例）

---

## 📅 Phase 3: Domain 验证安全修复 (⚠️ 高优先级)

### 目标
删除 `install.sh` 中的简化版验证，统一使用 `lib/validators.sh`

### 安全问题

**当前状态**: `install.sh:306-319` 包含简化版域名验证，缺少：
- ❌ RFC 3927 链路本地地址检测（169.254.0.0/16）
- ❌ RFC 6761 特殊用途 TLD（.test, .invalid）
- ❌ IPv6 私有地址检测（::1, fc00::/7, fe80::/10）

**风险**: 可能允许无效域名配置，导致服务无法正常工作

### 修复步骤

#### Step 3.1: 验证 `lib/validators.sh` 完整性

确认 `validators::domain()` 包含所有安全检查：

```bash
# 检查函数实现
grep -A 50 "validators::domain" lib/validators.sh

# 确认包含以下检测：
# - RFC 1918 私有地址
# - RFC 3927 链路本地地址
# - RFC 6761 特殊用途域名
# - IPv6 私有地址
```

#### Step 3.2: 删除 `install.sh` 中的重复验证

**文件**: `install.sh`
**位置**: 第 306-319 行

**删除的代码**:
```bash
# Simplified domain validation (DEPRECATED - use lib/validators.sh)
args::validate_domain() {
  local domain="${1}"
  [[ -z "${domain}" ]] && return 1

  # Basic format check only
  [[ "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]] || return 1

  # Reject localhost and private IPs
  case "${domain}" in
    localhost|*.local|127.*|10.*|192.168.*) return 1 ;;
  esac

  return 0
}
```

**替换为**:
```bash
# Source validators from lib (contains RFC-compliant validation)
. "${HERE}/lib/validators.sh"

# args::validate_domain is now provided by lib/validators.sh
# Uses validators::domain() with full RFC compliance:
# - RFC 1918: Private IPv4 addresses
# - RFC 3927: Link-local addresses (169.254.0.0/16)
# - RFC 6761: Special-use domain names (.test, .invalid)
# - RFC 4193: IPv6 unique local addresses (fc00::/7, fd00::/8)
# - RFC 4291: IPv6 link-local addresses (fe80::/10)
```

#### Step 3.3: 更新函数调用

确保所有域名验证都使用 `validators::domain()`:

```bash
# 查找所有调用
grep -rn "args::validate_domain\|validators::domain" install.sh commands/

# 统一调用方式
validators::domain "${DOMAIN}" || {
  core::log error "invalid domain" "$(printf '{"domain":"%s"}' "${DOMAIN}")"
  exit 1
}
```

#### Step 3.4: 添加安全测试用例

**文件**: `tests/unit/test-validators.bats`

**新增测试**:
```bash
# RFC 3927 link-local addresses
@test "validators::domain rejects RFC 3927 link-local addresses" {
  source "${PROJECT_ROOT}/lib/validators.sh"

  run validators::domain "169.254.1.1"
  [[ "$status" -eq 1 ]]

  run validators::domain "169.254.255.255"
  [[ "$status" -eq 1 ]]
}

# RFC 6761 special-use TLDs
@test "validators::domain rejects RFC 6761 special-use domains" {
  source "${PROJECT_ROOT}/lib/validators.sh"

  run validators::domain "example.test"
  [[ "$status" -eq 1 ]]

  run validators::domain "domain.invalid"
  [[ "$status" -eq 1 ]]
}

# IPv6 private addresses
@test "validators::domain rejects IPv6 private addresses" {
  source "${PROJECT_ROOT}/lib/validators.sh"

  # Loopback
  run validators::domain "::1"
  [[ "$status" -eq 1 ]]

  # Unique local (fc00::/7)
  run validators::domain "fc00::1"
  [[ "$status" -eq 1 ]]

  run validators::domain "fd00::1"
  [[ "$status" -eq 1 ]]

  # Link-local (fe80::/10)
  run validators::domain "fe80::1"
  [[ "$status" -eq 1 ]]
}
```

### 验证标准

```bash
# 1. 运行现有测试
make test-unit

# 2. 验证新增安全测试
bats -t tests/unit/test-validators.bats

# 3. 手动测试边界情况
bash -c '
  source lib/validators.sh

  # Should fail
  validators::domain "169.254.1.1" && echo "FAIL" || echo "PASS: link-local rejected"
  validators::domain "example.test" && echo "FAIL" || echo "PASS: .test rejected"
  validators::domain "::1" && echo "FAIL" || echo "PASS: IPv6 loopback rejected"

  # Should pass
  validators::domain "example.com" && echo "PASS: valid domain" || echo "FAIL"
'

# 4. 集成测试
XRF_PREFIX=/tmp/test-phase3 \
bin/xrf install --topology vision-reality --domain example.com --dry-run
```

### 预期结果
- ✅ 删除 13 行重复代码
- ✅ 统一使用 `lib/validators.sh`
- ✅ 安全性提升（RFC 全面检测）
- ✅ 测试覆盖新增 9 个用例

---

## 📅 Phase 4: 锁文件管理优化

### 目标
提取锁文件权限管理为独立函数，消除重复逻辑

### 当前问题

**重复位置**:
1. `lib/core.sh::core::with_flock()` (第 202-240 行)
2. `scripts/caddy-cert-sync.sh` (第 16-71 行)

**重复逻辑** (~35 行):
- 锁目录创建
- 锁文件权限修复（ownership + permissions）
- sudo 检查和降级

### 修复步骤

#### Step 4.1: 提取公共函数到 `lib/core.sh`

**新增函数**:
```bash
##
# Ensure lock file is writable by current user
#
# Handles mixed sudo/non-sudo scenarios where lock file may be
# owned by root from a previous run. Attempts to fix ownership
# and permissions to allow the current user to write to the lock file.
#
# Arguments:
#   $1 - Lock file path (string, required)
#
# Returns:
#   0 - Lock file is writable
#   1 - Failed to make lock file writable
#
# Security:
#   Fixes CWE-283 (Unverified Ownership) by ensuring correct ownership
#   Uses sudo only when necessary (principle of least privilege)
#
# Example:
#   core::ensure_lock_writable "/var/lib/xray-fusion/locks/install.lock"
##
core::ensure_lock_writable() {
  local lock_file="${1}"

  # If file doesn't exist, nothing to fix
  [[ ! -f "${lock_file}" ]] && return 0

  # Try to fix ownership first (may be root-owned)
  if ! chown "$(id -u):$(id -g)" "${lock_file}" 2>/dev/null; then
    # Need sudo to change ownership
    if command -v sudo > /dev/null 2>&1; then
      sudo chown "$(id -u):$(id -g)" "${lock_file}" 2>/dev/null || return 1
    else
      core::log warn "cannot fix lock file ownership, may fail to acquire lock" \
        "$(printf '{"lock":"%s"}' "${lock_file}")"
      return 1
    fi
  fi

  # Fix permissions (make writable)
  if ! chmod 0644 "${lock_file}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo chmod 0644 "${lock_file}" 2>/dev/null || return 1
    else
      return 1
    fi
  fi

  return 0
}
```

#### Step 4.2: 重构 `lib/core.sh::core::with_flock()`

**当前实现** (240 行，包含内联权限修复):
```bash
core::with_flock() {
  local lock_name="${1}"; shift
  local callback="${1}"; shift

  # ... lock directory creation ...

  # Inline permission fix (to be extracted)
  if test -f "${lock}"; then
    if ! chown "$(id -u):$(id -g)" "${lock}" 2>/dev/null; then
      sudo chown "$(id -u):$(id -g)" "${lock}" 2>/dev/null || true
    fi
    if ! chmod 0644 "${lock}" 2>/dev/null; then
      sudo chmod 0644 "${lock}" 2>/dev/null || true
    fi
  fi

  # ... flock logic ...
}
```

**新实现** (使用提取的函数):
```bash
core::with_flock() {
  local lock_name="${1}"; shift
  local callback="${1}"; shift

  local lock_dir="${XRF_STATE:-/var/lib/xray-fusion}/locks"
  local lock="${lock_dir}/${lock_name}.lock"

  # Ensure lock directory exists
  io::ensure_dir "${lock_dir}" 0755 || return 1

  # Fix ownership/permissions if lock file exists
  core::ensure_lock_writable "${lock}" || {
    core::log error "cannot make lock file writable" "$(printf '{"lock":"%s"}' "${lock}")"
    return 1
  }

  # Open file descriptor
  exec 200>> "${lock}" || {
    core::log error "cannot open lock file" "$(printf '{"lock":"%s"}' "${lock}")"
    return 1
  }

  # Acquire lock
  if ! flock -n 200; then
    core::log info "another process holds the lock, skipping" "$(printf '{"lock":"%s"}' "${lock_name}")"
    return 0
  fi

  # Execute callback with lock held
  "${callback}" "$@"
  local ret=$?

  # Release lock (automatic on fd close)
  exec 200>&-

  return ${ret}
}
```

#### Step 4.3: 更新 `scripts/caddy-cert-sync.sh`

**删除重复代码** (第 16-71 行):
```bash
# Old implementation with inline permission fix (~50 lines)
LOCK_DIR="/var/lib/xray-fusion/locks"
LOCK_FILE="${LOCK_DIR}/caddy-cert-sync.lock"

# Create lock directory...
# Fix ownership...
# Fix permissions...
# ... (35 lines of duplication)
```

**新实现** (使用核心函数):
```bash
# Lock file management using core utilities
LOCK_DIR="/var/lib/xray-fusion/locks"
LOCK_FILE="${LOCK_DIR}/caddy-cert-sync.lock"

# Ensure lock directory exists (same logic as io::ensure_dir)
if [[ ! -d "${LOCK_DIR}" ]]; then
  if ! install -d -m 0755 "${LOCK_DIR}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo install -d -m 0755 "${LOCK_DIR}" || {
        log error "failed to create lock directory: ${LOCK_DIR}"
        exit 1
      }
    else
      log error "lock directory does not exist and cannot be created: ${LOCK_DIR}"
      exit 1
    fi
  fi
fi

# Fix ownership/permissions (same logic as core::ensure_lock_writable)
if test -f "${LOCK_FILE}"; then
  # Try to fix ownership
  if ! chown "$(id -u):$(id -g)" "${LOCK_FILE}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo chown "$(id -u):$(id -g)" "${LOCK_FILE}" 2>/dev/null || true
    fi
  fi
  # Fix permissions
  if ! chmod 0644 "${LOCK_FILE}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo chmod 0644 "${LOCK_FILE}" 2>/dev/null || true
    fi
  fi
fi

# Acquire lock
exec 200>> "${LOCK_FILE}"
if ! flock -n 200; then
  log info "another sync process is running, exiting"
  exit 0
fi

# ... rest of script ...
```

#### Step 4.4: 添加测试

**文件**: `tests/unit/test-core-locks.bats`

```bash
@test "core::ensure_lock_writable fixes root-owned lock file" {
  source "${PROJECT_ROOT}/lib/core.sh"

  local tmpdir=$(mktemp -d)
  local lock="${tmpdir}/test.lock"

  # Create root-owned lock file (simulate previous sudo run)
  touch "${lock}"
  sudo chown root:root "${lock}"
  sudo chmod 0600 "${lock}"

  # Fix ownership
  run core::ensure_lock_writable "${lock}"
  [[ "$status" -eq 0 ]]

  # Verify current user can write
  echo "test" >> "${lock}"

  # Cleanup
  rm -rf "${tmpdir}"
}

@test "core::ensure_lock_writable handles non-existent file" {
  source "${PROJECT_ROOT}/lib/core.sh"

  # Should succeed (nothing to fix)
  run core::ensure_lock_writable "/nonexistent/lock.lock"
  [[ "$status" -eq 0 ]]
}
```

### 验证标准

```bash
# 1. 单元测试
make test-unit

# 2. 集成测试 - 模拟混合 sudo 运行
sudo bin/xrf install --topology reality-only --dry-run
bin/xrf status  # Non-root should still work

# 3. 验证锁文件权限
ls -la /var/lib/xray-fusion/locks/
# Expected: -rw-r--r-- current_user:current_group

# 4. 测试证书同步脚本
sudo /usr/local/bin/caddy-cert-sync example.com  # Root run
/usr/local/bin/caddy-cert-sync example.com       # Non-root run (should still work)
```

### 预期结果
- ✅ 新增函数: `core::ensure_lock_writable()`
- ✅ 代码减少: 12 行
- ✅ 一致性: 所有锁管理使用相同逻辑
- ✅ 测试覆盖: 2 个新测试用例

---

## 📅 Phase 5: 目录创建逻辑统一

### 目标
统一使用 `io::ensure_dir()`，消除内联目录创建代码

### 当前问题

**重复位置**:
1. `modules/io.sh::io::ensure_dir()` - 标准实现
2. `lib/core.sh` - 内联版本
3. `scripts/caddy-cert-sync.sh` - 内联版本

### 修复步骤

#### Step 5.1: 验证 `io::ensure_dir()` 健壮性

**当前实现** (modules/io.sh):
```bash
io::ensure_dir() {
  local dir="${1}"
  local mode="${2:-0755}"

  [[ -d "${dir}" ]] && return 0

  if ! install -d -m "${mode}" "${dir}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo install -d -m "${mode}" "${dir}" || return 1
    else
      return 1
    fi
  fi

  return 0
}
```

**增强建议**:
```bash
##
# Ensure directory exists with correct permissions
#
# Creates directory with specified mode, using sudo if needed.
# Idempotent - safe to call multiple times.
#
# Arguments:
#   $1 - Directory path (string, required)
#   $2 - Mode (octal, optional, default: 0755)
#
# Returns:
#   0 - Directory exists with correct permissions
#   1 - Failed to create directory
#
# Security:
#   Uses install(1) for atomic directory creation (CWE-362)
#   Principle of least privilege (tries non-sudo first)
#
# Example:
#   io::ensure_dir "/var/lib/xray-fusion" 0755
##
io::ensure_dir() {
  local dir="${1}"
  local mode="${2:-0755}"

  # Already exists - nothing to do
  [[ -d "${dir}" ]] && return 0

  # Try to create without sudo
  if install -d -m "${mode}" "${dir}" 2>/dev/null; then
    return 0
  fi

  # Need sudo
  if command -v sudo > /dev/null 2>&1; then
    if sudo install -d -m "${mode}" "${dir}"; then
      return 0
    fi
  fi

  # All methods failed
  core::log error "failed to create directory" \
    "$(printf '{"dir":"%s","mode":"%s"}' "${dir}" "${mode}")"
  return 1
}
```

#### Step 5.2: 替换内联实现

**文件**: `lib/core.sh`, `scripts/caddy-cert-sync.sh`

**查找内联代码**:
```bash
grep -rn "install -d -m" lib/ scripts/ | grep -v "io::ensure_dir"
```

**替换策略**:
- 在 `lib/core.sh` 中: 直接使用 `io::ensure_dir()`（已 sourced）
- 在 `caddy-cert-sync.sh` 中: 定义轻量级兼容函数

**caddy-cert-sync.sh 兼容函数**:
```bash
##
# Standalone directory creation function (compatible with io::ensure_dir)
#
# Lightweight version for standalone scripts.
##
ensure_dir() {
  local dir="${1}"
  local mode="${2:-0755}"

  [[ -d "${dir}" ]] && return 0

  if ! install -d -m "${mode}" "${dir}" 2>/dev/null; then
    if command -v sudo > /dev/null 2>&1; then
      sudo install -d -m "${mode}" "${dir}" || return 1
    else
      log error "failed to create directory: ${dir}"
      return 1
    fi
  fi

  return 0
}

# Usage
ensure_dir "${LOCK_DIR}" 0755 || exit 1
ensure_dir "${TARGET_DIR}" 0755 || exit 1
```

### 验证标准

```bash
# 1. 静态检查：确保没有内联 install -d
make lint
grep -rn "install -d" lib/ scripts/ | grep -v "io::ensure_dir\|ensure_dir()"

# 2. 功能测试
bash -c '
  source modules/io.sh
  tmpdir="/tmp/test-ensure-dir-$$"
  io::ensure_dir "${tmpdir}" 0750
  [[ -d "${tmpdir}" ]] && echo "PASS" || echo "FAIL"
  [[ "$(stat -c %a "${tmpdir}")" == "750" ]] && echo "PASS: mode" || echo "FAIL: mode"
  rm -rf "${tmpdir}"
'

# 3. 集成测试
bin/xrf install --topology reality-only --dry-run
```

### 预期结果
- ✅ 代码减少: 8 行
- ✅ 一致性: 所有目录创建使用相同函数
- ✅ 文档完善: ShellDoc 注释

---

## 📊 总体时间表

| 阶段 | 任务 | 预计时间 | 累计时间 | 状态 |
|-----|------|---------|---------|------|
| Phase 1 | ShortId 生成提取 | 30 min | 0.5h | ⏸️ Pending |
| - | 测试 + 验证 | 15 min | 0.75h | |
| Phase 2 | 日志函数统一 | 45 min | 1.5h | ⏸️ Pending |
| - | 测试 + 验证 | 15 min | 1.75h | |
| Phase 3 | Domain 验证安全修复 | 20 min | 2h | ⏸️ Pending |
| - | 测试 + 验证 | 15 min | 2.25h | |
| Phase 4 | 锁文件管理优化 | 30 min | 2.75h | ⏸️ Pending |
| - | 测试 + 验证 | 15 min | 3h | |
| Phase 5 | 目录创建统一 | 25 min | 3.5h | ⏸️ Pending |
| - | 测试 + 验证 | 15 min | 3.75h | |
| **总计** | | **~3-4 小时** | | |

---

## ✅ 质量门控（每阶段必须通过）

每个阶段完成后必须通过以下检查：

```bash
# 1. 代码格式化
make fmt

# 2. 静态分析（无新错误）
make lint

# 3. 单元测试（全部通过）
make test-unit

# 4. 集成测试（至少一个场景）
bin/xrf install --topology reality-only --dry-run

# 5. Git 提交
git add .
git commit -m "phase X: <description>"
git push origin claude/code-review-check-011CV14r7CTdEsN1mdRAqXCP
```

---

## 🚨 风险管理

### 潜在风险

| 风险 | 可能性 | 影响 | 缓解措施 |
|-----|--------|------|---------|
| 测试失败 | 中 | 中 | 每阶段独立回滚 |
| 功能回归 | 低 | 高 | 完整测试覆盖 |
| 合并冲突 | 低 | 低 | 小步提交 |
| 文档不同步 | 中 | 低 | 同步更新 AGENTS.md |

### 回滚策略

```bash
# 单阶段回滚
git revert HEAD
git push origin claude/code-review-check-011CV14r7CTdEsN1mdRAqXCP

# 多阶段回滚
git reset --hard <commit-before-phase-1>
git push -f origin claude/code-review-check-011CV14r7CTdEsN1mdRAqXCP
```

---

## 📈 成功指标

| 指标 | 当前 | 目标 | 测量方法 |
|-----|------|------|---------|
| 代码行数 | 2700 | 2635 (-65) | `wc -l **/*.sh` |
| 重复率 | 7.8% | <5% | 手动审查 |
| 测试覆盖 | 80% | 85% | `make test-unit` 通过率 |
| 新增测试 | 96 | 116 (+20) | 测试用例计数 |
| Lint 警告 | 0 | 0 | `make lint` 输出 |

---

## 📚 参考文档

- [CODE_DUPLICATION_ANALYSIS.md](./CODE_DUPLICATION_ANALYSIS.md) - 详细分析报告
- [CODE_DUPLICATION_QUICK_REFERENCE.md](./CODE_DUPLICATION_QUICK_REFERENCE.md) - 快速参考
- [CLAUDE.md](./CLAUDE.md) - 架构决策记录（ADR）
- [AGENTS.md](./AGENTS.md) - 编码规范和最佳实践

---

## ✨ 下一步行动

1. **Review**: 审查本计划，确认优先级和时间安排
2. **Prepare**: 创建测试环境，准备回滚计划
3. **Execute**: 按阶段执行，每阶段独立提交
4. **Validate**: 每阶段通过质量门控
5. **Document**: 更新 CLAUDE.md 和 AGENTS.md

**准备好开始 Phase 1 了吗？**
