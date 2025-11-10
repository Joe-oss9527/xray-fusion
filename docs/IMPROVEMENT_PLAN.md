# xray-fusion 多阶段改进计划

> **制定日期**: 2025-11-10
> **基于**: Code Review 报告 v1.0
> **官方文档核对**: ✅ 已完成

## 📋 执行摘要

本计划分为 **4 个阶段**，共 **15 项改进任务**。优先修复安全和稳定性问题，然后逐步提升可维护性和文档质量。

**预计总工时**: 16-20 小时
**预计完成周期**: 2-3 周（假设每周投入 8-10 小时）

---

## 🎯 阶段概览

| 阶段 | 重点 | 任务数 | 工时 | 风险等级 |
|------|------|--------|------|----------|
| **Phase 1** | 安全修复 | 3 | 4-6h | 🔴 高 |
| **Phase 2** | 稳定性改进 | 4 | 5-7h | 🟡 中 |
| **Phase 3** | 可维护性提升 | 4 | 4-5h | 🟢 低 |
| **Phase 4** | 文档完善 | 4 | 3-4h | 🟢 低 |

---

## 🔴 Phase 1: 安全修复（高优先级）

**目标**: 修复所有安全相关的验证缺陷
**预计工时**: 4-6 小时
**风险评估**: 高（涉及输入验证，需充分测试）

### Task 1.1: 完善域名验证器

**文件**: `lib/validators.sh`
**问题**: 缺少 IPv6 私有地址和 RFC 6761 保留域名检测
**官方依据**:
- RFC 6761 (Special-Use Domain Names)
- RFC 4193 (IPv6 Unique Local Addresses)
- RFC 3927 (IPv4 Link-Local)

**实施步骤**:

1. **备份现有实现** (5 分钟)
   ```bash
   cp lib/validators.sh lib/validators.sh.backup
   ```

2. **修改 `validators::domain()` 函数** (30 分钟)

   在 `lib/validators.sh:53-58` 替换为：
   ```bash
   # Reject internal/private domains and special-use domain names

   # IPv4 私有地址 (RFC 1918 + RFC 3927)
   case "${domain}" in
     # Loopback and special addresses
     localhost | *.local | 127.* | 0.0.0.0)
       core::log debug "domain validation failed: loopback/local" "$(printf '{"domain":"%s"}' "${domain}")"
       return 1
       ;;
     # RFC 1918 private networks
     10.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].* | 192.168.*)
       core::log debug "domain validation failed: RFC 1918 private network" "$(printf '{"domain":"%s"}' "${domain}")"
       return 1
       ;;
     # RFC 3927 link-local
     169.254.*)
       core::log debug "domain validation failed: RFC 3927 link-local" "$(printf '{"domain":"%s"}' "${domain}")"
       return 1
       ;;
     # RFC 6761 special-use domain names
     *.test | *.invalid)
       core::log debug "domain validation failed: RFC 6761 special-use TLD" "$(printf '{"domain":"%s","rfc":"6761"}' "${domain}")"
       return 1
       ;;
   esac

   # IPv6 私有地址检测 (RFC 4193, RFC 4291)
   if [[ "${domain}" =~ ^::1$ ]] || \
      [[ "${domain}" =~ ^[fF][cCdD][0-9a-fA-F]{2}: ]] || \
      [[ "${domain}" =~ ^[fF][eE]80: ]]; then
     core::log debug "domain validation failed: IPv6 private/link-local" "$(printf '{"domain":"%s"}' "${domain}")"
     return 1
   fi

   return 0
   ```

3. **更新单元测试** (45 分钟)

   在 `tests/unit/test_validators.bats` 添加：
   ```bash
   # RFC 3927 link-local addresses
   @test "validators::domain - rejects 169.254.0.0/16 link-local" {
     run validators::domain "169.254.10.1"
     [ "$status" -eq 1 ]
   }

   # RFC 6761 special-use TLDs
   @test "validators::domain - rejects .test TLD (RFC 6761)" {
     run validators::domain "example.test"
     [ "$status" -eq 1 ]
   }

   @test "validators::domain - rejects .invalid TLD (RFC 6761)" {
     run validators::domain "foo.invalid"
     [ "$status" -eq 1 ]
   }

   # IPv6 loopback
   @test "validators::domain - rejects ::1 (IPv6 loopback)" {
     run validators::domain "::1"
     [ "$status" -eq 1 ]
   }

   # IPv6 unique local addresses (RFC 4193)
   @test "validators::domain - rejects fc00::/7 (IPv6 ULA)" {
     run validators::domain "fc00:1234:5678::1"
     [ "$status" -eq 1 ]

     run validators::domain "fd00:abcd:ef01::1"
     [ "$status" -eq 1 ]
   }

   # IPv6 link-local (RFC 4291)
   @test "validators::domain - rejects fe80::/10 (IPv6 link-local)" {
     run validators::domain "fe80::1"
     [ "$status" -eq 1 ]
   }
   ```

4. **运行测试验证** (15 分钟)
   ```bash
   make test-unit
   # 预期: 新增 6 个测试全部通过
   ```

5. **更新文档** (15 分钟)

   在 `AGENTS.md` 的"Domain Validation"部分添加：
   ```markdown
   ### Domain Validation (RFC Compliant + Extended)

   ```bash
   # ✅ validators::domain() 拒绝以下内容：
   # - RFC 1918 私有网络 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
   # - RFC 3927 链路本地地址 (169.254.0.0/16)
   # - RFC 6761 特殊用途域名 (.test, .invalid)
   # - IPv6 环回地址 (::1)
   # - IPv6 唯一本地地址 (fc00::/7 - RFC 4193)
   # - IPv6 链路本地地址 (fe80::/10 - RFC 4291)
   ```
   ```

**验收标准**:
- ✅ 所有新增测试通过
- ✅ 现有测试无回归
- ✅ ShellCheck 无新警告
- ✅ 文档已更新

**预计工时**: 2 小时

---

### Task 1.2: 修复 shortId 生成一致性

**文件**: `commands/install.sh`
**问题**: `hexdump` 格式字符串错误导致输出长度不一致
**官方依据**: Stack Overflow consensus - `xxd -p` 是最简单可靠的方案

**实施步骤**:

1. **定位代码位置** (5 分钟)

   文件: `commands/install.sh:84-88`

2. **修改生成逻辑** (15 分钟)

   替换为：
   ```bash
   # Generate shortIds pool (3-5 shortIds for multi-client scenarios)
   # Primary shortId (backward compatible)
   if [[ -z "${XRAY_SHORT_ID:-}" ]]; then
     # Prefer xxd (part of vim-common), fallback to od (POSIX standard)
     if command -v xxd >/dev/null 2>&1; then
       XRAY_SHORT_ID="$(head -c 8 /dev/urandom | xxd -p -c 16)"
     elif command -v od >/dev/null 2>&1; then
       XRAY_SHORT_ID="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
     else
       # Fallback to openssl (always available in this project)
       XRAY_SHORT_ID="$(openssl rand -hex 8)"
     fi
   fi

   # Additional shortIds for future client differentiation (optional)
   if [[ -z "${XRAY_SHORT_ID_2:-}" ]]; then
     if command -v xxd >/dev/null 2>&1; then
       XRAY_SHORT_ID_2="$(head -c 8 /dev/urandom | xxd -p -c 16)"
     elif command -v od >/dev/null 2>&1; then
       XRAY_SHORT_ID_2="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
     else
       XRAY_SHORT_ID_2="$(openssl rand -hex 8)"
     fi
   fi

   if [[ -z "${XRAY_SHORT_ID_3:-}" ]]; then
     if command -v xxd >/dev/null 2>&1; then
       XRAY_SHORT_ID_3="$(head -c 8 /dev/urandom | xxd -p -c 16)"
     elif command -v od >/dev/null 2>&1; then
       XRAY_SHORT_ID_3="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
     else
       XRAY_SHORT_ID_3="$(openssl rand -hex 8)"
     fi
   fi
   ```

3. **添加单元测试** (30 分钟)

   创建 `tests/unit/test_shortid_generation.bats`:
   ```bash
   #!/usr/bin/env bats
   # Unit tests for shortId generation

   load ../test_helper

   @test "shortId generation - xxd produces 16 hex characters" {
     if ! command -v xxd >/dev/null 2>&1; then
       skip "xxd not available"
     fi

     local sid
     sid="$(head -c 8 /dev/urandom | xxd -p -c 16)"

     # Should be exactly 16 characters
     [ "${#sid}" -eq 16 ]

     # Should be valid hex
     [[ "${sid}" =~ ^[0-9a-fA-F]{16}$ ]]
   }

   @test "shortId generation - od produces 16 hex characters" {
     local sid
     sid="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"

     # Should be exactly 16 characters
     [ "${#sid}" -eq 16 ]

     # Should be valid hex
     [[ "${sid}" =~ ^[0-9a-fA-F]{16}$ ]]
   }

   @test "shortId generation - openssl produces 16 hex characters" {
     local sid
     sid="$(openssl rand -hex 8)"

     # Should be exactly 16 characters
     [ "${#sid}" -eq 16 ]

     # Should be valid hex
     [[ "${sid}" =~ ^[0-9a-fA-F]{16}$ ]]
   }

   @test "shortId validation - all three methods pass validator" {
     # Load validators
     source "${HERE}/lib/validators.sh"

     # Test xxd
     if command -v xxd >/dev/null 2>&1; then
       local sid_xxd
       sid_xxd="$(head -c 8 /dev/urandom | xxd -p -c 16)"
       run validators::shortid "${sid_xxd}"
       [ "$status" -eq 0 ]
     fi

     # Test od
     local sid_od
     sid_od="$(head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n')"
     run validators::shortid "${sid_od}"
     [ "$status" -eq 0 ]

     # Test openssl
     local sid_ssl
     sid_ssl="$(openssl rand -hex 8)"
     run validators::shortid "${sid_ssl}"
     [ "$status" -eq 0 ]
   }
   ```

4. **运行测试** (10 分钟)
   ```bash
   bats tests/unit/test_shortid_generation.bats
   make test-unit
   ```

5. **更新 AGENTS.md** (10 分钟)

   添加到"Common Commands"部分：
   ```markdown
   ### ShortId Generation Best Practices

   ```bash
   # ✅ Preferred: xxd (part of vim-common, simple and reliable)
   head -c 8 /dev/urandom | xxd -p -c 16

   # ✅ Fallback: od (POSIX standard, maximum portability)
   head -c 8 /dev/urandom | od -An -tx1 -v | tr -d ' \n'

   # ✅ Fallback: openssl (always available in xray-fusion)
   openssl rand -hex 8

   # ❌ Avoid: hexdump (format string complexity,易错)
   ```
   ```

**验收标准**:
- ✅ 所有三种方法生成 16 字符十六进制字符串
- ✅ 通过 validators::shortid 验证
- ✅ 单元测试覆盖所有生成路径
- ✅ 文档已更新

**预计工时**: 1.5 小时

---

### Task 1.3: 修复证书同步锁文件管理

**文件**: `scripts/caddy-cert-sync.sh`
**问题**: 锁文件位置和权限管理不规范
**官方依据**: Systemd best practices - 使用 `/run/lock` (tmpfs) 或应用私有目录

**实施步骤**:

1. **分析现有问题** (10 分钟)

   当前代码 (caddy-cert-sync.sh:6-11):
   ```bash
   exec 200> /var/lock/caddy-cert-sync.lock
   if ! flock -n 200; then
     printf '...' >&2
     exit 0
   fi
   ```

   问题：
   - `/var/lock` 在某些发行版指向 `/run/lock`（tmpfs，重启清除）
   - 未处理 sudo/非sudo 混合运行场景
   - 未使用项目的 `core::with_flock` 模式

