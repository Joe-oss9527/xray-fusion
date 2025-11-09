# Project Memory: xray-fusion

> 本文档记录项目关键技术决策、编码规范和常见问题解决方案。遵循"具体、简洁、可操作"原则。

## 开发工作流

### 调试原则
- ✅ **系统性调试，不做猜测** - 通过日志分析定位问题，基于实际现象修复
- ✅ **使用项目日志框架** - 统一使用 `core::log`，不使用 `echo`
- ✅ **优先查阅官方文档** - 避免使用过期或废弃的实现方式

### 代码质量要求
- 保持代码整洁，不做无用的向后兼容
- 确保所有操作通过脚本参数化，避免手动干预
- 变量命名使用下划线分隔：`XRAY_DOMAIN`、`XRAY_SNI`

## Shell 编程规范

### 日志输出
```bash
# 所有日志输出到 stderr，避免污染函数返回值
core::log() {
  local lvl="${1}"; shift
  local msg="${1}"; shift || true
  local ctx="${1-{} }"

  # Filter debug messages unless XRF_DEBUG=true
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0

  # All logs to stderr
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' \
      "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  fi
}

# 独立脚本中嵌入兼容的日志函数
# 用于 /usr/local/bin/caddy-cert-sync 等独立脚本
log() {
  local lvl="${1}"; shift
  local msg="${1}"
  [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]] && return 0
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"[script-name] %s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  else
    printf '[%s] %-5s [script-name] %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${lvl}" "${msg}" >&2
  fi
}

# 外部命令输出也必须重定向
external-command >/dev/null 2>&1 || true
```

### Trap 和变量作用域
```bash
# ❌ 错误：EXIT trap 中使用局部变量
function_name() {
  local tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT  # 局部变量在 trap 中可能失效
}

# ✅ 正确：使用全局变量 + 参数展开
function_name() {
  local tmpdir="$(mktemp -d)"
  _GLOBAL_TMPDIR="${tmpdir}"
  trap 'rm -rf "${_GLOBAL_TMPDIR:-}" 2>/dev/null || true; unset _GLOBAL_TMPDIR' EXIT
}

# ✅ 更好：Trap 多个信号
cleanup() {
  [[ -n "${tmpdir:-}" && -d "${tmpdir}" ]] && rm -rf "${tmpdir}"
}
trap cleanup EXIT INT TERM HUP
```

### 变量污染防御
```bash
# ❌ 错误：直接加载外部文件可能污染变量
. /etc/os-release  # VERSION 被系统版本覆盖

# ✅ 正确：子 shell 隔离
os_info=$(source /etc/os-release 2>/dev/null && echo "${ID:-unknown} ${VERSION_ID:-unknown}")
```

## Xray 配置最佳实践

### Vision-Reality 拓扑
- **Reality 端口**: 443（标准 HTTPS，符合官方推荐）
- **Vision 端口**: 8443（真实 TLS，避免与 Reality 冲突）
- **Caddy HTTPS 端口**: 8444（避免占用 443）

### 证书权限
```bash
# Xray 服务以 xray 用户运行，需要读取私钥
chmod 644 fullchain.pem
chmod 640 privkey.pem
chown root:xray *.pem
```

### VLESS+REALITY 核心概念
- REALITY 协议**不需要域名所有权**
- SNI 用于伪装，如 `www.microsoft.com` 是合法配置
- Reality 无法通过常规反向代理（如 Caddy）转发

### TLS 配置
```json
{
  "minVersion": "1.3",  // 2025 安全标准，强制 TLS 1.3（符合 Xray-core v25.9.11 推荐）
  "serverName": "example.com"
  // 注意：不再使用 ocspStapling（Let's Encrypt 2025-01-30 停止 OCSP 服务）
}
```

### shortIds 配置理解
- shortIds 是服务端配置的一个**池**，客户端从中选择
- 不是"每客户端必须唯一"，而是"提供区分能力"
- 个人使用单个 shortId 足够，多用户场景可扩展池

```bash
# 生成 3 个 shortId 作为池（向后兼容单 shortId）
sid_pool='["","${XRAY_SHORT_ID}","${XRAY_SHORT_ID_2}","${XRAY_SHORT_ID_3}"]'
```

