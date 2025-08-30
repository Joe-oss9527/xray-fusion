# HARDENING — 安全基线与非 root 运行

## 1. 非 root 绑定低端口（<1024）
推荐两种方案：

### 方案 A：文件能力（推荐）
```bash
# 设置 xray 二进制允许绑定低端口
sudo xrf harden setcap
# 查看当前能力
xrf harden status
```
> 若要撤销：`sudo xrf harden dropcap`。

### 方案 B：AmbientCapabilities（systemd）
在 `xray.service` 中使用：
```
User=nobody
Group=nogroup
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
```
> 二选一即可，**不要同时使用**，以减少不必要的权限表面。

## 2. 配置与密钥权限
- 配置文件建议 `0644`（只读）；私钥 `0600`。
- 目录权限最小化；尽量避免广泛的 `sudo`。

## 3. 下载完整性与签名校验（可选）
- 默认支持 SHA256（自动解析 `*.dgst`）；
- 若你有官方 GPG 公钥：
  ```bash
  export XRAY_GPG_KEYRING=/path/to/xray.gpg
  # 可选自定义签名 URL（默认 <zip>.asc）
  export XRAY_SIG_URL=https://example.com/Xray-linux-64.zip.asc
  bin/xrf install --version vX.Y.Z
  ```
  安装器会在校验 SHA256 后执行 `gpg --verify`；失败将中止。

## 4. systemd 单元加固建议
- `NoNewPrivileges=true`、`ProtectSystem=full`、`ProtectHome=true`、`PrivateTmp=true`、`RestrictAddressFamilies=AF_INET AF_INET6`。
- 根据运行用户调整配置路径读权限。

## 5. OpenRC 建议
- 使用 `supervise-daemon` 方式；指定 `ulimit -n` 与日志文件。


## 6. 专用服务账户（推荐）
- 创建 `xray:xray` 专用用户/组，并确保配置目录可读：
  ```bash
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin xray || true
  sudo chown -R root:xray /usr/local/etc/xray
  sudo chmod -R g+r /usr/local/etc/xray
  ```
- systemd unit 中将 `User=`/`Group=` 改为 `xray`，或按需定制。