2. **重构锁文件管理** (45 分钟)

   在 `scripts/caddy-cert-sync.sh:6-11` 替换为：
   ```bash
   # 使用项目标准锁文件位置（持久化，不受重启影响）
   LOCK_FILE="/var/lib/xray-fusion/locks/caddy-cert-sync.lock"

   # 创建锁文件目录
   LOCK_DIR="$(dirname "${LOCK_FILE}")"
   if ! test -d "${LOCK_DIR}"; then
     if ! mkdir -p "${LOCK_DIR}" 2>/dev/null; then
       if command -v sudo >/dev/null 2>&1; then
         sudo mkdir -p "${LOCK_DIR}" || {
           printf '[%s] %-5s [caddy-cert-sync] failed to create lock directory\n' \
             "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
           exit 1
         }
       else
         printf '[%s] %-5s [caddy-cert-sync] cannot create lock directory (no sudo)\n' \
           "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
         exit 1
       fi
     fi
   fi

   # 原子创建锁文件（参考 lib/core.sh:73-90）
   if ! test -f "${LOCK_FILE}" 2>/dev/null; then
     # 尝试使用 install(1) 原子创建（防止 TOCTOU）
     if ! install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${LOCK_FILE}" 2>/dev/null; then
       # Fallback to sudo
       if command -v sudo >/dev/null 2>&1; then
         sudo install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${LOCK_FILE}" 2>/dev/null || {
           printf '[%s] %-5s [caddy-cert-sync] failed to create lock file\n' \
             "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
           exit 1
         }
       else
         # 最后手段：创建但权限可能不正确
         touch "${LOCK_FILE}" 2>/dev/null || {
           printf '[%s] %-5s [caddy-cert-sync] cannot create lock file\n' \
             "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "error" >&2
           exit 1
         }
       fi
     fi
   else
     # 锁文件已存在，修复所有权（处理之前 root 运行的情况）
     if ! chown "$(id -u):$(id -g)" "${LOCK_FILE}" 2>/dev/null; then
       if command -v sudo >/dev/null 2>&1; then
         sudo chown "$(id -u):$(id -g)" "${LOCK_FILE}" 2>/dev/null || true
       fi
     fi
     # 修复权限
     if ! chmod 0644 "${LOCK_FILE}" 2>/dev/null; then
       if command -v sudo >/dev/null 2>&1; then
         sudo chmod 0644 "${LOCK_FILE}" 2>/dev/null || true
       fi
     fi
   fi

   # 非阻塞加锁
   exec 200>> "${LOCK_FILE}"
   if ! flock -n 200; then
     # 使用 log() 函数（在脚本后面定义）
     printf '[%s] %-5s [caddy-cert-sync] another sync process is running, skipping\n' \
       "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "info" >&2
     exit 0
   fi
   ```

3. **添加集成测试** (30 分钟)

   创建 `tests/integration/test_cert_sync_concurrency.bats`:
   ```bash
   #!/usr/bin/env bats
   # Integration test for certificate sync concurrency

   load ../test_helper

   setup() {
     # 创建测试环境
     export TEST_LOCK_DIR="${BATS_TEST_TMPDIR}/locks"
     mkdir -p "${TEST_LOCK_DIR}"

     # 模拟证书同步脚本（简化版）
     cat > "${BATS_TEST_TMPDIR}/test-sync.sh" << 'EOF'
   #!/usr/bin/env bash
   set -euo pipefail

   LOCK_FILE="${1}"
   LOCK_DIR="$(dirname "${LOCK_FILE}")"
   mkdir -p "${LOCK_DIR}"

   if ! test -f "${LOCK_FILE}"; then
     install -m 0644 -o "$(id -u)" -g "$(id -g)" /dev/null "${LOCK_FILE}" 2>/dev/null || touch "${LOCK_FILE}"
   fi

   exec 200>> "${LOCK_FILE}"
   if ! flock -n 200; then
     echo "LOCKED"
     exit 0
   fi

   echo "ACQUIRED"
   sleep 2  # Simulate work
   EOF
     chmod +x "${BATS_TEST_TMPDIR}/test-sync.sh"
   }

   @test "cert-sync - concurrent runs are mutually exclusive" {
     local lock_file="${TEST_LOCK_DIR}/test.lock"

     # 启动第一个实例（后台）
     "${BATS_TEST_TMPDIR}/test-sync.sh" "${lock_file}" > "${BATS_TEST_TMPDIR}/output1.txt" &
     local pid1=$!

     # 等待第一个实例获取锁
     sleep 0.5

     # 启动第二个实例
     run "${BATS_TEST_TMPDIR}/test-sync.sh" "${lock_file}"
     [ "$status" -eq 0 ]
     [ "$output" = "LOCKED" ]

     # 等待第一个实例完成
     wait "${pid1}"

     # 验证第一个实例成功获取锁
     local output1
     output1="$(cat "${BATS_TEST_TMPDIR}/output1.txt")"
     [ "${output1}" = "ACQUIRED" ]
   }

   @test "cert-sync - lock file has correct permissions" {
     local lock_file="${TEST_LOCK_DIR}/test-perms.lock"

     "${BATS_TEST_TMPDIR}/test-sync.sh" "${lock_file}" >/dev/null

     # 验证文件存在
     [ -f "${lock_file}" ]

     # 验证权限为 0644
     local perms
     perms="$(stat -c '%a' "${lock_file}")"
     [ "${perms}" = "644" ]

     # 验证所有者
     local owner
     owner="$(stat -c '%u' "${lock_file}")"
     [ "${owner}" = "$(id -u)" ]
   }
   ```

4. **运行测试** (15 分钟)
   ```bash
   bats tests/integration/test_cert_sync_concurrency.bats
   ```

5. **更新 ADR** (10 分钟)

   在 `CLAUDE.md` 的 ADR-006 后添加：
   ```markdown
   ---

   ### ADR-010: 统一锁文件管理（2025-11-10）
   **问题**: caddy-cert-sync 锁文件与 core::with_flock 模式不一致

   **决策**: 采用 `/var/lib/xray-fusion/locks/` 作为锁文件目录

   **理由**:
   - 持久化存储：不受系统重启影响（vs `/run/lock` tmpfs）
   - 权限隔离：应用专用目录，避免与系统锁文件冲突
   - 一致性：所有脚本使用相同的锁文件管理模式
   - 安全性：使用 `install(1)` 原子创建（防止 TOCTOU）
   - 兼容性：正确处理 sudo/非sudo 混合运行场景

   **影响**:
   - 锁文件位置从 `/var/lock/` 迁移到 `/var/lib/xray-fusion/locks/`
   - 所有锁文件操作统一使用 `install(1)` + 权限修复模式
   - 可处理混合权限运行环境（重要：防止权限冲突）
   ```

**验收标准**:
- ✅ 并发测试通过
- ✅ 权限测试通过
- ✅ 混合 sudo/非sudo 运行无权限错误
- ✅ ADR 已更新

**预计工时**: 2 小时

---

## 🟡 Phase 2: 稳定性改进（中优先级）

**目标**: 提升代码稳定性和错误处理能力
**预计工时**: 5-7 小时
**风险评估**: 中（需要确保向后兼容）

### Task 2.1: 创建集中配置管理

**文件**: 新建 `lib/defaults.sh`
**问题**: 默认配置值分散在多个文件中
**优势**: 单一修改点，便于维护和测试覆盖

**实施步骤**:

1. **创建配置文件** (30 分钟)

   创建 `lib/defaults.sh`:
   ```bash
   #!/usr/bin/env bash
   # Default configuration values for xray-fusion
   # This file provides centralized configuration management
   # Override via environment variables or command-line arguments

   # === Topology Defaults ===
   readonly DEFAULT_TOPOLOGY="reality-only"

   # === Port Defaults ===
   readonly DEFAULT_XRAY_PORT=443
   readonly DEFAULT_XRAY_VISION_PORT=8443
   readonly DEFAULT_XRAY_REALITY_PORT=443
   readonly DEFAULT_XRAY_FALLBACK_PORT=8080

   # === Certificate Defaults ===
   readonly DEFAULT_CADDY_CERT_BASE="/root/.local/share/caddy/certificates"
   readonly DEFAULT_XRAY_CERT_DIR="/usr/local/etc/xray/certs"

   # === Reality Protocol Defaults ===
   readonly DEFAULT_XRAY_SNI="www.microsoft.com"
   readonly DEFAULT_XRAY_SNIFFING="false"

   # === Logging Defaults ===
   readonly DEFAULT_XRAY_LOG_LEVEL="warning"
   readonly DEFAULT_XRF_DEBUG="false"
   readonly DEFAULT_XRF_JSON="false"

   # === Version Defaults ===
   readonly DEFAULT_VERSION="latest"

   # === Path Defaults (可通过环境变量覆盖) ===
   defaults::xrf_prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
   defaults::xrf_etc() { echo "${XRF_ETC:-/usr/local/etc}"; }
   defaults::xrf_var() { echo "${XRF_VAR:-/var/lib/xray-fusion}"; }
   defaults::xrf_lock_dir() { echo "$(defaults::xrf_var)/locks"; }

   # === Helper: Get value with fallback ===
   defaults::get() {
     local key="${1}"
     local default_var="DEFAULT_${key}"
     local env_value="${!key:-}"

     if [[ -n "${env_value}" ]]; then
       echo "${env_value}"
     else
       echo "${!default_var:-}"
     fi
   }
   ```

2. **重构现有代码** (90 分钟)

   修改以下文件以使用集中配置：

   **lib/args.sh:12**:
   ```bash
   # 旧代码：
   TOPOLOGY="reality-only"

   # 新代码：
   . "${HERE}/lib/defaults.sh"
   TOPOLOGY="${DEFAULT_TOPOLOGY}"
   ```

   **commands/install.sh:68-73**:
   ```bash
   # 旧代码：
   : "${XRAY_VISION_PORT:=8443}"
   : "${XRAY_REALITY_PORT:=443}"
   : "${XRAY_CERT_DIR:=/usr/local/etc/xray/certs}"
   : "${XRAY_FALLBACK_PORT:=8080}"
   : "${XRAY_PORT:=443}"

   # 新代码：
   . "${HERE}/lib/defaults.sh"
   : "${XRAY_VISION_PORT:=${DEFAULT_XRAY_VISION_PORT}}"
   : "${XRAY_REALITY_PORT:=${DEFAULT_XRAY_REALITY_PORT}}"
   : "${XRAY_CERT_DIR:=${DEFAULT_XRAY_CERT_DIR}}"
   : "${XRAY_FALLBACK_PORT:=${DEFAULT_XRAY_FALLBACK_PORT}}"
   : "${XRAY_PORT:=${DEFAULT_XRAY_PORT}}"
   ```

   **scripts/caddy-cert-sync.sh:14**:
   ```bash
   # 在文件头部添加：
   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
   . "${HERE}/lib/defaults.sh" 2>/dev/null || true

   # 旧代码：
   CADDY_CERT_BASE="/root/.local/share/caddy/certificates"

   # 新代码：
   CADDY_CERT_BASE="${CADDY_CERT_BASE:-${DEFAULT_CADDY_CERT_BASE}}"
   ```