### spiderX 参数
- spiderX 是**客户端参数**，不是服务端强制值
- 服务端 `"spiderX": "/"` 是示例路径
- 客户端链接中 `spx=%2F` 才是实际使用值

## 证书管理

### 自动化方案选择
- ✅ **Caddy**: 成熟的自动证书管理，参考 233boy/Xray
- ❌ **acme.sh**: 缺少完整集成逻辑，维护复杂度高

### 证书同步原子性（2025-10-05 改进）

#### 原子文件操作原则
```bash
# ✅ 使用同分区临时目录 + mv（POSIX 保证原子性）
tmpdir=$(mktemp -d -p "${TARGET_DIR}" .sync.XXXXXX)
cp source "${tmpdir}/file"
chmod 644 "${tmpdir}/file"
mv -f "${tmpdir}/file" "${TARGET_DIR}/file"  # 原子操作

# ⚠️ 避免跨分区 mv（非原子，实际是 copy + delete）
mktemp -d -p /tmp  # /tmp 通常在不同分区或 ramfs
```

#### 证书验证（支持 RSA 和 ECDSA）
```bash
# ✅ 通用方法：比较公钥哈希
cert_pub=$(openssl x509 -in cert.pem -pubkey -noout | sha256sum | awk '{print $1}')
key_pub=$(openssl pkey -in key.pem -pubout | sha256sum | awk '{print $1}')
[[ "${cert_pub}" == "${key_pub}" ]] || exit 1

# ❌ 旧方法：仅支持 RSA
cert_modulus=$(openssl x509 -noout -modulus -in cert.pem | openssl md5)
key_modulus=$(openssl rsa -noout -modulus -in key.pem | openssl md5)
```

#### 同步失败回滚
```bash
# 备份现有证书
backup_dir="${TARGET_DIR}/.backup.$$"
cp -a existing_cert "${backup_dir}/"

# 原子移动双文件
mv -f new_fullchain.pem target/
if ! mv -f new_privkey.pem target/; then
  # 回滚
  mv -f "${backup_dir}/fullchain.pem" target/
  exit 1
fi
rm -rf "${backup_dir}"
```

#### systemd 集成策略
```ini
# ✅ 使用 Timer（可靠、可预测）
[Timer]
OnBootSec=2min
OnUnitActiveSec=10min  # 证书变更频率低，10分钟足够
Persistent=true

# ❌ 避免 Path 单元（inotify 在嵌套目录/NFS 不可靠）
[Path]
PathChanged=/path/to/certs  # 有内置延迟，某些文件系统不可靠
```

#### 证书有效期检查
```bash
# 检查是否已过期（拒绝同步）
openssl x509 -in cert.pem -noout -checkend 0 || exit 1

# 7天警告窗口（24小时太短）
openssl x509 -in cert.pem -noout -checkend 604800 || log warn "expires soon"
```

#### 并发保护（2025-10-06）
```bash
# ✅ 证书同步脚本必须添加全局锁（防止 systemd timer 并发触发）
exec 200>/var/lock/caddy-cert-sync.lock
if ! flock -n 200; then
  log info "another sync process is running, skipping"
  exit 0
fi

# 原有同步逻辑...
```

**理由**:
- systemd timer 可能并发触发，导致竞态条件
- 使用 `-n` 非阻塞模式，避免任务堆积
- 符合项目已有 `core::with_flock` 模式

### Xray 重启策略（关键修正）

**重要发现**: Xray-core **不支持** SIGHUP 优雅重载
- 参考: https://github.com/XTLS/Xray-core/discussions/1060
- 官方安装脚本从不包含 `ExecReload` 指令

```bash
# ❌ 错误：Xray 不支持 reload
systemctl reload xray

# ✅ 正确：证书更新后必须 restart
systemctl restart xray
```

```ini
# xray.service 不应包含 ExecReload
[Service]
ExecStart=/usr/local/bin/xray run -confdir /usr/local/etc/xray/active -format json
# 不要添加 ExecReload（Xray 不支持）
```

