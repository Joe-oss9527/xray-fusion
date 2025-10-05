# Xray-Fusion

轻量级 Xray 管理工具，专注于简单可靠的部署体验。

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
```

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

```bash
# 代码格式化
make fmt

# 代码检查
make lint
```

## 许可证

MIT License