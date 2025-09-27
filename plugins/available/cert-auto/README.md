# cert-auto Plugin

自动证书管理插件，基于 Caddy 实现 TLS 证书的自动申请和续期。

## 功能

- 自动安装 Caddy
- 自动配置域名 TLS 证书
- 自动续期证书
- 与 vision-reality 拓扑集成

## 使用

```bash
# 启用插件并安装 vision-reality 拓扑
./install.sh --topology vision-reality --domain your.domain.com --plugins cert-auto
```

## 配置

- 域名（必需）：通过 `--domain` 参数指定
- `XRAY_VISION_PORT`: Vision 端口（默认 8443）

## 原理

1. 安装 Caddy 并配置自动 TLS
2. Caddy 自动申请 Let's Encrypt 证书
3. 将证书同步到 Xray 证书目录
4. 设置定时任务自动续期

## 要求

- 域名必须指向服务器 IP
- 80 和 443 端口可用
- 服务器可访问互联网