3. **添加单元测试** (30 分钟)

   创建 `tests/unit/test_defaults.bats`:
   ```bash
   #!/usr/bin/env bats
   # Unit tests for defaults.sh

   load ../test_helper

   setup() {
     setup_test_env
     source "${HERE}/lib/defaults.sh"
   }

   @test "defaults - topology default is reality-only" {
     [ "${DEFAULT_TOPOLOGY}" = "reality-only" ]
   }

   @test "defaults - port values are correct" {
     [ "${DEFAULT_XRAY_PORT}" = "443" ]
     [ "${DEFAULT_XRAY_VISION_PORT}" = "8443" ]
     [ "${DEFAULT_XRAY_REALITY_PORT}" = "443" ]
     [ "${DEFAULT_XRAY_FALLBACK_PORT}" = "8080" ]
   }

   @test "defaults - certificate paths are correct" {
     [ "${DEFAULT_CADDY_CERT_BASE}" = "/root/.local/share/caddy/certificates" ]
     [ "${DEFAULT_XRAY_CERT_DIR}" = "/usr/local/etc/xray/certs" ]
   }

   @test "defaults::get - returns env value if set" {
     export XRAY_PORT="8443"
     result="$(defaults::get XRAY_PORT)"
     [ "${result}" = "8443" ]
   }

   @test "defaults::get - returns default if env not set" {
     unset XRAY_PORT
     result="$(defaults::get XRAY_PORT)"
     [ "${result}" = "443" ]
   }

   @test "defaults - XRF_PREFIX override works" {
     export XRF_PREFIX="/custom/prefix"
     result="$(defaults::xrf_prefix)"
     [ "${result}" = "/custom/prefix" ]
   }
   ```

4. **运行测试** (15 分钟)
   ```bash
   make test-unit
   ```

5. **更新文档** (15 分钟)

   在 `AGENTS.md` 添加新章节：
   ```markdown
   ## Configuration Management

   ### Centralized Defaults (lib/defaults.sh)

   All default configuration values are defined in `lib/defaults.sh`:

   ```bash
   # Override via environment variables
   export XRAY_PORT=8443
   bin/xrf install --topology reality-only

   # Override via arguments (preferred)
   bin/xrf install --topology reality-only --domain custom.com
   ```

   ### Testing with Custom Defaults

   ```bash
   # Override paths for testing
   export XRF_PREFIX="${PWD}/tmp/prefix"
   export XRF_ETC="${PWD}/tmp/etc"
   export XRF_VAR="${PWD}/tmp/var"

   bin/xrf install --topology reality-only
   ```
   ```

**验收标准**:
- ✅ 所有默认值集中在 `lib/defaults.sh`
- ✅ 现有功能无回归
- ✅ 单元测试覆盖所有默认值
- ✅ 环境变量覆盖正常工作

**预计工时**: 3 小时

---

### Task 2.2: 定义错误代码常量

**文件**: 新建 `lib/errors.sh`
**问题**: 错误返回码不一致，难以理解
**优势**: 统一错误处理，便于调试和文档化

**实施步骤**:

1. **创建错误代码文件** (20 分钟)

   创建 `lib/errors.sh`:
   ```bash
   #!/usr/bin/env bash
   # Error code definitions for xray-fusion
   # Provides consistent error handling across all scripts

   # === Success ===
   readonly ERR_SUCCESS=0

   # === General Errors (1-9) ===
   readonly ERR_GENERAL=1          # General failure
   readonly ERR_INVALID_ARG=2      # Invalid argument
   readonly ERR_NOT_FOUND=3        # Resource not found
   readonly ERR_PERMISSION=4       # Permission denied
   readonly ERR_CONFIG=5           # Configuration error
   readonly ERR_NETWORK=6          # Network error
   readonly ERR_TIMEOUT=7          # Operation timeout

   # === Special Return Codes (10-19) ===
   readonly ERR_HELP_REQUESTED=10  # --help flag (not an error)

   # === Validation Errors (20-29) ===
   readonly ERR_INVALID_DOMAIN=20     # Domain validation failed
   readonly ERR_INVALID_PORT=21       # Port validation failed
   readonly ERR_INVALID_UUID=22       # UUID validation failed
   readonly ERR_INVALID_SHORTID=23    # shortId validation failed
   readonly ERR_INVALID_VERSION=24    # Version validation failed
   readonly ERR_INVALID_TOPOLOGY=25   # Topology validation failed

   # === Plugin Errors (30-39) ===
   readonly ERR_PLUGIN_NOT_FOUND=30   # Plugin does not exist
   readonly ERR_PLUGIN_LOAD_FAIL=31   # Plugin failed to load
   readonly ERR_PLUGIN_HOOK_FAIL=32   # Plugin hook execution failed

   # === Service Errors (40-49) ===
   readonly ERR_SERVICE_START_FAIL=40  # Service failed to start
   readonly ERR_SERVICE_STOP_FAIL=41   # Service failed to stop
   readonly ERR_SERVICE_NOT_FOUND=42   # Service not found

   # === File Operation Errors (50-59) ===
   readonly ERR_FILE_NOT_FOUND=50     # File does not exist
   readonly ERR_FILE_READ_FAIL=51     # Cannot read file
   readonly ERR_FILE_WRITE_FAIL=52    # Cannot write file
   readonly ERR_DIR_CREATE_FAIL=53    # Cannot create directory

   # === Helper: Get error message ===
   errors::message() {
     local code="${1}"
     case "${code}" in
       ${ERR_SUCCESS}) echo "Success" ;;
       ${ERR_GENERAL}) echo "General failure" ;;
       ${ERR_INVALID_ARG}) echo "Invalid argument" ;;
       ${ERR_NOT_FOUND}) echo "Resource not found" ;;
       ${ERR_PERMISSION}) echo "Permission denied" ;;
       ${ERR_CONFIG}) echo "Configuration error" ;;
       ${ERR_NETWORK}) echo "Network error" ;;
       ${ERR_TIMEOUT}) echo "Operation timeout" ;;
       ${ERR_HELP_REQUESTED}) echo "Help requested" ;;
       ${ERR_INVALID_DOMAIN}) echo "Invalid domain" ;;
       ${ERR_INVALID_PORT}) echo "Invalid port" ;;
       ${ERR_INVALID_UUID}) echo "Invalid UUID" ;;
       ${ERR_INVALID_SHORTID}) echo "Invalid shortId" ;;
       ${ERR_INVALID_VERSION}) echo "Invalid version" ;;
       ${ERR_INVALID_TOPOLOGY}) echo "Invalid topology" ;;
       ${ERR_PLUGIN_NOT_FOUND}) echo "Plugin not found" ;;
       ${ERR_PLUGIN_LOAD_FAIL}) echo "Plugin load failed" ;;
       ${ERR_PLUGIN_HOOK_FAIL}) echo "Plugin hook failed" ;;
       ${ERR_SERVICE_START_FAIL}) echo "Service start failed" ;;
       ${ERR_SERVICE_STOP_FAIL}) echo "Service stop failed" ;;
       ${ERR_SERVICE_NOT_FOUND}) echo "Service not found" ;;
       ${ERR_FILE_NOT_FOUND}) echo "File not found" ;;
       ${ERR_FILE_READ_FAIL}) echo "File read failed" ;;
       ${ERR_FILE_WRITE_FAIL}) echo "File write failed" ;;
       ${ERR_DIR_CREATE_FAIL}) echo "Directory creation failed" ;;
       *) echo "Unknown error (${code})" ;;
     esac
   }

   # === Helper: Exit with error code and message ===
   errors::exit() {
     local code="${1}"
     shift || true
     local msg="${1:-$(errors::message "${code}")}"

     if [[ -n "${msg}" ]]; then
       core::log error "${msg}" "$(printf '{"exit_code":%d}' "${code}")"
     fi

     exit "${code}"
   }
   ```

2. **重构现有代码** (60 分钟)

   修改以下文件：

   **lib/args.sh:47**:
   ```bash
   # 旧代码：
   --help | -h)
     return 10

   # 新代码：
   . "${HERE}/lib/errors.sh"
   --help | -h)
     return ${ERR_HELP_REQUESTED}
   ```

   **lib/plugins.sh:127**:
   ```bash
   # 旧代码：
   if [[ ! -f "${src}" ]]; then
     echo "plugin not found: ${id}" >&2
     return 2
   fi

   # 新代码：
   . "${HERE}/lib/errors.sh"
   if [[ ! -f "${src}" ]]; then
     echo "plugin not found: ${id}" >&2
     return ${ERR_PLUGIN_NOT_FOUND}
   fi
   ```

   **services/xray/configure.sh:96,215**:
   ```bash
   # 旧代码：
   core::log error "XRAY_PRIVATE_KEY required"
   exit 2

   # 新代码：
   . "${HERE}/lib/errors.sh"
   errors::exit ${ERR_CONFIG} "XRAY_PRIVATE_KEY required"
   ```

3. **添加单元测试** (30 分钟)

   创建 `tests/unit/test_errors.bats`:
   ```bash
   #!/usr/bin/env bats
   # Unit tests for errors.sh

   load ../test_helper

   setup() {
     setup_test_env
     source "${HERE}/lib/errors.sh"
   }

   @test "errors - all error codes are defined" {
     [ "${ERR_SUCCESS}" = "0" ]
     [ "${ERR_GENERAL}" = "1" ]
     [ "${ERR_INVALID_ARG}" = "2" ]
     [ "${ERR_HELP_REQUESTED}" = "10" ]
     [ "${ERR_INVALID_DOMAIN}" = "20" ]
     [ "${ERR_PLUGIN_NOT_FOUND}" = "30" ]
   }

   @test "errors::message - returns correct message" {
     result="$(errors::message ${ERR_SUCCESS})"
     [ "${result}" = "Success" ]

     result="$(errors::message ${ERR_INVALID_ARG})"
     [ "${result}" = "Invalid argument" ]

     result="$(errors::message ${ERR_PLUGIN_NOT_FOUND})"
     [ "${result}" = "Plugin not found" ]
   }

   @test "errors::message - handles unknown code" {
     result="$(errors::message 999)"
     [[ "${result}" == *"Unknown error"* ]]
   }
   ```

4. **运行测试** (10 分钟)
   ```bash
   make test-unit
   ```

5. **更新文档** (10 分钟)

   在 `AGENTS.md` 添加：
   ```markdown
   ## Error Handling

   ### Error Codes (lib/errors.sh)

   All error codes are centrally defined:

   | Range | Category | Examples |
   |-------|----------|----------|
   | 0 | Success | ERR_SUCCESS |
   | 1-9 | General | ERR_GENERAL, ERR_INVALID_ARG |
   | 10-19 | Special | ERR_HELP_REQUESTED |
   | 20-29 | Validation | ERR_INVALID_DOMAIN |
   | 30-39 | Plugin | ERR_PLUGIN_NOT_FOUND |
   | 40-49 | Service | ERR_SERVICE_START_FAIL |
   | 50-59 | File | ERR_FILE_NOT_FOUND |

   ### Usage

   ```bash
   # Source error definitions
   . "${HERE}/lib/errors.sh"

   # Return error code
   return ${ERR_INVALID_ARG}

   # Exit with error and message
   errors::exit ${ERR_CONFIG} "Custom error message"
   ```
   ```

**验收标准**:
- ✅ 所有错误码集中定义
- ✅ 现有功能无回归
- ✅ 单元测试覆盖
- ✅ 文档已更新

**预计工时**: 2 小时

---

### Task 2.3: 增强路径验证

**文件**: `services/xray/configure.sh`
**问题**: 路径验证正则表达式过于宽松
**风险**: 低（不会真正导致路径遍历，但不符合防御性编程原则）

**实施步骤**:

