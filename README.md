# Xray-Fusion

轻量级 Xray 管理工具，专注于简单可靠的部署体验。

[![Tests](https://github.com/Joe-oss9527/xray-fusion/actions/workflows/test.yml/badge.svg)](https://github.com/Joe-oss9527/xray-fusion/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 特性

- ✅ **自动化部署**: 一键安装，开箱即用
- ✅ **双拓扑支持**: Reality-only / Vision-Reality 双模式
- ✅ **配置模板**: 预定义场景模板（个人/团队/生产），快速部署
- ✅ **备份和恢复**: 自动备份、SHA256验证、原子恢复
- ✅ **日志管理**: 多级别过滤、实时追踪、统计导出
- ✅ **自动证书管理**: 集成 Caddy + Let's Encrypt
- ✅ **插件系统**: 模块化扩展，按需启用
- ✅ **全面测试**: 472个单元测试 + 集成测试，~85% 覆盖率
- ✅ **安全加固**: RFC 合规验证，systemd 安全加固
- ✅ **完善文档**: ShellDoc API 文档，故障排查指南

## 文档

- 📖 [Installation Guide](#快速开始) - 快速安装指南
- 🔧 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 故障排查指南
- 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献指南
- 📋 [CHANGELOG.md](CHANGELOG.md) - 版本变更历史
- 🏗️ [AGENTS.md](AGENTS.md) - 开发规范和技术细节
- 💡 [CLAUDE.md](CLAUDE.md) - 架构决策记录 (ADRs)

## 快速开始

### 一键安装
```bash
# Reality-only 模式（推荐）
curl -sL https://github.com/Joe-oss9527/xray-fusion/raw/main/install.sh | bash -s -- --topology reality-only

# Vision + Reality 双模式（需要域名）
curl -sL https://github.com/Joe-oss9527/xray-fusion/raw/main/install.sh | bash -s -- --topology vision-reality --domain your.domain.com --plugins cert-auto
```

### 一键卸载
```bash
curl -sL https://github.com/Joe-oss9527/xray-fusion/raw/main/uninstall.sh | bash
```

## 部署模式

### Reality-only
- **特点**：无需域名，伪装 SNI，隐蔽性强
- **端口**：443
- **用法**：开箱即用，适合个人使用

### Vision-Reality
- **特点**：真实 TLS + Reality 备用，双重保护
- **端口**：8443 (Vision), 443 (Reality)
- **要求**：需要域名所有权和自动证书管理

## 命令参数

### 基本语法
```bash
# 一键安装
curl -sL install.sh | bash -s -- [参数]

# 手动安装
bin/xrf install [参数]
```

### 可用参数
```bash
--topology reality-only|vision-reality  # 部署拓扑（必需）
--domain <domain>                       # 域名（vision-reality 模式必需）
--version <version>                     # Xray 版本（默认：latest）
--plugins <plugin1,plugin2>             # 启用插件列表，逗号分隔
--uuid <uuid>                           # 自定义 UUID（可选，默认自动生成）
--uuid-from-string <string>             # 从字符串生成 UUID（可选，便于记忆）
--debug                                 # 调试模式
```

### 完整示例
```bash
# Reality-only 基础安装
curl -sL install.sh | bash -s -- --topology reality-only

# Reality-only 带防火墙和日志插件
curl -sL install.sh | bash -s -- --topology reality-only --plugins firewall,logrotate-obs

# Vision-Reality 带自动证书
curl -sL install.sh | bash -s -- --topology vision-reality --domain example.com --plugins cert-auto

# 指定版本的完整安装
curl -sL install.sh | bash -s -- --topology vision-reality --domain example.com --version v1.8.0 --plugins cert-auto,firewall

# 使用自定义 UUID
curl -sL install.sh | bash -s -- --topology reality-only --uuid 6ba85179-d64e-4cb8-901f-bfb8e9e7d5f1

# 从字符串生成 UUID（便于记忆，每次相同）
curl -sL install.sh | bash -s -- --topology reality-only --uuid-from-string "alice"
```

## 配置模板

使用预定义模板快速部署常见场景，无需手动配置参数。

### 可用模板

| 模板 ID | 名称 | 拓扑 | 适用场景 | 插件 |
|--------|------|------|---------|------|
| `home` | Home User | reality-only | 个人用户，单设备访问 | - |
| `office` | Office/Team | vision-reality | 小型团队，5-20人 | cert-auto, firewall |
| `server` | Production Server | vision-reality | 生产环境，50+用户 | cert-auto, firewall, monitoring |

### 模板使用

```bash
# 查看可用模板
bin/xrf templates list

# 查看模板详情
bin/xrf templates show home

# 使用模板安装（模板值作为默认值）
curl -sL install.sh | bash -s -- --template home

# 使用模板 + 自定义参数（CLI 参数覆盖模板）
curl -sL install.sh | bash -s -- --template office --domain vpn.company.com

# 使用模板但覆盖拓扑
curl -sL install.sh | bash -s -- --template server --topology reality-only
```

### 模板优先级

配置参数的优先级从高到低：
1. **CLI 显式参数**（最高优先级）
2. **模板值**（默认值）
3. **系统默认值**（最低优先级）

示例：
```bash
# office 模板默认 vision-reality，但 CLI 指定 reality-only 会覆盖
--template office --topology reality-only  # 最终使用 reality-only

# office 模板包含 cert-auto,firewall 插件，CLI 指定 monitoring 会合并
--template office --plugins monitoring     # 最终启用 cert-auto,firewall,monitoring
```

### 模板详情

#### Home User 模板
- **拓扑**: reality-only (无需域名)
- **端口**: 443
- **SNI**: www.microsoft.com
- **插件**: 无
- **适用**: 个人用户，单设备访问

#### Office/Team 模板
- **拓扑**: vision-reality (需要域名)
- **端口**: Vision 8443, Reality 443
- **SNI**: www.cloudflare.com
- **插件**: cert-auto, firewall
- **适用**: 小型团队，5-20人

#### Production Server 模板
- **拓扑**: vision-reality (需要域名)
- **端口**: Vision 8443, Reality 443
- **SNI**: www.apple.com,www.icloud.com
- **插件**: cert-auto, firewall, monitoring
- **安全**: 严格安全设置，TLS 1.3 only
- **适用**: 生产环境，50+并发用户

## 插件系统

### 可用插件
- **cert-auto**: 自动证书管理（Caddy + Let's Encrypt）
- **firewall**: 防火墙端口管理
- **logrotate-obs**: 日志轮转和观测
- **links-qr**: 连接二维码生成

### 插件使用
推荐在安装时通过 `--plugins` 参数启用：

```bash
# 单个插件
--plugins cert-auto

# 多个插件
--plugins cert-auto,firewall,logrotate-obs
```

## 日志查看

### 基本用法
```bash
# 查看最近100行日志
bin/xrf logs

# 查看实时日志
bin/xrf logs --follow

# 按级别过滤
bin/xrf logs --level error   # 仅错误
bin/xrf logs --level warn    # 警告和错误

# 时间范围
bin/xrf logs --since "1 hour ago"
bin/xrf logs --since "2023-12-01 10:00:00"
```

### 日志导出
```bash
# 导出到文件
bin/xrf logs --export /path/to/logs.txt

# 导出错误日志
bin/xrf logs --level error --export errors.txt

# 统计信息
bin/xrf logs --stats
```

## 备份和恢复

### 创建备份
```bash
# 自动备份（系统生成名称）
bin/xrf backup create

# 指定备份名称
bin/xrf backup create pre-upgrade

# 安装时自动备份
# 如果检测到现有安装，install 命令会自动创建备份
bin/xrf install --topology reality-only
# 输出：[INFO] Automatic backup created: pre-install-20231201-120000
```

### 查看备份
```bash
# 列出所有备份
bin/xrf backup list

# JSON 格式输出
XRF_JSON=true bin/xrf backup list
```

### 恢复备份
```bash
# 恢复指定备份（自动创建恢复前备份）
bin/xrf backup restore pre-upgrade-20231201-120000

# 列出备份后选择恢复
bin/xrf backup list
bin/xrf backup restore <backup-name>
```

### 验证和删除
```bash
# 验证备份完整性（SHA256）
bin/xrf backup verify pre-upgrade-20231201-120000

# 删除备份
bin/xrf backup delete old-backup-20231101-090000
```

### 备份策略
- **自动备份**：安装前自动创建备份（如果存在现有安装）
- **完整性验证**：SHA256 哈希验证确保备份完整性
- **自动清理**：保留最近 10 个备份，自动删除旧备份
- **原子恢复**：恢复前自动创建当前配置备份，支持回滚

## 手动管理

如需本地开发或高级配置：

```bash
# 克隆仓库
git clone https://github.com/Joe-oss9527/xray-fusion.git
cd xray-fusion

# 安装
bin/xrf install --topology reality-only
bin/xrf install --topology vision-reality --domain your.domain.com --plugins cert-auto

# 管理
bin/xrf status    # 查看状态
bin/xrf links     # 查看连接信息
bin/xrf uninstall # 卸载

# 插件管理（可选）
bin/xrf plugin list
bin/xrf plugin enable cert-auto
bin/xrf plugin disable cert-auto
```

## 高级配置

### 环境变量

可通过环境变量自定义配置：

```bash
# Caddy 端口配置（cert-auto 插件）
CADDY_HTTP_PORT=80          # HTTP 端口（默认 80）
CADDY_HTTPS_PORT=8444       # HTTPS 端口（默认 8444，避免与 Vision 8443 冲突）
CADDY_FALLBACK_PORT=8080    # Fallback 服务端口（默认 8080）

# Xray 配置
XRAY_VISION_PORT=8443       # Vision 端口（vision-reality 模式）
XRAY_REALITY_PORT=443       # Reality 端口
XRAY_SNI=www.microsoft.com  # Reality 伪装域名
```

### 配置说明

**端口分配** (vision-reality 模式):
- **443**: Reality 入口（推荐，符合官方最佳实践）
- **8443**: Vision 入口（真实 TLS）
- **8444**: Caddy HTTPS（自动证书管理，避免冲突）
- **8080**: Caddy Fallback（处理非代理流量）

**TLS 配置**: Vision 使用 Go 自动协商 TLS 版本（支持 TLS 1.2+，优先 TLS 1.3，符合 Xray-core 官方推荐）

## 系统要求

- Ubuntu/Debian/CentOS/RHEL
- systemd
- curl, unzip
- 64位系统

## 开发

### 代码质量

[![Tests](https://github.com/Joe-oss9527/xray-fusion/actions/workflows/test.yml/badge.svg)](https://github.com/Joe-oss9527/xray-fusion/actions/workflows/test.yml)

```bash
# 代码格式化
make fmt

# 代码检查
make lint

# 运行测试
make test

# 运行单元测试
make test-unit
```

### 测试框架

项目使用 [bats-core](https://github.com/bats-core/bats-core) 测试框架：

```bash
# 安装 bats-core
sudo apt-get install bats  # Ubuntu/Debian
brew install bats-core      # macOS

# 运行所有测试
bats tests/unit/*.bats

# 详细输出
bats -t tests/unit/*.bats
```

**测试覆盖率**:
- ✅ lib/args.sh: 100% (21 tests - 参数验证)
- ✅ lib/core.sh: ~85% (8 tests - 核心功能)
- ✅ lib/plugins.sh: ~90% (26 tests - 插件系统)
- ✅ lib/validators.sh: 100% (9 tests - RFC 合规验证)
- ✅ modules/io.sh: ~95% (21 tests - IO 操作)
- ✅ services/xray/common.sh: 100% (20 tests - 路径管理)
- **整体覆盖率**: ~80% (96 个单元测试 + 6 个集成测试)

### CI/CD

项目配置了完整的 GitHub Actions 工作流：

- 🔍 **Lint**: ShellCheck 静态分析
- 📐 **Format Check**: shfmt 格式验证
- 🧪 **Unit Tests**: 多版本 Ubuntu 测试
- 🔒 **Security Scan**: 安全检查

所有提交和 PR 会自动运行测试。

## 许可证

MIT License