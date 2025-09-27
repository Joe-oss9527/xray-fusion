# xray-fusion-lite (complete, clean, pluginized)

**目标**：极简、可维护、可观测。核心仅负责：安装 Xray → 渲染分片配置（`-confdir`）→ 原子切换 `active` → systemd 单元。其余全部插件化（证书 / 防火墙 / 链接二维码 / 日志轮转）。

## 快速开始

```bash
# 1) 安装（Reality-only；端口默认 443；自动生成 uuid/shortId/密钥）
bin/xrf install --topology reality-only

# 2) 导出客户端链接（插件可扩展 QR、观测提示等）
bin/xrf links
```

### Vision + Reality（带证书）
```bash
bin/xrf plugin enable cert-acme
XRAY_DOMAIN="your.domain" bin/xrf install --topology vision-reality
```

### 文件日志 + logrotate（推荐生产）
```bash
bin/xrf plugin enable logrotate-obs
XRF_LOG_TARGET=file bin/xrf install --topology reality-only
# /var/log/xray/{error.log,access.log}；/etc/logrotate.d/xray-fusion
```

## 目录结构
```
bin/xrf
lib/{core.sh,plugins.sh}
modules/{io.sh,state.sh,net/network.sh,fw/*,cert/*,user/user.sh}
services/xray/{common.sh,install.sh,configure.sh,systemd-unit.sh,client-links.sh}
commands/{install.sh,status.sh,uninstall.sh,plugin.sh}
packaging/systemd/xray.service
plugins/available/{cert-acme,firewall,links-qr,logrotate-obs}/plugin.sh
plugins/enabled/   # 启用=这里建软链
```

> 仅 systemd；无 OpenRC/CI/Tests 等非运行时必需组件，**去冗余**、**降复杂度**。配置片段合并遵循 Xray 官方语义：对象“后读覆盖”、数组“后读追加”。Reality 强制 `flow: "xtls-rprx-vision"`。

## Lint & 格式化
```bash
make fmt   # 需要 shfmt
make lint  # 需要 shellcheck
```