### systemd 服务安全加固
```ini
[Service]
Type=oneshot
ExecStart=/usr/local/bin/cert-sync

# 安全限制
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/usr/local/etc/xray/certs
NoNewPrivileges=true

# 资源限制
MemoryMax=50M
TasksMax=10
```

## 参数系统设计

### 统一参数格式
```bash
# install.sh 和 xrf 使用完全相同的参数
--topology reality-only|vision-reality
--domain <domain>           # vision-reality 必需
--version <version>         # default: latest
--plugins <plugin1,plugin2>
--debug

# 管道友好（环境变量在管道中无效）
curl -sL install.sh | bash -s -- --domain example.com
```

### 参数验证原则
```bash
# 输入验证
args::validate_topology()  # 只允许 reality-only|vision-reality
args::validate_domain()    # RFC 兼容 + 禁止内部域名
args::validate_version()   # latest 或 vX.Y.Z

# 交叉验证
args::validate_config()    # vision-reality 需要域名

# ✅ 正确：验证失败立即退出
args::validate_topology "${2}" || return 1
TOPOLOGY="${2}"

# ❌ 错误：验证失败但继续执行
args::validate_topology "${2}"  # 未检查返回值
TOPOLOGY="${2}"
```

### 域名验证（RFC 兼容）
```bash
# ✅ 正确的正则（防止 ..com, -.com）
[[ "${domain}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]

# 禁止内部域名
case "${domain}" in
  localhost|*.local|127.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*)
    return 1 ;;
esac
```

## 常用命令

### 构建和安装
```bash
# 本地安装
bin/xrf install --topology reality-only

# 带插件的 Vision-Reality 拓扑
bin/xrf install --topology vision-reality --domain your.domain.com --plugins cert-auto

# 一键安装（管道友好）
curl -sL install.sh | bash -s -- --topology reality-only

# 卸载
bin/xrf uninstall
```

### 调试
```bash
# 启用调试日志
XRF_DEBUG=true bin/xrf install --topology reality-only

# JSON 格式日志
XRF_JSON=true bin/xrf install --topology reality-only

# 查看服务状态
systemctl status xray
journalctl -u xray -f

# 测试证书同步
/usr/local/bin/caddy-cert-sync example.com

# 验证 systemd timer
systemctl list-timers cert-reload.timer
systemctl status cert-reload.timer
```

### 验证端点
```bash
# Vision 端点测试
timeout 3 bash -c "</dev/tcp/domain.com/8443" && echo "Vision accessible"

# Reality 端点测试
timeout 3 bash -c "</dev/tcp/1.2.3.4/443" && echo "Reality accessible"
```

## 架构决策记录

### ADR-001: 统一参数传递系统（2025-09-XX）
**问题**: install.sh 和 xrf 使用不同参数格式，环境变量在管道中无效

**决策**: 彻底统一为命令行参数，移除环境变量混合模式

**理由**:
- 管道友好：`curl | bash -s -- --domain x.com` 正常工作
- 零维护负担：单一参数定义点，无兼容性包袱
- 接口一致：不同入口使用相同参数

### ADR-002: 证书同步从 Path 单元改为 Timer（2025-10-05）
**问题**: systemd Path 单元在嵌套目录、NFS 等场景不可靠

**决策**: 使用 Timer 每 10 分钟检查证书变更

**理由**:
- 更可靠：避免 inotify 文件系统兼容性问题
- 足够及时：证书通常 60-90 天才更新，10 分钟检查足够
- 易于测试：可预测的执行时间

### ADR-003: Xray 证书更新使用 restart 而非 reload（2025-10-05）
**问题**: Xray-core 不支持 SIGHUP 优雅重载

**决策**: 证书更新后使用 `systemctl restart xray`

**理由**:
- 官方确认：GitHub Discussion #1060 明确不支持
- 避免未定义行为：SIGHUP 可能导致进程异常终止
- 官方参考：XTLS/Xray-install 脚本无 ExecReload

### ADR-004: 证书验证支持 ECDSA（2025-10-05）
**问题**: 原实现仅验证 RSA 证书，现代 CA 越来越多使用 ECDSA

**决策**: 使用公钥哈希比对，支持 RSA 和 ECDSA

