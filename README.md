```
 ██╗  ██╗██████╗  █████╗ ██╗   ██╗      ███████╗██╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗
 ╚██╗██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝      ██╔════╝██║   ██║██╔════╝██║██╔═══██╗████╗  ██║
  ╚███╔╝ ██████╔╝███████║ ╚████╔╝ █████╗█████╗  ██║   ██║███████╗██║██║   ██║██╔██╗ ██║
  ██╔██╗ ██╔══██╗██╔══██║  ╚██╔╝  ╚════╝██╔══╝  ██║   ██║╚════██║██║██║   ██║██║╚██╗██║
 ██╔╝ ██╗██║  ██║██║  ██║   ██║         ██║     ╚██████╔╝███████║██║╚██████╔╝██║ ╚████║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝         ╚═╝      ╚═════╝ ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

# xray-fusion-lite (complete, clean, pluginized)

**目标**：极简、可维护、可观测。核心仅负责：安装 Xray → 渲染分片配置（`-confdir`）→ 原子切换 `active` → systemd 单元。其余全部插件化（证书 / 防火墙 / 链接二维码 / 日志轮转）。

## 🚀 一键安装

### 基础安装
```bash
# Reality-only 拓扑，默认端口 443，自动生成配置
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash
```

### 自定义 SNI 域名安装
```bash
# Reality-only 拓扑，自定义 SNI 伪装域名
XRAY_SNI=your.domain.com \
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash
```

### 高级安装
```bash
# Vision + Reality 拓扑，启用证书和日志插件
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- \
  --topology vision-reality \
  --enable-plugins cert-auto,logrotate-obs
```

### 安装选项
- `--topology reality-only|vision-reality` - 选择拓扑类型
- `--version <version>` - 指定 Xray 版本（默认：latest）
- `--enable-plugins <plugin1,plugin2>` - 启用插件
- `--proxy <proxy_url>` - 使用代理下载
- `--install-dir <path>` - 自定义安装目录
- `--debug` - 启用调试输出

## 🗑️ 一键卸载

### 完全卸载
```bash
# 标准卸载（保留安装目录）
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash

# 彻底卸载（包括安装目录）
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- --remove-install-dir
```

### 保留配置卸载
```bash
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- --keep-config
```

### 卸载选项
- `--keep-config` - 保留配置文件
- `--remove-install-dir` - 移除安装目录（彻底清理）
- `--force` - 强制卸载无需确认（非交互模式自动启用）
- `--debug` - 启用调试输出

## 快速开始（手动安装）

```bash
# 1) 安装（Reality-only；端口默认 443；自动生成 uuid/shortId/密钥）
bin/xrf install --topology reality-only

# 2) 导出客户端链接（插件可扩展 QR、观测提示等）
bin/xrf links
```

## 拓扑说明

### Reality-only 拓扑
- **用途**：隐蔽性最强，无需域名所有权
- **端口**：443（标准 HTTPS 端口）
- **特点**：SNI 伪装，流量特征与目标网站相同

### Vision-Reality 拓扑
- **用途**：双重保护，Vision 提供域名 TLS，Reality 提供备用连接
- **端口**：Vision 8443，Reality 443
- **特点**：需要域名所有权，自动证书管理

```bash
# Vision + Reality 拓扑示例
XRAY_DOMAIN="your.domain.com" \
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- \
  --topology vision-reality --enable-plugins cert-auto
```

### 启用日志轮转（推荐生产）
```bash
# 启用文件日志和自动轮转
bin/xrf plugin enable logrotate-obs
XRF_LOG_TARGET=file bin/xrf install --topology reality-only
```

## 目录结构
```
bin/xrf
lib/{core.sh,plugins.sh}
modules/{io.sh,state.sh,net/network.sh,fw/*,web/caddy.sh,user/user.sh}
services/xray/{common.sh,install.sh,configure.sh,systemd-unit.sh,client-links.sh}
commands/{install.sh,status.sh,uninstall.sh,plugin.sh}
packaging/systemd/xray.service
plugins/available/{cert-auto,firewall,links-qr,logrotate-obs}/plugin.sh
plugins/enabled/   # 启用=这里建软链
```

> **架构原则**：仅 systemd；无 OpenRC/CI/Tests 等非运行时必需组件，**去冗余**、**降复杂度**。配置片段合并遵循 Xray 官方语义：对象"后读覆盖"、数组"后读追加"。
>
> **重要概念**：VLESS+REALITY 协议**无需域名所有权**，SNI 域名仅用于 TLS 握手伪装。例如 `XRAY_SNI=www.microsoft.com` 是合法配置，无需拥有该域名。

## 环境变量配置

### Xray 配置变量
```bash
# Reality-only 拓扑（推荐配置）
export XRAY_PORT=443                    # 监听端口（默认 443）
export XRAY_UUID=<uuid>                 # 用户 UUID（自动生成）
export XRAY_SNI=www.microsoft.com       # SNI 伪装域名（无需拥有）
export XRAY_REALITY_DEST=www.microsoft.com:443  # 目标地址（自动推导）
export XRAY_PRIVATE_KEY=<X25519>        # 私钥（自动生成）
export XRAY_SHORT_ID=<hex>              # Short ID（自动生成）

# Vision-Reality 拓扑（需要域名所有权）
export XRAY_VISION_PORT=8443            # Vision 端口（TLS 真实连接）
export XRAY_REALITY_PORT=443            # Reality 端口（伪装连接）
export XRAY_FALLBACK_PORT=8080          # 回落端口
export XRAY_UUID_VISION=<uuid>          # Vision UUID（自动生成）
export XRAY_UUID_REALITY=<uuid>         # Reality UUID（自动生成）
export XRAY_DOMAIN=example.com          # 真实拥有的域名
export XRAY_CERT_DIR=/usr/local/etc/xray/certs  # 证书目录

# 通用配置
export XRAY_SNIFFING=false              # 流量嗅探（默认关闭）
export XRF_LOG_TARGET=journal           # 日志目标 (journal|file)
export XRF_DEBUG=false                  # 调试模式（--debug 启用）
```

### 安装脚本变量
```bash
export XRF_REPO_URL=https://github.com/Joe-oss9527/xray-fusion.git  # 仓库地址
export XRF_BRANCH=main                  # 分支
export XRF_INSTALL_DIR=/usr/local/xray-fusion  # 安装目录
```

## 常见问题

### 如何选择拓扑？
- **Reality-only**：推荐，无需域名所有权，隐蔽性最强
- **Vision-Reality**：需要域名，提供双重连接选项

### 安装问题排查
```bash
# 启用调试模式查看详细信息
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- --debug

# 使用代理下载
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash -s -- --proxy http://127.0.0.1:1080
```

### 管理操作
```bash
# 更新到最新版本
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/install.sh | bash

# 彻底卸载
curl -sL https://raw.githubusercontent.com/Joe-oss9527/xray-fusion/main/uninstall.sh | bash -s -- --remove-install-dir

# 查看连接信息
bin/xrf links

# 查看运行状态
bin/xrf status
```

## Lint & 格式化
```bash
make fmt   # 需要 shfmt
make lint  # 需要 shellcheck
```
