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
- **用法**：开箱即用

### Vision-Reality
- **特点**：真实 TLS + Reality 备用，双重保护
- **端口**：8443 (Vision), 443 (Reality)
- **要求**：需要域名所有权

## 手动管理

```bash
# 克隆仓库
git clone https://github.com/Joe-oss9527/xray-fusion.git
cd xray-fusion

# 安装 Reality-only
bin/xrf install --topology reality-only

# 安装 Vision-Reality（需要域名）
bin/xrf install --topology vision-reality --domain your.domain.com --plugins cert-auto

# 查看连接信息
bin/xrf links

# 查看状态
bin/xrf status

# 卸载
bin/xrf uninstall
```

## 配置选项

### 基础配置
```bash
export XRAY_SNI=www.microsoft.com    # SNI 伪装域名
export XRAY_PORT=443                 # 监听端口
export XRAY_SNIFFING=false           # 流量嗅探
```

### Vision-Reality 配置
```bash
export XRAY_DOMAIN=your.domain.com   # 真实域名
export XRAY_VISION_PORT=8443         # Vision 端口
export XRAY_REALITY_PORT=443         # Reality 端口
```

## 插件系统

### 可用插件
- **cert-auto**: 自动证书管理（Caddy + Let's Encrypt）
- **firewall**: 防火墙端口管理
- **logrotate-obs**: 日志轮转和观测
- **links-qr**: 连接二维码生成

### 插件管理
```bash
# 启用插件
bin/xrf plugin enable cert-auto

# 禁用插件
bin/xrf plugin disable cert-auto

# 查看插件
bin/xrf plugin list
```

## 开发

```bash
# 代码格式化
make fmt

# 代码检查
make lint
```

## 系统要求

- Ubuntu/Debian/CentOS/RHEL
- systemd
- curl, unzip
- 64位系统

## 许可证

MIT License