**理由**:
- 通用方法：`openssl pkey` 处理所有密钥类型
- 面向未来：ECDSA 性能更好、体积更小
- 算法无关：SHA256 哈希比对不依赖特定算法

### ADR-005: 移除 OCSP Stapling（2025-10-06）
**问题**: Let's Encrypt 于 2025-01-30 停止 OCSP 服务

**决策**: 从 TLS 配置中删除 `ocspStapling` 参数

**理由**:
- Let's Encrypt 官方公告停止 OCSP Must-Staple 支持
- 保留无效参数增加维护负担
- 替代方案（CRLite）由浏览器自动处理，无需服务端配置

### ADR-006: 证书同步并发锁（2025-10-06）
**问题**: systemd timer 可能并发触发证书同步脚本

**决策**: 使用 flock 非阻塞锁保护证书同步

**理由**:
- 防止竞态条件导致证书损坏或不一致
- 非阻塞模式避免任务堆积，第二个实例立即退出
- 符合项目已有 `core::with_flock` 模式

### ADR-007: 强制配置验证（2025-10-06）
**问题**: `XRF_SKIP_XRAY_TEST` 环境变量可能被滥用跳过验证

**决策**: 完全删除配置测试跳过功能

**理由**:
- 配置验证是关键安全检查，不应可绕过
- 简化代码逻辑，减少维护负担（删除 21 行冗余代码）
- 符合"代码整洁优于兼容性"原则

### ADR-008: 证书同步脚本独立化（2025-11-09）
**问题**: `modules/web/caddy.sh` 包含 195 行嵌入式 HERE 文档（证书同步脚本）

**决策**: 提取为独立脚本 `scripts/caddy-cert-sync.sh`

**理由**:
- 可维护性：独立脚本更易于测试、调试和版本控制
- 代码复杂度：消除大型 HERE 文档，caddy.sh 从 444 行减至 259 行（-41.7%）
- 单一职责：证书同步是独立功能，应该是独立模块
- 可测试性：独立脚本可以单独测试，无需启动整个安装流程

**影响**:
- 文件结构更清晰
- 便于 code review
- 支持独立执行和调试

### ADR-009: 引入自动化测试框架（2025-11-09）
**问题**: 项目缺少自动化测试，完全依赖人工测试和静态分析

**决策**: 基于 bats-core 建立测试框架和 CI/CD 流水线

**实现**:
- 测试框架：bats-core + 自定义测试辅助函数
- 单元测试：26 个测试用例覆盖核心模块
- CI/CD：GitHub Actions 6 个工作流（Lint, Format, Test, Security）
- Makefile：统一的测试命令 (`make test`, `make test-unit`)

**理由**:
- 质量保证：自动化测试防止回归错误
- 快速反馈：CI/CD 在每次提交时自动运行测试
- 文档化：测试用例是最好的使用文档
- 持续改进：测试覆盖率可以持续提升

**测试覆盖**:
- lib/args.sh: 100% (19 个测试)
- lib/core.sh: ~85% (7 个测试)
- 更多模块持续添加中

## 核心教训总结

1. **验证官方支持，不做假设**
   - 查阅官方文档和 GitHub discussions
   - 验证关键功能（如 SIGHUP reload）实际支持情况

2. **选择适合场景的技术**
   - Timer 比 Path 更可靠（虽然看起来不"高级"）
   - 成熟方案（Caddy）优于重复造轮子（acme.sh）

3. **完整的错误恢复机制**
   - 原子操作需要考虑多文件场景
   - 添加备份和回滚机制

4. **安全默认和最小权限**
   - systemd 服务启用安全加固（ProtectSystem、NoNewPrivileges）
   - 文件权限遵循最小权限原则

5. **代码整洁优于兼容性**
   - 无用户则无负担，不做不必要的向后兼容
   - 删除不完整或废弃的代码

6. **安全配置不可妥协**
   - TLS 1.3 强制启用，无向下兼容（2025 安全标准）
   - 配置验证总是执行，无跳过选项
   - 并发保护必须实现，防止竞态条件

---

**文档维护**: 定期审查，随项目演进更新。遵循"具体、简洁、可操作"原则。