1. **修改路径验证** (15 分钟)

   在 `services/xray/configure.sh:236-239` 替换为：
   ```bash
   # Security: Validate directory path to prevent injection attacks
   # - Must be absolute path (starts with /)
   # - No parent directory references (..)
   # - No consecutive slashes
   # - Only alphanumeric, underscore, hyphen, dot, slash
   if [[ ! "${release_dir}" =~ ^/([a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+$ ]] || \
      [[ "${release_dir}" == *".."* ]] || \
      [[ "${release_dir}" == *"//"* ]]; then
     core::log error "invalid directory path" "$(printf '{"path":"%s","reason":"path validation failed"}' "${release_dir//\"/\\\"}")"
     return ${ERR_INVALID_ARG}
   fi
   ```

2. **添加测试** (30 分钟)

   在 `tests/unit/test_xray_paths.bats` 添加：
   ```bash
   @test "path validation - rejects parent directory reference" {
     # 模拟 deploy_release 的验证逻辑
     local test_path="/valid/path/../etc"

     if [[ "${test_path}" == *".."* ]]; then
       result="rejected"
     else
       result="accepted"
     fi

     [ "${result}" = "rejected" ]
   }

   @test "path validation - rejects consecutive slashes" {
     local test_path="/valid//path"

     if [[ "${test_path}" == *"//"* ]]; then
       result="rejected"
     else
       result="accepted"
     fi

     [ "${result}" = "rejected" ]
   }

   @test "path validation - accepts valid absolute path" {
     local test_path="/usr/local/etc/xray/releases/20251110"

     if [[ "${test_path}" =~ ^/([a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+$ ]] && \
        [[ "${test_path}" != *".."* ]] && \
        [[ "${test_path}" != *"//"* ]]; then
       result="accepted"
     else
       result="rejected"
     fi

     [ "${result}" = "accepted" ]
   }
   ```

3. **运行测试** (5 分钟)
   ```bash
   make test-unit
   ```

**验收标准**:
- ✅ 拒绝包含 `..` 的路径
- ✅ 拒绝包含 `//` 的路径
- ✅ 接受合法的绝对路径
- ✅ 测试覆盖边界条件

**预计工时**: 1 小时

---

### Task 2.4: 实现基础集成测试

**文件**: 新建 `tests/integration/` 目录
**问题**: 缺少端到端测试
**优势**: 捕获跨模块交互问题

**实施步骤**:

1. **创建集成测试框架** (30 分钟)

   创建 `tests/integration/test_helper.bash`:
   ```bash
   #!/usr/bin/env bash
   # Integration test helper

   # Setup isolated test environment
   setup_integration_env() {
     export TEST_ROOT="${BATS_TEST_TMPDIR}/xrf-integration"
     export XRF_PREFIX="${TEST_ROOT}/prefix"
     export XRF_ETC="${TEST_ROOT}/etc"
     export XRF_VAR="${TEST_ROOT}/var"

     mkdir -p "${XRF_PREFIX}" "${XRF_ETC}" "${XRF_VAR}"

     # Mock systemctl for testing
     export PATH="${TEST_ROOT}/bin:${PATH}"
     mkdir -p "${TEST_ROOT}/bin"
     cat > "${TEST_ROOT}/bin/systemctl" << 'EOF'
   #!/usr/bin/env bash
   echo "systemctl $*" >> "${XRF_VAR}/systemctl.log"
   exit 0
   EOF
     chmod +x "${TEST_ROOT}/bin/systemctl"
   }

   cleanup_integration_env() {
     rm -rf "${TEST_ROOT}" 2>/dev/null || true
   }
   ```

2. **创建安装流程集成测试** (60 分钟)

   创建 `tests/integration/test_install_flow.bats`:
   ```bash
   #!/usr/bin/env bats
   # Integration test for install flow

   load test_helper

   setup() {
     setup_integration_env
   }

   teardown() {
     cleanup_integration_env
   }

   @test "install flow - reality-only topology completes successfully" {
     skip "Requires xray binary - implement in CI environment"

     run bin/xrf install --topology reality-only
     [ "$status" -eq 0 ]

     # Verify configuration files created
     [ -d "${XRF_ETC}/xray/releases" ]

     # Verify state saved
     [ -f "${XRF_VAR}/state.json" ]

     # Verify systemctl called
     [ -f "${XRF_VAR}/systemctl.log" ]
     grep -q "enable --now xray" "${XRF_VAR}/systemctl.log"
   }

   @test "install flow - vision-reality requires domain" {
     run bin/xrf install --topology vision-reality
     [ "$status" -ne 0 ]
     [[ "$output" == *"requires domain"* ]]
   }

   @test "install flow - invalid topology rejected" {
     run bin/xrf install --topology invalid-topo
     [ "$status" -ne 0 ]
     [[ "$output" == *"invalid topology"* ]]
   }
   ```

3. **创建插件系统集成测试** (45 分钟)

   创建 `tests/integration/test_plugin_system.bats`:
   ```bash
   #!/usr/bin/env bats
   # Integration test for plugin system

   load test_helper

   setup() {
     setup_integration_env
     export HERE="${BATS_TEST_DIRNAME}/../.."
   }

   @test "plugin system - enable and load plugin" {
     run bin/xrf plugin enable firewall
     [ "$status" -eq 0 ]

     # Verify symlink created
     [ -L "${HERE}/plugins/enabled/firewall.sh" ]

     # Verify plugin info works
     run bin/xrf plugin info firewall
     [ "$status" -eq 0 ]
     [[ "$output" == *"firewall"* ]]
   }

   @test "plugin system - disable plugin" {
     bin/xrf plugin enable logrotate-obs

     run bin/xrf plugin disable logrotate-obs
     [ "$status" -eq 0 ]

     # Verify symlink removed
     [ ! -e "${HERE}/plugins/enabled/logrotate-obs.sh" ]
   }

   @test "plugin system - invalid plugin rejected" {
     run bin/xrf plugin enable nonexistent-plugin
     [ "$status" -ne 0 ]
     [[ "$output" == *"not found"* ]]
   }
   ```

4. **更新 Makefile** (10 分钟)

   修改 `Makefile`:
   ```makefile
   test-integration: ## Run integration tests
   	@echo "Running integration tests..."
   	bats tests/integration/*.bats

   test: test-unit test-integration ## Run all tests
   ```

5. **更新 CI 工作流** (15 分钟)

   修改 `.github/workflows/test.yml`:
   ```yaml
   integration-tests:
     runs-on: ubuntu-latest
     if: github.event_name == 'pull_request'
     steps:
       - uses: actions/checkout@v4
       - name: Install dependencies
         run: |
           sudo apt-get update
           sudo apt-get install -y bats jq

       - name: Run integration tests
         run: make test-integration
   ```

**验收标准**:
- ✅ 集成测试框架可运行
- ✅ 安装流程测试通过
- ✅ 插件系统测试通过
- ✅ CI 集成完成

**预计工时**: 2.5 小时

---

## 🟢 Phase 3: 可维护性提升（低优先级）

**目标**: 提升代码可读性和维护效率
**预计工时**: 4-5 小时
**风险评估**: 低

### Task 3.1: 添加 ShellDoc 风格 API 文档

**文件**: 所有 `lib/` 和 `modules/` 文件
**问题**: 函数缺少标准化文档注释
**优势**: 便于开发者理解函数用途和参数

**实施步骤**:

1. **定义文档模板** (15 分钟)

   在 `AGENTS.md` 添加：
   ```markdown
   ## Function Documentation Standard

   All public functions must include ShellDoc-style comments:

   ```bash
   ##
   # Brief one-line description of the function
   #
   # Detailed description (optional, multiple lines)
   #
   # Arguments:
   #   $1 - Parameter name (type, required/optional, description)
   #   $2 - Parameter name (type, required/optional, default: value)
   #
   # Input:
   #   Description of stdin input (if applicable)
   #
   # Output:
   #   Description of stdout output
   #
   # Returns:
   #   0 - Success description
   #   1 - Error description
   #   2 - Another error description
   #
   # Security:
   #   Security considerations (CWE references, etc.)
   #
   # Example:
   #   function_name arg1 arg2
   ##
   function_name() {
     # implementation
   }
   ```
   ```

2. **为核心函数添加文档** (120 分钟)

   示例 - `lib/core.sh`:
   ```bash
   ##
   # Initialize strict mode and parse global flags
   #
   # Sets up bash strict mode (set -euo pipefail -E) and parses
   # global flags like --json and --debug. Must be called at the
   # start of every main script.
   #
   # Arguments:
   #   $@ - Command-line arguments (optional)
   #
   # Globals:
   #   XRF_JSON - Set to true if --json flag present
   #   XRF_DEBUG - Set to true if --debug flag present
   #
   # Returns:
   #   0 - Always succeeds
   #
   # Example:
   #   core::init "${@}"
   ##
   core::init() {
     # ... existing implementation ...
   }

   ##
   # Structured logging to stderr
   #
   # Logs messages in text or JSON format depending on XRF_JSON.
   # All output goes to stderr to avoid contaminating function
   # return values. Debug messages are filtered unless XRF_DEBUG=true.
   #
   # Arguments:
   #   $1 - Log level (string, required) - debug|info|warn|error
   #   $2 - Message (string, required)
   #   $3 - Context JSON (string, optional, default: "{}")
   #
   # Output:
   #   Log line to stderr (text or JSON format)
   #
   # Returns:
   #   0 - Always succeeds (or returns early for filtered debug)
   #
   # Example:
   #   core::log info "Operation completed" '{"duration_ms":123}'
   #   core::log error "Failed to read file" "$(printf '{"file":"%s"}' "${path}")"
   ##
   core::log() {
     # ... existing implementation ...
   }

   ##
   # Retry command with exponential backoff
   #
   # Executes a command up to max_attempts times, with exponentially
   # increasing delays between attempts (1s, 4s, 9s, 16s, ...).
   #
   # Arguments:
   #   $1 - Maximum attempts (number, optional, default: 3)
   #   $@ - Command and arguments to execute (required)
   #
   # Returns:
   #   0 - Command succeeded within max_attempts
   #   1 - All attempts failed
   #
   # Example:
   #   core::retry 5 curl -fsSL https://example.com/file
   #   core::retry wget -O /tmp/file https://example.com/file
   ##
   core::retry() {
     # ... existing implementation ...
   }

   ##
   # Execute command with exclusive file lock
   #
   # Acquires a file-based lock before executing the command,
   # ensuring mutual exclusion. Handles sudo/non-sudo mixed
   # scenarios by fixing ownership and permissions atomically.
   #
   # Arguments:
   #   $1 - Lock file path (string, required)
   #   $@ - Command and arguments to execute (required)
   #
   # Returns:
   #   0 - Command succeeded
   #   1 - Lock acquisition failed or command failed
   #   2 - Missing command argument
   #
   # Security:
   #   - Uses install(1) for atomic file creation (prevents TOCTOU - CWE-362)
   #   - Fixes ownership to current user (handles sudo remnants - CWE-283)
   #   - Executes in subshell to release lock automatically
   #
   # Example:
   #   core::with_flock "/var/lib/app/locks/deploy.lock" deploy_function arg1 arg2
   ##
   core::with_flock() {
     # ... existing implementation ...
   }
   ```

   类似方式为以下文件添加文档：
   - `lib/args.sh` (所有 `args::*` 函数)
   - `lib/validators.sh` (所有 `validators::*` 函数)
   - `lib/plugins.sh` (所有 `plugins::*` 函数)
   - `modules/io.sh` (所有 `io::*` 函数)
   - `modules/state.sh` (所有 `state::*` 函数)

