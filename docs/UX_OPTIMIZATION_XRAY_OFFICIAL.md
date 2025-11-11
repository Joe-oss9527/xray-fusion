# UX Optimization: Xray Official Documentation Integration

> **研究目标**: 结合 Xray-core 官方文档和最佳实践，深度分析 xray-fusion 的用户体验优化方向

**日期**: 2025-11-11
**研究范围**: Xray 官方文档 + 顶级开源项目 UX 模式
**当前 xray-fusion 版本**: 基于最新 main 分支

---

## 目录

1. [Xray 官方文档关键发现](#1-xray-官方文档关键发现)
2. [xray-fusion vs 官方推荐对比](#2-xray-fusion-vs-官方推荐对比)
3. [配置生成 UX 改进建议](#3-配置生成-ux-改进建议)
4. [用户引导和验证增强](#4-用户引导和验证增强)
5. [错误处理和故障排除](#5-错误处理和故障排除)
6. [高级功能暴露](#6-高级功能暴露)
7. [实施优先级和快速胜利](#7-实施优先级和快速胜利)

---

## 1. Xray 官方文档关键发现

### 1.1 配置验证机制

**官方提供的工具**:
```bash
# Xray 内置配置测试命令
xray run -test -confdir /path/to/config

# 支持多种格式自动检测
xray run -config config.json -test
xray run -config config.toml -format toml -test
xray run -config config.yaml -format yaml -test
```

**xray-fusion 当前实现**: ✅
```bash
# services/xray/configure.sh:297-302
"${xray_bin}" -test -confdir "${release_dir}" -format json 2>&1
```

**优化建议**: ⚠️ 用户不知道如何手动验证配置
- 应该暴露 `xrf validate` 或 `xrf test-config` 命令
- 安装时显示验证命令供用户参考

---

### 1.2 UUID 生成工具

**官方提供的工具**:
```bash
# 生成随机 UUID
xray uuid
# Output: 6ba85179-d64e-4cb8-901f-bfb8e9e7d5f1

# 从字符串映射 UUID (稳定映射)
xray uuid -i "my-custom-string"
# Output: b0d82e7d-4d24-5b5c-9b6e-3c4e1f0a8c9d
```

**xray-fusion 当前实现**: ⚠️ 仅在内部使用 `uuidgen`
```bash
# services/xray/install.sh 中使用系统工具
uuid=$(command -v uuidgen &>/dev/null && uuidgen || cat /proc/sys/kernel/random/uuid)
```

**优化建议**:
1. **切换到 Xray 官方工具**: 使用 `xray uuid` 替代 `uuidgen`
   - 保证与 Xray 核心一致的 UUID 格式
   - 支持自定义字符串映射（便于记忆和管理）

2. **暴露给用户**: 提供 `xrf uuid` 子命令
   ```bash
   xrf uuid                    # 生成随机 UUID
   xrf uuid --from-string "name"  # 从字符串生成
   ```

3. **安装时交互式选择**:
   ```
   [INFO] Generating UUID for VLESS...

   Options:
     1) Generate random UUID (recommended)
     2) Generate from custom string (e.g., username)

   Choice [1]: 2
   Enter custom string: alice
   Generated UUID: b0d82e7d-4d24-5b5c-9b6e-3c4e1f0a8c9d
   ```

---

### 1.3 X25519 密钥生成

**官方提供的工具**:
```bash
# 生成 REALITY 所需的密钥对
xray x25519

# Output:
# Private key: gK3C8vCuE9TLuLOq1QvZBJF8M0N2P4R6S8T0U2V4W6Y=
# Public key: AAAAAAAAAAAABBBBBBBBBBBBCCCCCCCCCCCCDDDDDDDD=
```

**xray-fusion 当前实现**: ✅ 使用官方工具
```bash
# services/xray/install.sh
XRAY_KEYS="$("${xray_bin}" x25519)"
XRAY_PRIVATE_KEY="$(echo "${XRAY_KEYS}" | grep 'Private key:' | awk '{print $3}')"
XRAY_PUBLIC_KEY="$(echo "${XRAY_KEYS}" | grep 'Public key:' | awk '{print $3}')"
```

**优化建议**: ✅ 已经正确使用，但可以改进用户体验

1. **显示密钥生成过程**:
   ```
   [INFO] Generating REALITY encryption keys...
   Private key: gK3C8vCuE9TLuLOq1QvZBJF8M0N2P4R6S8T0U2V4W6Y=
   Public key: AAAAAAAAAAAABBBBBBBBBBBBCCCCCCCCCCCCDDDDDDDD=
   [✓] Keys generated successfully
   ```

2. **允许导入已有密钥**:
   ```bash
   xrf install --topology reality-only \
     --private-key "gK3C8vCuE9TLuLOq1QvZBJF8M0N2P4R6S8T0U2V4W6Y=" \
     --public-key "AAAAAAAAAAAABBBBBBBBBBBBCCCCCCCCCCCCDDDDDDDD="
   ```

3. **提供密钥管理命令**:
   ```bash
   xrf keys generate        # 生成新密钥对
   xrf keys show           # 显示当前密钥
   xrf keys rotate         # 轮换密钥（生成新的并更新配置）
   ```

---

### 1.4 VLESS 协议关键参数

**官方文档强调的必需项**:

| 参数 | 要求 | xray-fusion 实现 | 状态 |
|------|------|------------------|------|
| `decryption` | 必须显式设为 `"none"` | ✅ `services/xray/configure.sh:150` | ✅ 正确 |
| `flow` | REALITY 必须是 `xtls-rprx-vision` | ✅ 硬编码 | ✅ 正确 |
| `security` | 使用 REALITY 时必须是 `"reality"` | ✅ 硬编码 | ✅ 正确 |
| `network` | XTLS 仅支持 `tcp` | ✅ 硬编码 | ✅ 正确 |

**关键警告** (来自官方文档):
> ⚠️ **Security**: "VLESS does not provide built-in encryption. Please use it with a reliable channel, such as TLS."

**xray-fusion 实现**: ✅ 总是使用 TLS 1.3 或 REALITY（安全）

**优化建议**: 在文档中强调安全性
```markdown
## Security Guarantees

xray-fusion enforces secure configurations by default:
- ✅ REALITY protocol (no traditional TLS certificates required)
- ✅ TLS 1.3 minimum version (vision-reality topology)
- ✅ XTLS Vision flow (optimal performance + security)
- ❌ Never exposes unencrypted VLESS connections
```

---

### 1.5 REALITY 目标网站选择

**官方推荐标准**:

| 标准 | 优先级 | 说明 |
|------|--------|------|
| **TLS v1.3 支持** | 必需 | REALITY 要求 |
| **HTTP/2 支持** | 必需 | 性能和伪装 |
| **非重定向域名** | 必需 | 避免暴露真实流量 |
| **国外网站** | 推荐 | 提高伪装效果 |
| **低延迟** | 推荐 | 就近选择 IP |
| **OCSP Stapling** | 可选 | 增强伪装 |

**官方推荐示例**:
- `dl.google.com` (Google 下载服务，加密 Server Hello 后内容)
- `www.microsoft.com` (Microsoft 官网)
- `www.cloudflare.com` (Cloudflare 官网)
- `www.apple.com` (Apple 官网)

**xray-fusion 当前实现**: ⚠️ 默认 `www.microsoft.com`，无验证

```bash
# services/xray/configure.sh:134
: "${XRAY_SNI:=www.microsoft.com}"
```

**优化建议**: 🚀 增强 SNI 选择和验证

#### 方案 A: 交互式 SNI 选择器

```bash
xrf install --topology reality-only

# 触发交互式选择
[INFO] REALITY requires a target website (SNI) for camouflage.

Recommended targets (TLS 1.3 + H2 verified):
  1) www.microsoft.com    (Default, Global CDN, Fast)
  2) dl.google.com        (Encrypted post-handshake, Best privacy)
  3) www.cloudflare.com   (Anycast network, Low latency)
  4) www.apple.com        (High reputation, Stable)
  5) Custom domain        (Advanced users)

Select target [1]: 2

[✓] Using SNI: dl.google.com
[INFO] Verifying target supports TLS 1.3 and H2...
[✓] Target validated successfully
```

#### 方案 B: 自动 SNI 验证

```bash
# 用户提供自定义 SNI
xrf install --topology reality-only --sni "example.com"

# 自动验证
[INFO] Validating target website: example.com
  [✓] DNS resolution: 93.184.216.34
  [✓] TLS 1.3 support: Yes
  [✓] HTTP/2 support: Yes
  [✓] Non-redirect: Yes
  [✓] Latency: 45ms (Good)

[✓] Target validated successfully
```

#### 方案 C: SNI 测试工具

```bash
# 新增命令：测试目标网站是否适合 REALITY
xrf test-sni "example.com"

# 输出：
Testing target: example.com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ DNS resolution     93.184.216.34
✓ TLS 1.3 support    Enabled
✓ HTTP/2 support     Enabled (h2)
✓ Certificate chain  Valid (Let's Encrypt)
✓ OCSP Stapling      Enabled
✓ Non-redirect       No redirects detected
✓ Latency            45ms (Good)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Result: ✓ SUITABLE for REALITY

Recommendation:
  This domain meets all requirements for REALITY protocol.
  Use with: xrf install --topology reality-only --sni "example.com"
```

**实现优先级**: 🔥 HIGH (直接影响用户配置质量)

**参考工具**:
```bash
# TLS 1.3 检测
openssl s_client -connect example.com:443 -tls1_3 </dev/null 2>&1 | grep "Protocol.*TLSv1.3"

# HTTP/2 检测
curl -I --http2 https://example.com 2>&1 | grep "HTTP/2"

# 重定向检测
curl -I https://example.com 2>&1 | grep -E "^HTTP|^Location"

# OCSP Stapling 检测
openssl s_client -connect example.com:443 -status </dev/null 2>&1 | grep "OCSP Response Status"
```

---

### 1.6 shortIds 配置

**官方说明**:
- shortIds 是服务端提供的 **ID 池**，客户端从中选择一个
- 长度：0-16 个十六进制字符（`[0-9a-f]{0,16}`）
- **空字符串 `""` 必须包含在池中** (用于兼容性)
- 推荐：3-8 个不同 ID，供不同客户端使用

**官方配置示例**:
```json
{
  "shortIds": [
    "",                    // Required: empty string for compatibility
    "0123456789abcdef",    // Client 1
    "fedcba9876543210",    // Client 2
    "1a2b3c4d"            // Client 3 (shorter ID also valid)
  ]
}
```

**xray-fusion 当前实现**: ⚠️ 固定长度，单一 ID

```bash
# services/xray/common.sh:28-46
xray::generate_shortid() {
  # 总是生成 16 字符（8 字节）
  head -c 8 /dev/urandom | xxd -p -c 16
}

# services/xray/configure.sh:43-50
build_shortids_pool() {
  local primary="${1}" secondary="${2:-}" tertiary="${3:-}"
  local pool="[\"\",\"${primary}\""
  [[ -n "${secondary}" ]] && pool="${pool},\"${secondary}\""
  [[ -n "${tertiary}" ]] && pool="${pool},\"${tertiary}\""
  echo "${pool}]"
}
```

**实际生成的配置**:
```json
{
  "shortIds": [
    "",                    // ✅ 正确：包含空字符串
    "a1b2c3d4e5f67890"    // ⚠️ 问题：仅 1 个固定长度 ID
  ]
}
```

**优化建议**: 🎯 改进 shortIds 生成策略

#### 问题 1: 长度固定

**现状**: 总是生成 16 字符
**官方**: 支持 0-16 字符任意长度
**影响**: 失去灵活性，增加指纹特征

**建议**:
```bash
# 新函数：生成随机长度的 shortId
xray::generate_shortid_variable() {
  local length="${1:-$((RANDOM % 17))}"  # 默认随机 0-16
  [[ "${length}" -eq 0 ]] && echo "" && return
  head -c "$((length / 2 + 1))" /dev/urandom | xxd -p -c 32 | cut -c1-"${length}"
}

# 使用示例
xray::generate_shortid_variable 8   # 生成 8 字符
xray::generate_shortid_variable 16  # 生成 16 字符
xray::generate_shortid_variable     # 随机长度
```

#### 问题 2: 单一 ID

**现状**: 默认仅生成 1 个主 ID
**官方推荐**: 3-8 个不同 ID 供客户端选择
**影响**: 无法区分不同客户端流量

**建议**:
```bash
# 默认生成 3 个不同长度的 ID
mapfile -t sids < <(
  echo ""                                    # 空字符串（必需）
  xray::generate_shortid_variable 8          # 短 ID
  xray::generate_shortid_variable 16         # 长 ID
  xray::generate_shortid_variable 12         # 中 ID
)

# 配置示例
{
  "shortIds": ["", "a1b2c3d4", "0123456789abcdef", "1a2b3c4d5e6f"]
}
```

#### 问题 3: 用户不知道如何管理

**建议**: 提供 shortId 管理命令

```bash
# 查看当前 shortIds 池
xrf shortids list

# 输出：
Current shortIds pool (3 IDs):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. ""                    (empty, required)
  2. "a1b2c3d4"            (8 chars)
  3. "0123456789abcdef"    (16 chars)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 添加新 shortId
xrf shortids add "1a2b3c4d5e6f"
[✓] Added shortId: 1a2b3c4d5e6f
[INFO] Reloading Xray configuration...
[✓] Configuration reloaded

# 删除 shortId
xrf shortids remove "a1b2c3d4"
[✓] Removed shortId: a1b2c3d4
[WARN] Clients using this shortId will be disconnected
```

---

### 1.7 spiderX 参数

**官方说明**:
- spiderX 是 **客户端参数**，不是服务器强制的
- 服务器配置的 `"spiderX": "/"` 仅是示例路径
- 客户端链接 `spx=%2F` 才是实际生效的值
- **推荐**: 每个客户端使用唯一路径（增强隐蔽性）

**xray-fusion 当前实现**: ⚠️ 所有客户端使用相同路径

```bash
# services/xray/configure.sh:151
"spiderX":"/"

# services/xray/client-links.sh:53,61
spx=%2F  # URL 编码的 "/"
```

**优化建议**: 🔒 为每个客户端生成唯一 spiderX

#### 方案 A: 安装时生成随机路径

```bash
# 生成随机爬虫路径
SPIDER_X="$(head -c 8 /dev/urandom | base64 | tr -d '/+=' | head -c 12)"
# 例如: AbCdEf123456

# 配置中使用
"spiderX": "/${SPIDER_X}"

# 客户端链接
spx=%2F${SPIDER_X}  # /AbCdEf123456
```

#### 方案 B: 多客户端场景

```bash
# 为不同客户端生成不同路径
xrf links --client alice
# spx=%2Falice_Ab12Cd34

xrf links --client bob
# spx=%2Fbob_Ef56Gh78

# 链接格式
vless://uuid@ip:443?...&spx=%2Falice_Ab12Cd34#REALITY-alice
vless://uuid@ip:443?...&spx=%2Fbob_Ef56Gh78#REALITY-bob
```

#### 方案 C: 用户自定义路径

```bash
xrf install --topology reality-only --spider-path "/custom/path"

# 生成的链接
spx=%2Fcustom%2Fpath
```

**实施优先级**: 🔒 MEDIUM (安全性增强，但非关键)

---

## 2. xray-fusion vs 官方推荐对比

### 2.1 配置结构合规性

| 配置项 | 官方要求 | xray-fusion 实现 | 符合度 |
|--------|----------|------------------|--------|
| **log** | 可选，推荐配置 | ✅ `00_log.json` | ✅ 100% |
| **inbounds** | 必需，至少 1 个 | ✅ `05_inbounds.json` | ✅ 100% |
| **outbounds** | 必需，至少 1 个 | ✅ `06_outbounds.json` | ✅ 100% |
| **routing** | 推荐配置 | ✅ `09_routing.json` | ✅ 100% |
| **多文件支持** | 支持 `-confdir` | ✅ 使用 releases 目录 | ✅ 100% |

**结论**: ✅ xray-fusion 完全遵循官方配置结构

---

### 2.2 VLESS+REALITY 配置质量

#### Reality-only 拓扑

**xray-fusion 生成的配置**:
```json
{
  "inbounds": [{
    "tag": "reality",
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "uuid", "flow": "xtls-rprx-vision"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.microsoft.com:443",
        "xver": 0,
        "serverNames": ["www.microsoft.com"],
        "privateKey": "...",
        "shortIds": ["", "0123456789abcdef"],
        "spiderX": "/"
      }
    },
    "sniffing": {
      "enabled": false,
      "destOverride": ["http", "tls", "quic"]
    }
  }]
}
```

**与官方示例对比**:

| 配置项 | 官方示例 | xray-fusion | 差异 |
|--------|----------|-------------|------|
| `protocol` | `vless` | ✅ `vless` | 一致 |
| `flow` | `xtls-rprx-vision` | ✅ `xtls-rprx-vision` | 一致 |
| `decryption` | `none` | ✅ `none` | 一致 |
| `network` | `tcp` | ✅ `tcp` | 一致 |
| `security` | `reality` | ✅ `reality` | 一致 |
| `dest` | `example.com:443` | ✅ `www.microsoft.com:443` | 合理默认 |
| `serverNames` | 数组 | ✅ 数组 | 一致 |
| `shortIds` | 包含空字符串 | ✅ `["", "..."]` | 一致 |
| `show` | `false` (生产) | ✅ `false` | 一致 |
| `xver` | `0` | ✅ `0` | 一致 |
| `spiderX` | 客户端参数 | ⚠️ 服务端固定 `/` | 可改进 |

**符合度**: ✅ **95%** (仅 spiderX 可优化)

---

#### Vision-Reality 双拓扑

**Vision 入站 (TLS 1.3)**:
```json
{
  "tag": "vision",
  "port": 8443,
  "protocol": "vless",
  "settings": {
    "clients": [{"id": "uuid", "flow": "xtls-rprx-vision"}],
    "decryption": "none",
    "fallbacks": [
      {"alpn": "h2", "dest": 8080},
      {"dest": 8080}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "tls",
    "tlsSettings": {
      "minVersion": "1.3",
      "rejectUnknownSni": true,
      "alpn": ["h2", "http/1.1"],
      "certificates": [{
        "certificateFile": "/usr/local/etc/xray/certs/fullchain.pem",
        "keyFile": "/usr/local/etc/xray/certs/privkey.pem"
      }]
    }
  }
}
```

**与官方推荐对比**:

| 配置项 | 官方推荐 | xray-fusion | 评价 |
|--------|----------|-------------|------|
| `minVersion` | `1.3` (推荐) | ✅ `1.3` | ✅ 安全 |
| `alpn` | `["h2", "http/1.1"]` | ✅ 同上 | ✅ 标准 |
| `rejectUnknownSni` | 推荐启用 | ✅ `true` | ✅ 安全增强 |
| `fallbacks` | 可选 | ✅ 配置到 Caddy | ✅ 合理 |
| ~~`ocspStapling`~~ | ❌ 已废弃 (2025-01) | ✅ 未配置 | ✅ 正确 |

**符合度**: ✅ **100%**

---

### 2.3 命令行工具使用

| 官方工具 | 用途 | xray-fusion 使用 | 状态 |
|----------|------|------------------|------|
| `xray run -test` | 配置验证 | ✅ 安装时自动验证 | ✅ 使用 |
| `xray uuid` | 生成 UUID | ❌ 使用 `uuidgen` | ⚠️ 可改进 |
| `xray x25519` | 生成密钥对 | ✅ 正确使用 | ✅ 使用 |
| `xray tls` | TLS 工具 | ❌ 未使用 | 💡 可探索 |
| `xray api` | gRPC API | ❌ 未启用 | 💡 高级功能 |

**建议**:
1. **替换 UUID 生成器**: `uuidgen` → `xray uuid`
2. **暴露验证命令**: 增加 `xrf validate` 用于手动验证
3. **探索 TLS 工具**: 用于证书验证和调试
4. **考虑 API 集成**: 动态管理用户和流量统计

---

## 3. 配置生成 UX 改进建议

### 3.1 安装前预览 (Pre-flight Summary)

**问题**: 用户不知道将要生成什么配置，直到安装完成

**解决方案**: 安装前显示配置摘要，征求确认

#### 实现示例

```bash
xrf install --topology vision-reality --domain example.com --plugins cert-auto

# 输出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Installation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Topology:     vision-reality
Domain:       example.com
Xray Version: latest (will fetch: 1.8.23)

Inbound Ports:
  • Vision:   8443  (TLS 1.3, domain: example.com)
  • Reality:  443   (SNI: www.microsoft.com)

Security:
  • Vision UUID:   6ba85179-d64e-4cb8-901f-bfb8e9e7d5f1
  • Reality UUID:  a1b2c3d4-e5f6-7890-1234-567890abcdef
  • Private Key:   gK3C8vC... (x25519)
  • Public Key:    AAAAAAA... (x25519)
  • Short IDs:     ["", "a1b2c3d4e5f67890"] (pool)

Plugins:
  ✓ cert-auto      Automatic TLS certificates via Caddy

Services:
  • xray.service            (systemd, enabled)
  • caddy.service           (systemd, enabled)
  • cert-reload.timer       (systemd, every 10min)

Firewall:
  • Allow TCP/443  (reality)
  • Allow TCP/8443 (vision)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed with installation? [Y/n]:
```

**实现位置**: `commands/install.sh` 在调用 `xray::configure` 之前

**参考**: Docker `docker run` 的容器配置预览

---

### 3.2 交互式配置向导 (Interactive Wizard)

**问题**: 新用户不熟悉 topology、domain、sni 等概念

**解决方案**: 提供交互式问答，引导配置选择

#### 实现示例

```bash
xrf install --interactive

# 或者简化为
xrf wizard

# 输出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Xray-Fusion Setup Wizard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This wizard will guide you through Xray server setup.
Press Ctrl+C at any time to cancel.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1/5: Choose deployment topology

  1) reality-only      Simple setup, no domain required
                       Best for: Personal use, IP-based access

  2) vision-reality    Dual protocol, requires domain + TLS
                       Best for: Multiple users, domain-based access

Select [1]: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 2/5: Domain configuration

Vision protocol requires a domain name with valid DNS.
Example: vpn.example.com

Enter domain: example.com

[INFO] Validating DNS...
  ✓ DNS resolves to: 93.184.216.34
  ✓ Matches server public IP
  ✓ Domain is valid

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 3/5: Certificate management

How should TLS certificates be managed?

  1) Automatic (Caddy)     Recommended, zero maintenance
  2) Manual                I'll provide certificates myself

Select [1]: 1

[INFO] cert-auto plugin will be enabled

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 4/5: REALITY camouflage target

REALITY protocol uses a target website for camouflage.

Recommended targets:
  1) www.microsoft.com    (Default, Global CDN)
  2) dl.google.com        (Best privacy, Encrypted handshake)
  3) www.cloudflare.com   (Anycast, Low latency)
  4) Custom               (Advanced)

Select [1]: 2

[INFO] Testing target: dl.google.com
  ✓ TLS 1.3 supported
  ✓ HTTP/2 enabled
  ✓ Latency: 23ms (Excellent)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 5/5: Review configuration

Topology:      vision-reality
Domain:        example.com
Certificates:  Automatic (Caddy)
REALITY SNI:   dl.google.com
Xray Version:  latest

Inbound Ports:
  • Vision (TLS):    8443
  • Reality:         443

Plugins:
  ✓ cert-auto

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Start installation? [Y/n]: y

[INFO] Installing Xray-Fusion...
```

**实现优先级**: 🎯 MEDIUM (大幅降低学习曲线)

**参考**: `npm init`, `gh repo create` 的交互式创建流程

---

### 3.3 配置模板和预设 (Templates & Presets)

**问题**: 高级用户需要快速部署标准配置

**解决方案**: 提供预定义模板

#### 实现示例

```bash
# 列出可用模板
xrf templates list

# 输出：
Available templates:

  personal-simple        Reality-only, single user
                         Port: 443, SNI: www.microsoft.com

  personal-dual          Vision + Reality, single domain
                         Ports: 8443 (Vision), 443 (Reality)
                         Includes: cert-auto plugin

  multi-user             Reality-only, 3 shortIds pool
                         Port: 443, optimized for multiple clients

  high-security          Reality + custom SNI + unique spiderX
                         Maximum camouflage settings

  performance            Vision-only, TLS 1.3, no fallbacks
                         Optimized for throughput

# 使用模板
xrf install --template personal-dual --domain example.com

# 自定义模板
xrf install --template personal-simple \
  --sni "dl.google.com" \
  --port 8443
```

**实现位置**: `lib/templates.sh` + `commands/install.sh` 集成

**参考**: Terraform 模块、Docker Compose 示例

---

### 3.4 配置 Diff 和变更预览

**问题**: 用户无法预览配置变更的影响

**解决方案**: 提供配置对比工具

#### 实现示例

```bash
# 场景：用户想更换 SNI
xrf config set --sni "dl.google.com"

# 输出：
Configuration changes to be applied:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  05_inbounds.json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  "realitySettings": {
    "dest": "www.microsoft.com:443",
-   "serverNames": ["www.microsoft.com"],
+   "serverNames": ["dl.google.com"],
  }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Impact:
  ⚠ Existing client links will break
  ⚠ Clients must update SNI to: dl.google.com

Apply changes? [y/N]: y

[INFO] Generating new configuration...
[INFO] Validating with 'xray -test'...
[✓] Configuration valid
[INFO] Restarting xray.service...
[✓] Service restarted successfully

Updated client links:
  vless://uuid@ip:443?...&sni=dl.google.com#REALITY
```

**实现优先级**: 🎯 HIGH (防止误操作)

**参考**: `terraform plan`, `git diff` 的变更对比

---

## 4. 用户引导和验证增强

### 4.1 参数验证和友好错误

**当前实现**: 参数验证存在，但错误提示不够友好

#### 案例 A: 域名验证错误

**当前输出**:
```bash
xrf install --topology vision-reality --domain "192.168.1.1"

[ERROR] invalid domain "192.168.1.1"
```

**优化输出**:
```bash
[ERROR] Invalid domain: 192.168.1.1

Reason:
  ✗ This is a private IP address (RFC 1918)
  ✗ Vision topology requires a public domain name

Valid examples:
  ✓ vpn.example.com
  ✓ proxy.yourdomain.net

Learn more: https://xray-fusion.example.com/docs/domains

Did you mean to use 'reality-only' topology instead?
  xrf install --topology reality-only  # No domain required
```

#### 案例 B: 端口冲突检测

**当前实现**: 无端口占用检测

**优化实现**:
```bash
xrf install --topology vision-reality --domain example.com

[WARN] Port 443 is already in use

Detected services using port 443:
  • nginx (PID 1234)
  • apache2 (PID 5678)

Options:
  1) Stop conflicting services (requires manual intervention)
  2) Use alternative port (e.g., 8443 for Reality)
  3) Cancel installation

Select [3]: 2

[INFO] Using port 8443 for Reality inbound
[INFO] You'll need to configure firewall accordingly
```

#### 案例 C: 依赖检测

**当前实现**: 依赖在使用时才检测

**优化实现**:
```bash
xrf install --topology reality-only

[INFO] Checking prerequisites...
  ✓ Bash 4.0+           (5.1.16)
  ✓ OpenSSL             (3.0.2)
  ✓ jq                  (1.6)
  ✓ systemd             (250)
  ✗ curl                Not found

[ERROR] Missing required dependencies

Install missing packages:
  # Debian/Ubuntu
  sudo apt-get install curl

  # CentOS/RHEL
  sudo yum install curl

After installing, retry: xrf install
```

**实现优先级**: 🔥 HIGH (直接减少用户困惑)

---

### 4.2 安装后验证和健康检查

**问题**: 用户不知道安装是否成功，服务是否正常运行

**解决方案**: 自动执行安装后检查

#### 实现示例

```bash
xrf install --topology reality-only

# ... 安装过程 ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Installation Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Running post-installation checks...

System Status:
  ✓ xray.service        Active (running)
  ✓ Xray process        PID 12345, uptime 2s
  ✓ Configuration       Valid (xray -test passed)

Network:
  ✓ Port 443            Listening (0.0.0.0)
  ✓ Firewall            TCP/443 allowed
  ✓ Public IP           93.184.216.34

Configuration:
  ✓ Reality inbound     Enabled
  ✓ XTLS Vision         Enabled
  ✓ Private key         Loaded
  ✓ Short IDs           2 in pool

Client Links:
  REALITY: vless://uuid@93.184.216.34:443?...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next steps:
  1. Copy client link above to your device
  2. Import link in Xray client (v2rayN, v2rayNG, etc.)
  3. Test connection: xrf test-connection
  4. View logs: journalctl -u xray -f

Documentation: https://xray-fusion.example.com/docs/getting-started
```

**包含检查**:
- ✅ Systemd 服务状态
- ✅ Xray 进程运行
- ✅ 配置文件验证
- ✅ 端口监听
- ✅ 防火墙规则
- ✅ 公网 IP 检测
- ✅ 证书有效性（vision-reality）

**参考**: `docker ps`, `kubectl get pods` 的健康检查

---

### 4.3 连接测试工具

**问题**: 用户不知道如何验证服务器配置正确

**解决方案**: 提供内置连接测试

#### 实现示例

```bash
xrf test-connection

# 输出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Connection Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Testing Reality endpoint: 93.184.216.34:443

  [1/5] DNS resolution...             ✓ Passed (15ms)
  [2/5] TCP handshake...              ✓ Passed (42ms)
  [3/5] TLS handshake (REALITY)...   ✓ Passed (89ms)
  [4/5] VLESS authentication...       ✓ Passed (101ms)
  [5/5] Data transfer...              ✓ Passed (125ms, 1.2 MB/s)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Result: ✓ ALL TESTS PASSED

Server is reachable and accepting connections.
Client link is valid and ready to use.

Performance:
  • Latency:     89ms
  • Throughput:  1.2 MB/s (test transfer)

Next: Import client link to your Xray client application.
```

**高级功能**: 外部测试（从客户端视角）

```bash
xrf test-connection --external

# 输出：
[INFO] Testing from external perspective...
[INFO] Using public connectivity check service...

External Connectivity:
  ✓ Server is reachable from internet
  ✓ Port 443 is open
  ✓ TLS handshake successful
  ✓ No firewall blocking detected

Camouflage Test (REALITY):
  ✓ SNI handshake mimics: www.microsoft.com
  ✓ Certificate chain matches target
  ✓ No anomalies detected
```

**实现优先级**: 🔥 HIGH (用户最常见需求)

---

## 5. 错误处理和故障排除

### 5.1 结构化错误代码

**问题**: 当前错误使用文本描述，难以编程处理

**解决方案**: 引入错误代码系统

#### 错误代码设计

```bash
# 错误代码格式: XRF-CATEGORY-NUMBER
XRF-CONFIG-001   Invalid topology
XRF-CONFIG-002   Missing required parameter
XRF-CONFIG-003   Port conflict
XRF-NETWORK-001  DNS resolution failed
XRF-NETWORK-002  Port not accessible
XRF-CERT-001     Certificate not found
XRF-CERT-002     Certificate expired
XRF-XRAY-001     Xray binary not found
XRF-XRAY-002     Configuration test failed
```

#### 实现示例

**当前错误**:
```bash
[ERROR] invalid domain "192.168.1.1"
```

**优化错误**:
```bash
[ERROR] XRF-CONFIG-004: Invalid domain

Domain: 192.168.1.1
Reason: Private IP address not allowed (RFC 1918)

Resolution:
  Use a public domain name for vision-reality topology, or
  Switch to reality-only topology which supports IP addresses.

Examples:
  xrf install --topology vision-reality --domain vpn.example.com
  xrf install --topology reality-only  # No domain needed

Learn more: https://xray-fusion.example.com/errors/XRF-CONFIG-004
```

**JSON 输出**（便于脚本解析）:
```bash
XRF_JSON=true xrf install --domain "192.168.1.1"

# 输出：
{
  "ts": "2025-11-11T12:34:56Z",
  "level": "error",
  "error_code": "XRF-CONFIG-004",
  "msg": "Invalid domain",
  "details": {
    "domain": "192.168.1.1",
    "reason": "Private IP address not allowed (RFC 1918)",
    "suggestions": [
      "Use public domain name",
      "Switch to reality-only topology"
    ],
    "docs": "https://xray-fusion.example.com/errors/XRF-CONFIG-004"
  }
}
```

---

### 5.2 自动故障诊断

**问题**: 用户遇到问题时不知道如何调试

**解决方案**: 提供诊断工具

#### 实现示例

```bash
xrf diagnose

# 输出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Xray-Fusion Diagnostic Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Date: 2025-11-11 12:34:56 UTC
Hostname: vpn-server
Kernel: Linux 5.15.0-generic

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  System Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Operating System      Ubuntu 22.04 LTS
✓ Bash Version          5.1.16
✓ Systemd               250
✓ OpenSSL               3.0.2
✓ jq                    1.6
✓ curl                  7.81.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Xray Installation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Xray Binary           /usr/local/bin/xray
✓ Xray Version          1.8.23
✓ Configuration Dir     /usr/local/etc/xray/active
✓ Config Files          4 files
  • 00_log.json         (142 bytes)
  • 05_inbounds.json    (458 bytes)
  • 06_outbounds.json   (89 bytes)
  • 09_routing.json     (52 bytes)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Syntax Check          Passed (xray -test)
✓ Inbound Ports         443
✓ Outbound Routes       2 (direct, block)
✓ Reality Settings      Valid
  • SNI:                www.microsoft.com
  • Private Key:        Present (64 chars)
  • Short IDs:          2 in pool

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Service Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ xray.service          Active (running)
  • PID:                12345
  • Uptime:             2 days 5 hours
  • Memory:             28.3 MB
  • Restart Count:      0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Network Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Public IP             93.184.216.34
✓ Port 443 Listening    0.0.0.0:443 (Xray)
✓ Firewall (ufw)        Active
  • Allow TCP/443       ✓ Present

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Recent Logs (last 10 lines)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Nov 11 12:30:15 xray[12345]: [Info] transport/internet/tcp: listening TCP on 0.0.0.0:443
Nov 11 12:30:15 xray[12345]: [Info] Xray 1.8.23 started

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status: ✓ HEALTHY

All checks passed. Xray is running normally.

If you're experiencing connection issues, run:
  xrf test-connection --external
```

**高级诊断**: 特定问题检测

```bash
xrf diagnose --issue connection-refused

# 输出：
Diagnosing: Connection Refused

Checking common causes...

✗ Port Accessibility
  Port 443 is NOT reachable from external network

Possible reasons:
  1. Firewall blocking incoming connections
     Check: sudo iptables -L -n | grep 443
     Fix:   sudo ufw allow 443/tcp

  2. Cloud security group not configured
     Check your cloud provider's security group settings.
     AWS:    EC2 → Security Groups → Inbound Rules
     GCP:    VPC → Firewall Rules
     Azure:  Network Security Groups

  3. SELinux blocking Xray
     Check: sudo ausearch -m AVC -ts recent | grep xray
     Fix:   sudo setenforce 0 (temporary)

Run diagnostic after fixing:
  xrf test-connection --external
```

**实现优先级**: 🔥 HIGH (减少 90% support 负担)

---

### 5.3 日志分析和可读化

**问题**: Xray 日志是机器可读的 JSON，用户难以理解

**解决方案**: 提供日志解析工具

#### 实现示例

```bash
xrf logs

# 输出：人类可读格式
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Xray Logs (last 50 lines)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

12:34:56  INFO  TCP listener started on 0.0.0.0:443
12:35:10  INFO  New connection from 203.0.113.45
12:35:11  INFO  VLESS handshake successful (uuid: 6ba85179...)
12:35:11  INFO  Routing to: direct
12:35:12  INFO  Connection closed (duration: 1.2s, tx: 1.5 MB, rx: 523 KB)

12:36:20  WARN  Connection rejected: invalid shortId (client: 198.51.100.23)
12:37:05  ERROR Failed authentication (uuid: invalid-uuid)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Filters:
  xrf logs --level error          # Show errors only
  xrf logs --since "1 hour ago"   # Last hour
  xrf logs --follow               # Real-time tail

Statistics:
  xrf logs --stats                # Connection statistics
```

**日志统计**:
```bash
xrf logs --stats --since "24 hours ago"

# 输出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Traffic Statistics (Last 24 Hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Connections:
  • Total:          1,234 connections
  • Successful:     1,198 (97.1%)
  • Rejected:       36 (2.9%)

Rejection Reasons:
  • Invalid UUID:         20
  • Invalid shortId:      12
  • Authentication fail:  4

Traffic:
  • Upload:         12.3 GB
  • Download:       45.6 GB
  • Total:          57.9 GB

Top Clients (by traffic):
  1. 203.0.113.45       15.2 GB
  2. 198.51.100.23      8.7 GB
  3. 192.0.2.100        6.1 GB

Peak Hours:
  • 14:00-15:00         8.2 GB
  • 20:00-21:00         7.5 GB
```

**实现优先级**: 🎯 MEDIUM (改善可观测性)

---

## 6. 高级功能暴露

### 6.1 配置热更新

**问题**: 修改配置需要完整重装或手动编辑

**解决方案**: 提供配置更新命令

#### 实现示例

```bash
# 更新单个配置项
xrf config set sni "dl.google.com"
xrf config set port 8443
xrf config set log-level "info"

# 批量更新
xrf config set \
  --sni "dl.google.com" \
  --port 8443 \
  --log-level "info"

# 查看当前配置
xrf config show

# 输出：
Current Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Topology:      reality-only
Xray Version:  1.8.23

Inbound:
  • Port:      443
  • Protocol:  vless + reality
  • Flow:      xtls-rprx-vision

Security:
  • UUID:      6ba85179-d64e-4cb8-901f-bfb8e9e7d5f1
  • SNI:       www.microsoft.com
  • Short IDs: ["", "a1b2c3d4e5f67890"]

Logging:
  • Level:     warning
  • Access:    none
  • Error:     none
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 导出配置为 JSON
xrf config export > config.json

# 导入配置
xrf config import config.json
```

**参考**: `kubectl edit`, `docker update` 的配置更新

---

### 6.2 多用户管理

**问题**: 当前仅支持单用户 UUID

**解决方案**: 提供用户管理命令

#### 实现示例

```bash
# 添加用户
xrf users add alice
[✓] User added: alice
    UUID: b0d82e7d-4d24-5b5c-9b6e-3c4e1f0a8c9d
    Link: vless://b0d82e7d@...

# 列出用户
xrf users list

# 输出：
Users (3 total):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  alice    b0d82e7d-4d24-5b5c-9b6e-3c4e1f0a8c9d    Active
  bob      c1d93f8e-5e35-6c6d-0c7f-4d1f1b9d0a0e    Active
  charlie  d2e04g9f-6f46-7d7e-1d8g-5e2g2c0e1b1f    Suspended

# 删除用户
xrf users remove bob
[WARN] This will disconnect user 'bob' immediately.
Confirm? [y/N]: y
[✓] User removed: bob

# 暂停用户
xrf users suspend charlie
[✓] User suspended: charlie (can be resumed with 'resume' command)

# 获取用户链接
xrf users link alice
vless://b0d82e7d@93.184.216.34:443?...
```

**高级功能**: 用户流量统计

```bash
xrf users stats alice --since "7 days ago"

# 输出：
User: alice
UUID: b0d82e7d-4d24-5b5c-9b6e-3c4e1f0a8c9d
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Traffic (Last 7 Days):
  • Upload:       2.3 GB
  • Download:     8.7 GB
  • Total:        11.0 GB

Connections:
  • Total:        156
  • Average:      22/day

Active Times:
  • Most active:  14:00-16:00 (weekdays)
  • Last seen:    2025-11-11 12:34:56
```

**实现优先级**: 🎯 MEDIUM (多用户场景需求)

**参考**: `xray api` 的 gRPC API（需要启用）

---

### 6.3 备份和恢复

**问题**: 用户无法轻松迁移或恢复配置

**解决方案**: 提供备份/恢复工具

#### 实现示例

```bash
# 创建备份
xrf backup create

# 输出：
[INFO] Creating backup...
  ✓ Xray configuration
  ✓ TLS certificates (if any)
  ✓ State database
  ✓ Plugin configurations

[✓] Backup created: /var/backups/xray-fusion/backup-20251111-123456.tar.gz
    Size: 2.3 MB

# 列出备份
xrf backup list

# 输出：
Available backups:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  backup-20251111-123456.tar.gz    2.3 MB    2 minutes ago
  backup-20251110-083012.tar.gz    2.1 MB    1 day ago
  backup-20251109-140523.tar.gz    2.0 MB    2 days ago

# 恢复备份
xrf backup restore backup-20251111-123456.tar.gz

# 输出：
[WARN] This will replace current configuration!
[WARN] Current config will be backed up first.

Proceed? [y/N]: y

[INFO] Backing up current config...
[✓] Current config saved: backup-current-20251111-123500.tar.gz

[INFO] Restoring from backup...
  ✓ Xray configuration extracted
  ✓ Certificates restored
  ✓ State database restored
  ✓ Configuration validated (xray -test)

[INFO] Restarting services...
[✓] xray.service restarted

[✓] Restore complete

# 自动备份（定时任务）
xrf backup schedule --daily --keep 7

# 输出：
[INFO] Configuring automatic backups...
[✓] Systemd timer created: xray-fusion-backup.timer
    Schedule: Daily at 02:00 UTC
    Retention: 7 days (older backups auto-deleted)

View schedule: systemctl status xray-fusion-backup.timer
```

**实现优先级**: 🎯 MEDIUM (灾难恢复需求)

---

## 7. 实施优先级和快速胜利

### 7.1 优先级矩阵

| 功能 | 影响 | 实施难度 | 优先级 | 预计时间 |
|------|------|----------|--------|----------|
| **安装前预览** | 高 | 低 | 🔥 HIGH | 2-3h |
| **参数验证增强** | 高 | 低 | 🔥 HIGH | 3-4h |
| **安装后健康检查** | 高 | 中 | 🔥 HIGH | 4-6h |
| **连接测试工具** | 高 | 中 | 🔥 HIGH | 4-6h |
| **错误代码系统** | 高 | 中 | 🔥 HIGH | 6-8h |
| **SNI 验证和选择** | 高 | 中 | 🔥 HIGH | 4-6h |
| **自动诊断工具** | 高 | 高 | 🔥 HIGH | 8-12h |
| **UUID 生成改进** | 中 | 低 | 🎯 MEDIUM | 1-2h |
| **交互式向导** | 高 | 高 | 🎯 MEDIUM | 12-16h |
| **配置 Diff** | 中 | 中 | 🎯 MEDIUM | 4-6h |
| **日志解析** | 中 | 中 | 🎯 MEDIUM | 6-8h |
| **配置热更新** | 中 | 中 | 🎯 MEDIUM | 6-8h |
| **多用户管理** | 中 | 高 | 💡 LOW | 12-16h |
| **备份恢复** | 低 | 中 | 💡 LOW | 6-8h |
| **配置模板** | 低 | 低 | 💡 LOW | 4-6h |

---

### 7.2 快速胜利（Quick Wins）

**Phase 1: 立即改进（1-2 天）**

1. ✅ **UUID 生成改进** (1-2h)
   - 替换 `uuidgen` 为 `xray uuid`
   - 支持 `--uuid-from-string` 参数

2. ✅ **安装前预览** (2-3h)
   - 显示即将安装的配置摘要
   - 征求用户确认

3. ✅ **参数验证增强** (3-4h)
   - 改进错误消息，包含原因和建议
   - 添加 "Did you mean?" 提示

4. ✅ **SNI 验证基础版** (2-3h)
   - 检测 TLS 1.3 和 H2 支持
   - 警告不合适的目标

**Phase 2: 核心 UX 增强（3-5 天）**

5. ✅ **安装后健康检查** (4-6h)
   - 验证服务状态、端口监听、配置有效性
   - 显示下一步操作

6. ✅ **连接测试工具** (4-6h)
   - `xrf test-connection` 命令
   - 端到端连接验证

7. ✅ **错误代码系统** (6-8h)
   - 定义错误代码规范
   - 重构现有错误消息
   - 生成在线文档链接

8. ✅ **SNI 交互式选择** (3-4h)
   - 推荐目标列表
   - 自动验证自定义目标

**Phase 3: 高级功能（1-2 周）**

9. ✅ **自动诊断工具** (8-12h)
   - `xrf diagnose` 命令
   - 常见问题检测和修复建议

10. ✅ **交互式向导** (12-16h)
    - 新用户友好的安装流程
    - 逐步配置指导

11. ✅ **配置热更新** (6-8h)
    - `xrf config set` 命令
    - 自动验证和应用

12. ✅ **日志解析** (6-8h)
    - 人类可读的日志输出
    - 流量统计

---

### 7.3 实施路线图

#### Sprint 1: 基础 UX（Week 1）

**目标**: 改善首次安装体验

- [ ] UUID 生成切换到 `xray uuid`
- [ ] 安装前配置预览
- [ ] 参数验证错误增强
- [ ] SNI 基础验证
- [ ] 安装后健康检查

**预期成果**:
- 用户知道将要安装什么
- 错误消息更清晰、可操作
- 安装成功率提升

#### Sprint 2: 核心工具（Week 2）

**目标**: 提供故障排查工具

- [ ] 连接测试工具 (`xrf test-connection`)
- [ ] 错误代码系统
- [ ] 自动诊断 (`xrf diagnose`)
- [ ] 日志解析器 (`xrf logs`)

**预期成果**:
- 用户可以自助解决 80% 常见问题
- Support 负担显著降低

#### Sprint 3: 高级 UX（Week 3-4）

**目标**: 完善用户体验

- [ ] 交互式安装向导
- [ ] 配置热更新
- [ ] SNI 交互式选择
- [ ] 配置 Diff 预览

**预期成果**:
- 新用户无需阅读文档即可安装
- 配置更改可视化、安全

#### Sprint 4: 高级功能（Week 5-6）

**目标**: 企业级特性

- [ ] 多用户管理
- [ ] 备份和恢复
- [ ] 配置模板系统
- [ ] Traffic 统计

**预期成果**:
- 支持生产环境部署
- 多用户场景完整支持

---

## 结论

### 关键发现

1. **xray-fusion 已经正确实现了 Xray 核心配置**
   - ✅ VLESS+REALITY 配置符合官方规范
   - ✅ TLS 1.3 安全配置正确
   - ✅ 使用官方 `xray x25519` 生成密钥
   - ✅ 配置验证使用 `xray -test`

2. **主要 UX 差距在于用户引导和可见性**
   - ⚠️ 缺少安装前预览和确认
   - ⚠️ 错误消息不够友好和可操作
   - ⚠️ 缺少安装后验证和健康检查
   - ⚠️ 高级功能（UUID 映射、SNI 验证）未暴露

3. **Quick Wins 可以快速提升用户体验**
   - 🚀 安装前预览（2-3h）
   - 🚀 参数验证增强（3-4h）
   - 🚀 安装后健康检查（4-6h）
   - 🚀 连接测试工具（4-6h）

### 推荐行动

**立即执行**（本周内）:
1. 实施 Phase 1 快速胜利（~15h 工作量）
2. 建立错误代码规范
3. 改进安装流程可见性

**短期目标**（2-4 周）:
1. 完成核心 UX 增强（Sprint 1-2）
2. 提供完整的故障诊断工具
3. 优化 SNI 选择和验证

**长期目标**（1-2 个月）:
1. 交互式向导（降低学习曲线）
2. 多用户管理（企业场景）
3. 完整的配置管理系统

### UX 成熟度提升预期

**当前**: 4.75/10（功能完整，UX 粗糙）

**Phase 1 后**: 6.5/10（基础 UX 改进）
- ✅ 清晰的安装流程
- ✅ 友好的错误提示
- ✅ 基础健康检查

**Phase 2 后**: 8.0/10（核心工具完善）
- ✅ 完整的诊断工具
- ✅ 自助故障排查
- ✅ 可视化配置

**Phase 3-4 后**: 9.0/10（企业级 UX）
- ✅ 交互式向导
- ✅ 高级配置管理
- ✅ 多用户支持

---

## 参考资料

### Xray 官方文档
- [Configuration Guide](https://xtls.github.io/en/config/)
- [VLESS Protocol](https://xtls.github.io/en/config/inbounds/vless.html)
- [REALITY Examples](https://github.com/XTLS/Xray-examples/blob/main/VLESS-TCP-XTLS-Vision-REALITY/REALITY.ENG.md)
- [Command-Line Options](https://xtls.github.io/en/document/command.html)

### 顶级项目 UX 参考
- Docker CLI: 安装前预览、健康检查
- Kubernetes kubectl: 配置 Diff、资源管理
- Terraform: 变更预览、错误代码
- GitHub CLI: 交互式向导、友好错误
- Vercel CLI: 部署前确认、实时日志

### xray-fusion 现有文档
- [UX Analysis](../UX_ANALYSIS.md) - 初步 UX 分析
- [UX Research References](../UX_RESEARCH_REFERENCES.md) - 实现参考
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - 故障排查指南
- [AGENTS.md](../AGENTS.md) - 开发规范

---

**文档维护**: 本文档应随 Xray 官方文档更新和 xray-fusion 实施进度定期更新。

**反馈**: 如有 UX 改进建议，请在项目 GitHub 创建 issue。