3. **生成 API 参考文档** (30 分钟)

   创建脚本 `scripts/generate-api-docs.sh`:
   ```bash
   #!/usr/bin/env bash
   # Generate API documentation from ShellDoc comments
   set -euo pipefail

   OUTPUT_FILE="docs/API_REFERENCE.md"

   cat > "${OUTPUT_FILE}" << 'EOF'
   # API Reference

   > Auto-generated from ShellDoc comments
   > Last updated: $(date -u +%Y-%m-%d)

   This document provides API reference for all public functions in xray-fusion.

   ---

   EOF

   # Extract ShellDoc comments from all lib/ and modules/ files
   for file in lib/*.sh modules/*.sh modules/*/*.sh; do
     [[ -f "${file}" ]] || continue

     echo "## $(basename "${file}")" >> "${OUTPUT_FILE}"
     echo "" >> "${OUTPUT_FILE}"

     # Extract ##...## blocks
     awk '/^##$/{flag=1; next} /^##$/{flag=0} flag{sub(/^# ?/, ""); print}' "${file}" >> "${OUTPUT_FILE}"

     echo "" >> "${OUTPUT_FILE}"
   done

   echo "API documentation generated: ${OUTPUT_FILE}"
   ```

   运行生成：
   ```bash
   chmod +x scripts/generate-api-docs.sh
   ./scripts/generate-api-docs.sh
   ```

4. **更新开发工作流** (10 分钟)

   在 `Makefile` 添加：
   ```makefile
   docs: ## Generate API documentation
   	@echo "Generating API documentation..."
   	./scripts/generate-api-docs.sh
   ```

**验收标准**:
- ✅ 所有公共函数有 ShellDoc 注释
- ✅ API 参考文档自动生成
- ✅ 文档包含参数、返回值、安全考虑、示例
- ✅ `make docs` 命令可用

**预计工时**: 3 小时

---

### Task 3.2: 添加日志级别：fatal 和 critical

**文件**: `lib/core.sh`
**问题**: 缺少严重错误级别
**优势**: 区分可恢复和不可恢复错误

**实施步骤**:

1. **扩展 `core::log()` 函数** (20 分钟)

   在 `lib/core.sh:28-46` 修改：
   ```bash
   ##
   # Structured logging to stderr
   #
   # Supports log levels: debug, info, warn, error, critical, fatal
   # - fatal: Immediately exits with code 1 after logging
   # - critical: Logs severe error but does not exit
   # - error/warn/info/debug: Existing behavior
   #
   # Arguments:
   #   $1 - Log level (string, required) - debug|info|warn|error|critical|fatal
   #   $2 - Message (string, required)
   #   $3 - Context JSON (string, optional, default: "{}")
   #
   # Returns:
   #   0 - Success (debug/info/warn/error/critical)
   #   Exits 1 - If level is fatal
   ##
   core::log() {
     local lvl="${1}"
     shift
     local msg="${1}"
     shift || true
     local ctx="${1-{} }"

     # Filter debug messages unless XRF_DEBUG is true
     if [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]]; then
       return 0
     fi

     # Normalize fatal/critical to uppercase for visibility
     local display_lvl="${lvl}"
     if [[ "${lvl}" == "fatal" || "${lvl}" == "critical" ]]; then
       display_lvl="${lvl^^}"  # Convert to uppercase
     fi

     # All logs go to stderr to avoid contaminating function outputs
     if [[ "${XRF_JSON}" == "true" ]]; then
       printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' \
         "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
     else
       printf '[%s] %-8s %s %s\n' "$(core::ts)" "${display_lvl}" "${msg}" "${ctx}" >&2
     fi

     # Fatal errors exit immediately
     if [[ "${lvl}" == "fatal" ]]; then
       exit 1
     fi

     return 0
   }
   ```

2. **更新错误处理器** (10 分钟)

   在 `lib/core.sh:20-24` 修改：
   ```bash
   core::error_handler() {
     local return_code="${1}" line_number="${2}" command="${3}"
     # Use critical level for ERR trap (doesn't exit, trap will handle that)
     core::log critical "ERR trap" "$(printf '{"rc":%d,"line":%d,"cmd":"%s"}' \
       "${return_code}" "${line_number}" "${command//\"/\\\"}")"
     exit "${return_code}"
   }
   ```

3. **重构关键错误使用 fatal** (30 分钟)

   在关键位置使用 `fatal` 级别：

   **services/xray/configure.sh:96**:
   ```bash
   # 旧代码：
   core::log error "XRAY_PRIVATE_KEY required"
   exit 2

   # 新代码：
   core::log fatal "XRAY_PRIVATE_KEY required"
   # 不需要 exit（fatal 自动退出）
   ```

4. **添加测试** (20 分钟)

   在 `tests/unit/test_core_functions.bats` 添加：
   ```bash
   @test "core::log - fatal level exits with code 1" {
     run bash -c "source ${HERE}/lib/core.sh; core::log fatal 'test fatal'"
     [ "$status" -eq 1 ]
     [[ "$output" == *"FATAL"* ]]
   }

   @test "core::log - critical level does not exit" {
     run bash -c "source ${HERE}/lib/core.sh; core::log critical 'test critical'; echo 'still running'"
     [ "$status" -eq 0 ]
     [[ "$output" == *"CRITICAL"* ]]
     [[ "$output" == *"still running"* ]]
   }
   ```

5. **更新文档** (10 分钟)

   在 `AGENTS.md` 的"Logging Standards"部分添加：
   ```markdown
   ### Log Levels

   | Level | Use Case | Exits? |
   |-------|----------|--------|
   | **debug** | Detailed troubleshooting info | No |
   | **info** | Normal operational messages | No |
   | **warn** | Warning conditions (recoverable) | No |
   | **error** | Error conditions (recoverable) | No |
   | **critical** | Severe errors (may be recoverable) | No |
   | **fatal** | Unrecoverable errors | **Yes (exit 1)** |

   ```bash
   # Example usage
   core::log info "Starting deployment"
   core::log warn "Certificate expires in 7 days"
   core::log error "Failed to connect to server"
   core::log critical "Database corruption detected"
   core::log fatal "Required configuration file missing"  # Exits immediately
   ```
   ```

**验收标准**:
- ✅ `fatal` 级别立即退出
- ✅ `critical` 级别记录但不退出
- ✅ 单元测试验证行为
- ✅ 文档已更新

**预计工时**: 1.5 小时

---

### Task 3.3: 优化 find 命令性能

**文件**: `scripts/caddy-cert-sync.sh`
**问题**: `maxdepth 4` 可能遍历不必要的目录
**优势**: 提升证书查找性能

**实施步骤**:

1. **调研 Caddy 证书目录结构** (15 分钟)

   ```bash
   # Caddy 实际目录结构（基于官方文档）：
   # /root/.local/share/caddy/certificates/
   # └── acme-v02.api.letsencrypt.org-directory/
   #     └── example.com/
   #         ├── example.com.crt
   #         └── example.com.key
   #
   # 最大深度：3 层
   ```

2. **优化 find 命令** (10 分钟)

   在 `scripts/caddy-cert-sync.sh:52-55` 替换为：
   ```bash
   # 动态查找域名证书（限制深度为 3 层，覆盖所有 ACME providers）
   # Caddy 目录结构: certificates/<provider>/<domain>/<domain>.crt
   cert_file=$(find "${CADDY_CERT_BASE}" -maxdepth 3 -type f -name "${DOMAIN}.crt" \
     -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
   key_file=$(find "${CADDY_CERT_BASE}" -maxdepth 3 -type f -name "${DOMAIN}.key" \
     -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
   ```

3. **添加调试日志** (5 分钟)

   在查找后添加：
   ```bash
   log debug "certificate search completed" "$(printf '{"base":"%s","maxdepth":3,"found":"%s"}' \
     "${CADDY_CERT_BASE}" "${cert_file:-none}")"
   ```

4. **测试性能改进** (10 分钟)

   创建基准测试脚本：
   ```bash
   # test_find_performance.sh
   #!/usr/bin/env bash

   CADDY_BASE="/root/.local/share/caddy/certificates"
   DOMAIN="example.com"

   echo "Benchmark: find -maxdepth 4"
   time for i in {1..10}; do
     find "${CADDY_BASE}" -maxdepth 4 -type f -name "${DOMAIN}.crt" 2>/dev/null | head -1
   done

   echo ""
   echo "Benchmark: find -maxdepth 3"
   time for i in {1..10}; do
     find "${CADDY_BASE}" -maxdepth 3 -type f -name "${DOMAIN}.crt" 2>/dev/null | head -1
   done
   ```

**验收标准**:
- ✅ `maxdepth` 从 4 降到 3
- ✅ 仍能找到所有合法证书
- ✅ 性能有可测量的提升（可选）

**预计工时**: 0.5 小时

---

### Task 3.4: 代码复杂度优化

**文件**: `services/xray/configure.sh`
**问题**: `render_vision_reality_inbounds` 函数过长（58 行）
**优势**: 提升可读性和可测试性

**实施步骤**:

1. **提取证书验证逻辑** (20 分钟)

   在 `services/xray/configure.sh` 添加新函数：
   ```bash
   # Helper: Verify TLS certificates exist for vision-reality
   verify_tls_certificates() {
     local cert_dir="${1}"
     local fullchain="${cert_dir}/fullchain.pem"
     local privkey="${cert_dir}/privkey.pem"

     if [[ ! -f "${fullchain}" ]]; then
       core::log error "TLS certificate not found" "$(printf '{"file":"%s"}' "${fullchain}")"
       return 1
     fi

     if [[ ! -f "${privkey}" ]]; then
       core::log error "TLS private key not found" "$(printf '{"file":"%s"}' "${privkey}")"
       return 1
     fi

     core::log debug "TLS certificates verified" "$(printf '{"cert_dir":"%s"}' "${cert_dir}")"
     return 0
   }
   ```

2. **重构主函数** (15 分钟)

   在 `services/xray/configure.sh:116-163` 修改：
   ```bash
   # Render Vision + Reality dual inbound configuration
   xray::render_vision_reality_inbounds() {
     local release_dir="${1}"
     local sniff_bool="${2}"

     # Validate required variables
     : "${XRAY_VISION_PORT:=8443}" : "${XRAY_REALITY_PORT:=443}"
     : "${XRAY_UUID_VISION:?}" : "${XRAY_UUID_REALITY:?}" : "${XRAY_DOMAIN:?}"
     : "${XRAY_CERT_DIR:=/usr/local/etc/xray/certs}" : "${XRAY_FALLBACK_PORT:=8080}"
     : "${XRAY_SNI:=www.microsoft.com}" : "${XRAY_SHORT_ID:?}" : "${XRAY_PRIVATE_KEY:?}"

     core::log debug "vision-reality variables set" "$(printf '{"vision_port":"%s","reality_port":"%s","domain":"%s"}' \
       "${XRAY_VISION_PORT}" "${XRAY_REALITY_PORT}" "${XRAY_DOMAIN}")"

     # Check for required TLS certificates (extracted to function)
     if ! verify_tls_certificates "${XRAY_CERT_DIR}"; then
       core::log error "vision-reality requires TLS certificates" "$(printf '{"cert_dir":"%s","suggestion":"Use: --plugins cert-auto"}' \
         "${XRAY_CERT_DIR}")"
       exit ${ERR_CONFIG}
     fi

     [[ -n "${XRAY_PRIVATE_KEY}" ]] || {
       core::log fatal "XRAY_PRIVATE_KEY required"
     }

     # Prepare configuration values
     local reality_dest server_names shortids_pool
     reality_dest="$(ensure_reality_dest "${XRAY_REALITY_DEST:-}" "${XRAY_SNI}")"
     server_names="$(json_array_from_csv "${XRAY_SNI}")"
     shortids_pool="$(build_shortids_pool "${XRAY_SHORT_ID}" "${XRAY_SHORT_ID_2:-}" "${XRAY_SHORT_ID_3:-}")"

     # Write dual inbound configuration
     cat > "${release_dir}/05_inbounds.json" << JSON
   {"inbounds":[
   {"tag":"vision","listen":"0.0.0.0","port":${XRAY_VISION_PORT},"protocol":"vless",
    "settings":{"clients":[{"id":"${XRAY_UUID_VISION}","flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"alpn":"h2","dest":${XRAY_FALLBACK_PORT}},{"dest":${XRAY_FALLBACK_PORT}}]},
    "streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"minVersion":"1.3","rejectUnknownSni":true,"alpn":["h2","http/1.1"],"certificates":[{"certificateFile":"${XRAY_CERT_DIR}/fullchain.pem","keyFile":"${XRAY_CERT_DIR}/privkey.pem"}]}},
    "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls"]}},
   {"tag":"reality","listen":"0.0.0.0","port":${XRAY_REALITY_PORT},"protocol":"vless",
    "settings":{"clients":[{"id":"${XRAY_UUID_REALITY}","flow":"xtls-rprx-vision"}],"decryption":"none"},
    "streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${reality_dest}","xver":0,"serverNames":${server_names},"privateKey":"${XRAY_PRIVATE_KEY}","shortIds":${shortids_pool},"spiderX":"/"}},
    "sniffing":{"enabled":${sniff_bool},"destOverride":["http","tls","quic"]}}]}
   JSON

     core::log debug "vision-reality inbounds config written" "$(printf '{"vision_port":%d,"reality_port":%d}' \
       "${XRAY_VISION_PORT}" "${XRAY_REALITY_PORT}")"
   }
   ```

3. **添加单元测试** (15 分钟)

   在 `tests/unit/` 创建 `test_xray_configure.bats`:
   ```bash
   #!/usr/bin/env bats
   # Unit tests for xray configure helpers

   load ../test_helper

   setup() {
     setup_test_env
     source "${HERE}/services/xray/configure.sh"
   }

   @test "verify_tls_certificates - success when both files exist" {
     local cert_dir="${BATS_TEST_TMPDIR}/certs"
     mkdir -p "${cert_dir}"
     touch "${cert_dir}/fullchain.pem"
     touch "${cert_dir}/privkey.pem"

     run verify_tls_certificates "${cert_dir}"
     [ "$status" -eq 0 ]
   }

   @test "verify_tls_certificates - fails when fullchain missing" {
     local cert_dir="${BATS_TEST_TMPDIR}/certs"
     mkdir -p "${cert_dir}"
     touch "${cert_dir}/privkey.pem"

     run verify_tls_certificates "${cert_dir}"
     [ "$status" -eq 1 ]
   }

   @test "verify_tls_certificates - fails when privkey missing" {
     local cert_dir="${BATS_TEST_TMPDIR}/certs"
     mkdir -p "${cert_dir}"
     touch "${cert_dir}/fullchain.pem"

     run verify_tls_certificates "${cert_dir}"
     [ "$status" -eq 1 ]
   }
   ```

**验收标准**:
- ✅ 函数复杂度降低
- ✅ 提取的函数可独立测试
- ✅ 现有功能无回归
- ✅ 单元测试覆盖新函数

**预计工时**: 1 小时

---

## 🟢 Phase 4: 文档完善（低优先级）

**目标**: 完善项目文档，提升用户和开发者体验
**预计工时**: 3-4 小时
**风险评估**: 低

### Task 4.1: 创建 CHANGELOG.md

**文件**: 新建 `CHANGELOG.md`
**标准**: Keep a Changelog 格式
**优势**: 便于用户跟踪版本变更

**实施步骤**:

1. **创建 CHANGELOG 文件** (45 分钟)

   创建 `CHANGELOG.md`:
   ```markdown
   # Changelog

   All notable changes to this project will be documented in this file.

   The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
   and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

   ## [Unreleased]

   ### Added
   - Multi-stage improvement plan based on comprehensive code review
   - Enhanced domain validation (IPv6, RFC 6761 reserved TLDs)
   - Centralized configuration management (lib/defaults.sh)
   - Standardized error code definitions (lib/errors.sh)
   - ShellDoc-style API documentation
   - Integration test framework
   - `fatal` and `critical` log levels

   ### Changed
   - Certificate sync lock file location (from /var/lock to /var/lib/xray-fusion/locks)
   - ShortId generation uses `xxd` or `od` instead of `hexdump`
   - Path validation regex tightened (no `..`, no `//`)
   - Certificate lookup optimized (maxdepth 3 instead of 4)

   ### Fixed
   - Domain validator now rejects RFC 3927 link-local addresses
   - Domain validator now rejects RFC 6761 special-use domains
   - Domain validator now rejects IPv6 private addresses
   - Lock file ownership handling in mixed sudo/non-sudo scenarios
   - ShortId generation consistency across different tools

   ### Security
   - Enhanced input validation for domain names
   - Improved lock file security (atomic creation with install(1))
   - Stricter path validation to prevent injection

   ---

   ## [1.0.0] - 2025-11-09

   ### Added
   - Automated testing framework based on bats-core
   - 96 unit tests with ~80% code coverage
   - CI/CD pipeline (GitHub Actions: lint, format, test, security)
   - Independent certificate sync script (scripts/caddy-cert-sync.sh)
   - ADR-009: Automated testing framework

   ### Changed
   - Certificate sync from systemd Path to Timer unit (ADR-002)
   - Xray restart instead of reload for certificate updates (ADR-003)
   - Certificate validation supports both RSA and ECDSA (ADR-004)
   - Extracted cert-sync script from caddy.sh HERE-doc (ADR-008)

   ### Removed
   - OCSP stapling support (Let's Encrypt sunset on 2025-01-30, ADR-005)
   - Config test skip option via XRF_SKIP_XRAY_TEST (ADR-007)

   ### Fixed
   - Certificate sync concurrency protection (ADR-006)
   - Atomic file operations across modules

   ### Security
   - Systemd service hardening (ProtectSystem, NoNewPrivileges, etc.)
   - Plugin system path traversal protection
   - Atomic lock file creation (CWE-362, CWE-283)

   ---

   ## [0.9.0] - 2025-09-XX

   ### Added
   - Unified parameter system (ADR-001)
   - Plugin system architecture
   - Four built-in plugins (cert-auto, firewall, logrotate-obs, links-qr)
   - Dual topology support (reality-only, vision-reality)

   ### Changed
   - Migrated from environment variables to command-line arguments
   - Pipe-friendly installation (curl | bash -s -- --args)

   ### Security
   - RFC-compliant domain validation
   - Input validation at all entry points

   ---

   ## [0.1.0] - 2025-08-XX (Initial Release)

   ### Added
   - Basic Xray installation and configuration
   - Reality protocol support
   - Systemd integration
   - Basic logging framework

   [Unreleased]: https://github.com/Joe-oss9527/xray-fusion/compare/v1.0.0...HEAD
   [1.0.0]: https://github.com/Joe-oss9527/xray-fusion/compare/v0.9.0...v1.0.0
   [0.9.0]: https://github.com/Joe-oss9527/xray-fusion/compare/v0.1.0...v0.9.0
   [0.1.0]: https://github.com/Joe-oss9527/xray-fusion/releases/tag/v0.1.0
   ```

2. **添加版本标签约定** (10 分钟)

   在 `AGENTS.md` 添加：
   ```markdown
   ## Release Management

   ### Version Numbering

   Follow [Semantic Versioning](https://semver.org/):
   - **Major (X.0.0)**: Breaking changes
   - **Minor (0.X.0)**: New features (backward compatible)
   - **Patch (0.0.X)**: Bug fixes

   ### Changelog Maintenance

   Update `CHANGELOG.md` for every notable change:
   1. Add entries to `[Unreleased]` section during development
   2. On release, move `[Unreleased]` to new version section
   3. Update comparison links at bottom

   ### Release Process

   ```bash
   # 1. Update CHANGELOG.md
   # 2. Update version in README.md
   # 3. Create git tag
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin v1.1.0

   # 4. Create GitHub release (auto-triggers CI)
   ```
   ```

**验收标准**:
- ✅ CHANGELOG.md 遵循 Keep a Changelog 格式
- ✅ 所有重要变更已记录
- ✅ 版本管理流程已文档化

**预计工时**: 1 小时

---

### Task 4.2: 创建故障排查指南

**文件**: 新建 `docs/TROUBLESHOOTING.md`
**优势**: 降低用户支持成本

**实施步骤**:

1. **创建故障排查文档** (60 分钟)

   创建 `docs/TROUBLESHOOTING.md`:
   ```markdown
   # Troubleshooting Guide

   Common issues and solutions for xray-fusion.

   ## Table of Contents

   - [Installation Issues](#installation-issues)
   - [Certificate Issues](#certificate-issues)
   - [Service Issues](#service-issues)
   - [Network Issues](#network-issues)
   - [Plugin Issues](#plugin-issues)
   - [Debugging Tools](#debugging-tools)

   ---

   ## Installation Issues

   ### Issue: "vision-reality topology requires domain"

   **Symptom**:
   ```
   [ERROR] vision-reality topology requires domain
   ```

   **Cause**: Vision-Reality topology needs a domain for TLS certificates.

   **Solution**:
   ```bash
   bin/xrf install --topology vision-reality --domain your-domain.com --plugins cert-auto
   ```

   ---

   ### Issue: "command not found: xray"

   **Symptom**:
   ```
   xray: command not found
   ```

   **Cause**: Xray binary not in PATH or installation failed.

   **Diagnosis**:
   ```bash
   # Check if binary exists
   ls -la /usr/local/bin/xray

   # Check installation logs
   journalctl -u xray -n 50
   ```

   **Solution**:
   ```bash
   # Reinstall Xray
   bin/xrf uninstall
   bin/xrf install --topology reality-only
   ```

   ---

   ## Certificate Issues

   ### Issue: Certificate sync fails

   **Symptom**:
   ```bash
   systemctl status cert-reload.service
   # Shows: "certificate file not found"
   ```

   **Diagnosis**:
   ```bash
   # 1. Check Caddy certificate location
   sudo find /root/.local/share/caddy -name "your-domain.com.crt"

   # 2. Check Caddy service
   systemctl status caddy

   # 3. Check Caddy logs
   journalctl -u caddy -n 50

   # 4. Test sync manually
   sudo /usr/local/bin/caddy-cert-sync your-domain.com
   ```

   **Solutions**:

   1. **Caddy hasn't issued certificate yet**:
      ```bash
      # Wait for initial certificate issuance (may take 1-2 minutes)
      journalctl -u caddy -f

      # Verify domain DNS points to server
      dig +short your-domain.com
      ```

   2. **Permission issues**:
      ```bash
      # Fix certificate directory permissions
      sudo chown -R root:xray /usr/local/etc/xray/certs
      sudo chmod 750 /usr/local/etc/xray/certs
      sudo chmod 640 /usr/local/etc/xray/certs/privkey.pem
      sudo chmod 644 /usr/local/etc/xray/certs/fullchain.pem
      ```

   3. **Certificate expired**:
      ```bash
      # Check expiry
      openssl x509 -in /usr/local/etc/xray/certs/fullchain.pem -noout -dates

      # Force Caddy renewal (if Caddy manages the cert)
      systemctl restart caddy
      sleep 60
      sudo /usr/local/bin/caddy-cert-sync your-domain.com
      ```

   ---

   ### Issue: "certificate and private key do not match"

   **Symptom**:
   ```
   [ERROR] certificate and private key do not match
   ```

   **Cause**: Cert-key pair mismatch (usually during manual certificate replacement).

   **Diagnosis**:
   ```bash
   # Compare public key hashes
   cert_hash=$(openssl x509 -in /usr/local/etc/xray/certs/fullchain.pem -pubkey -noout | sha256sum)
   key_hash=$(openssl pkey -in /usr/local/etc/xray/certs/privkey.pem -pubout | sha256sum)

   echo "Cert hash: ${cert_hash}"
   echo "Key hash:  ${key_hash}"
   ```

   **Solution**:
   ```bash
   # If using Caddy, re-sync certificates
   sudo /usr/local/bin/caddy-cert-sync your-domain.com

   # If manual certificates, ensure correct pairing
   # fullchain.pem and privkey.pem must be from same certificate issuance
   ```

   ---

   ## Service Issues

   ### Issue: Xray service fails to start

   **Symptom**:
   ```bash
   systemctl status xray
   # Shows: "failed" or "inactive"
   ```

   **Diagnosis**:
   ```bash
   # 1. Check service logs
   journalctl -u xray -n 100 --no-pager

   # 2. Test configuration manually
   sudo /usr/local/bin/xray -test -confdir /usr/local/etc/xray/active -format json

   # 3. Check config files exist
   ls -la /usr/local/etc/xray/active/*.json

   # 4. Verify xray binary
   /usr/local/bin/xray -version
   ```

   **Solutions**:

   1. **Invalid configuration**:
      ```bash
      # Re-generate configuration
      XRF_DEBUG=true bin/xrf install --topology reality-only

      # Check config test output
      sudo /usr/local/bin/xray -test -confdir /usr/local/etc/xray/active
      ```

   2. **Port already in use**:
      ```bash
      # Check what's using port 443
      sudo ss -tulpn | grep :443

      # If needed, change Xray port
      export XRAY_PORT=8443
      bin/xrf install --topology reality-only
      ```

   3. **Permission issues**:
      ```bash
      # Fix config directory permissions
      sudo chown -R root:xray /usr/local/etc/xray
      sudo chmod 750 /usr/local/etc/xray/active
      sudo chmod 640 /usr/local/etc/xray/active/*.json
      ```

   ---

   ### Issue: Xray service running but not accepting connections

   **Symptom**:
   ```bash
   systemctl status xray
   # Shows: "active (running)"
   # But: timeout 3 bash -c "</dev/tcp/SERVER_IP/443" fails
   ```

   **Diagnosis**:
   ```bash
   # 1. Check if port is listening
   sudo ss -tulpn | grep xray

   # 2. Check firewall
   sudo ufw status
   sudo firewall-cmd --list-all  # For firewalld

   # 3. Check Xray logs
   journalctl -u xray -f

   # 4. Test from server itself
   timeout 3 bash -c "</dev/tcp/127.0.0.1/443" && echo "Local OK"
   ```

   **Solutions**:

   1. **Firewall blocking**:
      ```bash
      # Enable firewall plugin
      bin/xrf plugin enable firewall

      # Or manually open ports
      sudo ufw allow 443/tcp
      sudo ufw allow 8443/tcp  # For vision-reality

      # For firewalld
      sudo firewall-cmd --permanent --add-port=443/tcp
      sudo firewall-cmd --reload
      ```

   2. **Cloud provider security group**:
      - AWS: Add inbound rule for port 443/TCP
      - GCP: Add firewall rule for tcp:443
      - Azure: Add NSG rule for port 443

   ---

   ## Network Issues

   ### Issue: Client connection timeout

   **Symptom**: Client shows "timeout" or "connection refused"

   **Diagnosis**:
   ```bash
   # 1. Verify server IP
   curl ifconfig.me

   # 2. Test port from client
   nc -zv SERVER_IP 443

   # 3. Test from another server
   timeout 3 bash -c "</dev/tcp/SERVER_IP/443" && echo "OK"

   # 4. Check client link format
   bin/xrf links
   ```

   **Solutions**:

   1. **Wrong server IP in client**:
      - Regenerate client links: `bin/xrf links`
      - Update client configuration

   2. **DNS not resolving** (Vision-Reality):
      ```bash
      # Check DNS
      dig +short your-domain.com

      # Ensure A record points to server IP
      ```

   3. **ISP blocking**:
      - Test from different network
      - Consider using Vision-Reality (looks like normal HTTPS)

   ---

   ## Plugin Issues

   ### Issue: Plugin not found

   **Symptom**:
   ```
   plugin not found: my-plugin
   ```

   **Diagnosis**:
   ```bash
   # List available plugins
   bin/xrf plugin list

   # Check plugin directory
   ls -la plugins/available/
   ```

   **Solution**:
   ```bash
   # Use exact plugin ID
   bin/xrf plugin enable cert-auto

   # Available plugins:
   # - cert-auto
   # - firewall
   # - logrotate-obs
   # - links-qr
   ```

   ---

   ### Issue: Plugin hook failed

   **Symptom**:
   ```
   [ERROR] plugin hook failed {"plugin":"cert-auto","event":"configure_pre"}
   ```

   **Diagnosis**:
   ```bash
   # Enable debug mode
   XRF_DEBUG=true bin/xrf install --topology vision-reality --domain example.com --plugins cert-auto

   # Check plugin logs
   journalctl -u caddy -n 50  # For cert-auto plugin
   ```

   **Solution**: See specific plugin documentation in `plugins/available/<plugin>/README.md`

   ---

   ## Debugging Tools

   ### Enable Debug Logging

   ```bash
   # Method 1: Environment variable
   export XRF_DEBUG=true
   bin/xrf install --topology reality-only

   # Method 2: Command-line flag
   bin/xrf install --topology reality-only --debug

   # Method 3: JSON output
   XRF_JSON=true bin/xrf status
   ```

   ---

   ### Check System State

   ```bash
   # View state file
   cat /var/lib/xray-fusion/state.json | jq .

   # Check active configuration
   ls -la /usr/local/etc/xray/active
   cat /usr/local/etc/xray/active/*.json | jq .

   # View all releases
   ls -lt /usr/local/etc/xray/releases/
   ```

   ---

   ### Service Diagnostics

   ```bash
   # Xray service
   systemctl status xray
   journalctl -u xray -f --no-pager

   # Caddy service (if cert-auto plugin)
   systemctl status caddy
   journalctl -u caddy -f --no-pager

   # Certificate reload timer
   systemctl status cert-reload.timer
   systemctl list-timers cert-reload.timer
   ```

   ---

   ### Manual Configuration Test

   ```bash
   # Test configuration without restarting service
   sudo /usr/local/bin/xray -test -confdir /usr/local/etc/xray/active -format json

   # Expected output: "Configuration OK."
   ```

   ---

   ### Network Testing

   ```bash
   # Check listening ports
   sudo ss -tulpn | grep xray

   # Test local connectivity
   timeout 3 bash -c "</dev/tcp/127.0.0.1/443" && echo "Local port OK"

   # Test from remote
   # (Run from client machine)
   nc -zv SERVER_IP 443
   timeout 5 bash -c "</dev/tcp/SERVER_IP/443" && echo "Remote port OK"
   ```

   ---

   ### Certificate Inspection

   ```bash
   # Check certificate validity
   openssl x509 -in /usr/local/etc/xray/certs/fullchain.pem -noout -text

   # Check expiry
   openssl x509 -in /usr/local/etc/xray/certs/fullchain.pem -noout -dates

   # Verify key match
   cert_pub=$(openssl x509 -in /usr/local/etc/xray/certs/fullchain.pem -pubkey -noout | sha256sum)
   key_pub=$(openssl pkey -in /usr/local/etc/xray/certs/privkey.pem -pubout | sha256sum)
   echo "Cert: ${cert_pub}"
   echo "Key:  ${key_pub}"
   ```

   ---

   ## Getting Help

   If these solutions don't resolve your issue:

   1. **Enable debug logging**: `XRF_DEBUG=true`
   2. **Collect logs**:
      ```bash
      # System info
      uname -a
      cat /etc/os-release

      # Service logs
      journalctl -u xray -n 100 --no-pager > xray.log
      journalctl -u caddy -n 100 --no-pager > caddy.log

      # Configuration
      sudo /usr/local/bin/xray -test -confdir /usr/local/etc/xray/active > config-test.log 2>&1

      # State
      cat /var/lib/xray-fusion/state.json > state.log
      ```

   3. **Open GitHub issue**: https://github.com/Joe-oss9527/xray-fusion/issues
      - Include logs (redact sensitive info like UUIDs, keys)
      - Describe what you tried
      - Specify your environment (OS, version, topology)
   ```

2. **更新 README.md** (10 分钟)

   在 `README.md` 添加链接：
   ```markdown
   ## Documentation

   - [Installation Guide](README.md#quick-start)
   - [Architecture Decision Records](CLAUDE.md)
   - [Development Guidelines](AGENTS.md)
   - [API Reference](docs/API_REFERENCE.md)
   - **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** ← New
   - [Changelog](CHANGELOG.md)
   ```

**验收标准**:
- ✅ 覆盖常见问题场景
- ✅ 诊断步骤清晰
- ✅ 解决方案可操作
- ✅ README.md 已链接

**预计工时**: 1.5 小时

---

### Task 4.3: 创建贡献指南

**文件**: 新建 `CONTRIBUTING.md`
**优势**: 规范外部贡献流程

**实施步骤**:

1. **创建贡献指南** (30 分钟)

   创建 `CONTRIBUTING.md`:
   ```markdown
   # Contributing to xray-fusion

   Thank you for considering contributing to xray-fusion! This document provides guidelines for contributing.

   ## Code of Conduct

   This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code.

   ## How to Contribute

   ### Reporting Bugs

   1. **Check existing issues** to avoid duplicates
   2. **Use the bug report template**
   3. **Include**:
      - OS and version
      - xray-fusion version
      - Steps to reproduce
      - Expected vs actual behavior
      - Logs (redact sensitive data)

   ### Suggesting Features

   1. **Check existing feature requests**
   2. **Use the feature request template**
   3. **Describe**:
      - Use case
      - Proposed solution
      - Alternatives considered

   ### Pull Requests

   #### Before You Start

   1. **Open an issue first** for significant changes
   2. **Check existing PRs** to avoid duplicate work
   3. **Ensure alignment** with project goals

   #### Development Setup

   ```bash
   # 1. Fork and clone
   git clone https://github.com/YOUR_USERNAME/xray-fusion.git
   cd xray-fusion

   # 2. Install dependencies
   # - Bash 4.0+
   # - ShellCheck
   # - shfmt
   # - bats-core
   # - jq

   # 3. Run tests
   make test

   # 4. Create feature branch
   git checkout -b feature/my-feature
   ```

   #### Coding Standards

   **Must follow**:
   - [ShellCheck](https://www.shellcheck.net/) - No errors/warnings
   - [shfmt](https://github.com/mvdan/sh) - 2-space indent, Bash mode
   - [AGENTS.md](AGENTS.md) - Project coding conventions

   **Key requirements**:
   ```bash
   # 1. Start with shebang and strict mode
   #!/usr/bin/env bash
   set -euo pipefail

   # 2. Use namespaced functions
   mymodule::my_function() { ... }

   # 3. Use core::log for logging (never echo)
   core::log info "message" '{"key":"value"}'

   # 4. Add ShellDoc comments for public functions
   ##
   # Brief description
   #
   # Arguments:
   #   $1 - Description
   # Returns:
   #   0 - Success
   ##

   # 5. Write tests for new features
   @test "description" {
     run my_function
     [ "$status" -eq 0 ]
   }
   ```

   #### Testing Requirements

   ```bash
   # 1. All tests must pass
   make test

   # 2. Add tests for new features
   # - Unit tests: tests/unit/
   # - Integration tests: tests/integration/

   # 3. Maintain coverage
   # - Target: 80%+ for new code

   # 4. Test in isolation
   export XRF_PREFIX="${PWD}/tmp/prefix"
   export XRF_ETC="${PWD}/tmp/etc"
   export XRF_VAR="${PWD}/tmp/var"
   ```

   #### Commit Guidelines

   Follow [Conventional Commits](https://www.conventionalcommits.org/):

   ```
   <type>(<scope>): <description>

   [optional body]

   [optional footer]
   ```

   **Types**:
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation only
   - `style`: Code style (formatting, no logic change)
   - `refactor`: Code refactoring
   - `test`: Adding/updating tests
   - `chore`: Maintenance (dependencies, build, etc.)

   **Examples**:
   ```
   feat(validators): add IPv6 private address validation

   - Added RFC 4193 ULA detection
   - Added RFC 4291 link-local detection
   - Updated tests

   Closes #42

   ---

   fix(cert-sync): handle mixed sudo/non-sudo lock file ownership

   Use install(1) for atomic lock file creation with correct ownership.

   Fixes #38

   ---

   docs: add troubleshooting guide for certificate issues
   ```

   #### Pull Request Checklist

   - [ ] Code follows style guidelines (`make lint`, `make fmt`)
   - [ ] All tests pass (`make test`)
   - [ ] New tests added for new features
   - [ ] Documentation updated (README, AGENTS.md, etc.)
   - [ ] CHANGELOG.md updated (in `[Unreleased]` section)
   - [ ] Commit messages follow Conventional Commits
   - [ ] PR description explains **what** and **why**

   #### PR Template

   ```markdown
   ## Description
   Brief description of changes

   ## Motivation
   Why this change is needed

   ## Changes
   - Bullet list of changes

   ## Testing
   How to test this PR

   ## Checklist
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] CHANGELOG updated
   ```

   ### Architecture Decisions

   Significant architectural changes require an ADR (Architecture Decision Record):

   1. **Add ADR to CLAUDE.md**
   2. **Format**:
      ```markdown
      ### ADR-XXX: Title (YYYY-MM-DD)
      **Problem**: What problem are we solving?

      **Decision**: What did we decide?

      **Rationale**:
      - Why this decision?
      - What alternatives were considered?

      **Impact**: How does this affect the codebase?
      ```

   ## Development Workflow

   ### Local Testing

   ```bash
   # 1. Format code
   make fmt

   # 2. Lint
   make lint

   # 3. Run unit tests
   make test-unit

   # 4. Run integration tests
   make test-integration

   # 5. Test install flow (in isolated environment)
   export XRF_PREFIX="${PWD}/tmp/prefix"
   export XRF_ETC="${PWD}/tmp/etc"
   export XRF_VAR="${PWD}/tmp/var"
   XRF_DEBUG=true bin/xrf install --topology reality-only
   ```

   ### Pre-commit Hooks (Optional)

   ```bash
   # Install pre-commit
   pip install pre-commit

   # Install hooks
   pre-commit install

   # Run manually
   pre-commit run --all-files
   ```

   ## Plugin Development

   See [AGENTS.md#plugin-tips](AGENTS.md#plugin-tips) for plugin development guidelines.

   ## Questions?

   - **Documentation**: See [AGENTS.md](AGENTS.md)
   - **Issues**: [GitHub Issues](https://github.com/Joe-oss9527/xray-fusion/issues)
   - **Discussions**: [GitHub Discussions](https://github.com/Joe-oss9527/xray-fusion/discussions)

   ## License

   By contributing, you agree that your contributions will be licensed under the same license as the project.
   ```

2. **更新 README.md** (5 分钟)

   在 `README.md` 添加：
   ```markdown
   ## Contributing

   Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
   ```

**验收标准**:
- ✅ 贡献流程清晰
- ✅ 编码标准明确
- ✅ PR 要求具体
- ✅ README.md 已链接

**预计工时**: 0.5 小时

---

### Task 4.4: 更新 README.md

**文件**: `README.md`
**问题**: 缺少徽章、目录、快速链接
**优势**: 提升项目专业度

**实施步骤**:

1. **添加项目徽章** (15 分钟)

   在 `README.md` 顶部添加：
   ```markdown
   # xray-fusion

   [![CI](https://github.com/Joe-oss9527/xray-fusion/workflows/test/badge.svg)](https://github.com/Joe-oss9527/xray-fusion/actions)
   [![ShellCheck](https://github.com/Joe-oss9527/xray-fusion/workflows/shellcheck/badge.svg)](https://github.com/Joe-oss9527/xray-fusion/actions)
   [![License](https://img.shields.io/github/license/Joe-oss9527/xray-fusion)](LICENSE)
   [![Code Coverage](https://img.shields.io/badge/coverage-80%25-brightgreen)](tests/)

   > Lightweight, modular Xray deployment tool with automated TLS and plugin system

   [Quick Start](#quick-start) •
   [Documentation](#documentation) •
   [Troubleshooting](docs/TROUBLESHOOTING.md) •
   [Contributing](CONTRIBUTING.md) •
   [Changelog](CHANGELOG.md)
   ```

2. **添加目录** (10 分钟)

   在 Quick Start 前添加：
   ```markdown
   ## Table of Contents

   - [Features](#features)
   - [Quick Start](#quick-start)
   - [Deployment Topologies](#deployment-topologies)
   - [Plugins](#plugins)
   - [Configuration](#configuration)
   - [Testing](#testing)
   - [Documentation](#documentation)
   - [Troubleshooting](docs/TROUBLESHOOTING.md)
   - [Contributing](CONTRIBUTING.md)
   - [License](#license)
   ```

3. **更新 Features 部分** (10 分钟)

   ```markdown
   ## Features

   - 🚀 **One-line installation** - Pipe-friendly curl | bash
   - 🔒 **Auto TLS** - Caddy-powered certificate management
   - 🧩 **Plugin system** - Extensible architecture
   - 🧪 **80% test coverage** - 173 unit + integration tests
   - 📋 **Dual topologies** - Reality-only or Vision+Reality
   - 🔐 **Security-first** - RFC-compliant validation, hardened systemd
   - 📊 **Structured logging** - JSON or text output
   - 🛡️ **Production-ready** - Atomic operations, concurrency protection
   ```

4. **添加架构图** (可选，15 分钟)

   创建简单的 ASCII 架构图：
   ```markdown
   ## Architecture

   ```
   ┌─────────────────┐
   │   bin/xrf CLI   │  ← User entry point
   └────────┬────────┘
            │
   ┌────────▼────────────────────────────┐
   │  commands/  (install/uninstall/etc) │
   └────────┬────────────────────────────┘
            │
   ┌────────▼──────────┬─────────────────┐
   │   lib/            │  modules/       │
   │ • core.sh         │ • io.sh         │
   │ • args.sh         │ • state.sh      │
   │ • validators.sh   │ • web/caddy.sh  │
   │ • plugins.sh      │ • user/user.sh  │
   │ • defaults.sh     │ • fw/firewall.sh│
   │ • errors.sh       │                 │
   └───────────────────┴─────────────────┘
            │
   ┌────────▼────────────────────────────┐
   │  services/xray/                     │
   │ • install.sh    (fetch binary)      │
   │ • configure.sh  (generate config)   │
   │ • systemd-unit.sh                   │
   └─────────────────────────────────────┘
            │
   ┌────────▼────────────────────────────┐
   │  Systemd Services                   │
   │ • xray.service                      │
   │ • caddy.service (optional)          │
   │ • cert-reload.timer (optional)      │
   └─────────────────────────────────────┘
   ```
   ```

**验收标准**:
- ✅ 徽章显示正确
- ✅ 目录链接有效
- ✅ Features 部分突出亮点
- ✅ 架构图清晰（可选）

**预计工时**: 1 小时

---

## 📊 阶段总结

| 阶段 | 任务 | 工时 | 完成标准 |
|------|------|------|----------|
| **Phase 1** | 3个安全修复任务 | 4-6h | 所有高风险问题已修复 |
| **Phase 2** | 4个稳定性任务 | 5-7h | 配置管理统一，测试覆盖提升 |
| **Phase 3** | 4个可维护性任务 | 4-5h | API文档完善，代码简化 |
| **Phase 4** | 4个文档任务 | 3-4h | 用户文档完整 |
| **总计** | **15个任务** | **16-22h** | **所有验收标准通过** |

---

## 🎯 执行建议

### 1. 并行开发

可并行的任务组合：
- **Week 1**: Phase 1 全部 + Phase 2.1
- **Week 2**: Phase 2.2-2.4 + Phase 3.1
- **Week 3**: Phase 3.2-3.4 + Phase 4 全部

### 2. 持续集成

每完成一个 Phase:
```bash
# 1. 运行全部测试
make test

# 2. 验证代码质量
make lint
make fmt

# 3. 提交代码
git add .
git commit -m "feat(phase-N): complete phase N improvements"

# 4. 推送并创建PR
git push origin feature/phase-N-improvements
gh pr create --title "Phase N: <title>" --body "..."
```

### 3. 验收标准

每个 Phase 完成后检查：
- ✅ 所有新增测试通过
- ✅ 现有测试无回归
- ✅ ShellCheck 无警告
- ✅ 代码格式正确 (shfmt)
- ✅ 文档已更新
- ✅ CHANGELOG.md 已更新

### 4. 回滚计划

每个 Phase 开始前：
```bash
# 创建备份分支
git checkout -b backup/before-phase-N

# 在功能分支工作
git checkout -b feature/phase-N

# 如果出问题，回滚到备份
git checkout main
git reset --hard backup/before-phase-N
```

---

## 📝 最终交付物

完成所有 4 个阶段后，项目将拥有：

1. **代码质量**
   - ✅ 零安全漏洞（已知）
   - ✅ 100% ShellCheck 通过
   - ✅ 统一的错误处理
   - ✅ 集中的配置管理

2. **测试覆盖**
   - ✅ 80%+ 单元测试覆盖率
   - ✅ 集成测试框架
   - ✅ CI/CD 自动化

3. **文档完整性**
   - ✅ API 参考文档
   - ✅ 故障排查指南
   - ✅ 贡献指南
   - ✅ 完整的 CHANGELOG

4. **可维护性**
   - ✅ 函数文档化
   - ✅ 代码简化
   - ✅ 清晰的架构

---

## 🆘 获取帮助

如果在实施过程中遇到问题：

1. **参考官方文档**
   - [AGENTS.md](AGENTS.md) - 开发指南
   - [CLAUDE.md](CLAUDE.md) - ADR记录

2. **运行调试模式**
   ```bash
   XRF_DEBUG=true <your-command>
   ```

3. **寻求 Code Review**
   - 每个 Phase 完成后创建 PR
   - 标记为 `WIP` (Work In Progress) 如果未完成

4. **联系维护者**
   - GitHub Issues
   - GitHub Discussions

---

**祝改进顺利！** 🚀
