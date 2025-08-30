# 部署自检清单（Checklist）

- [ ] **用户/权限**：优先使用专用用户 `xray:xray`（或最小权限账户），避免直接使用 `root`/`nobody`。
- [ ] **低端口绑定**：二选一 —— `xrf harden setcap` 或 systemd `AmbientCapabilities=CAP_NET_BIND_SERVICE`。
- [ ] **配置与密钥**：`config.json` 为 0644（或更严），私钥 0600；目录权限最小化。
- [ ] **下载校验**：SHA256（自动）+ 可选 GPG（`XRAY_GPG_KEYRING`）。
- [ ] **服务状态**：`xrf service setup` 后 `status`/`journalctl -u xray` 无错误。
- [ ] **端口监听**：目标端口处于 LISTEN；`xrf doctor --json` 输出健康。
- [ ] **防火墙**：放通端口规则已生效（如 ufw/firewalld）。
- [ ] **证书续期**：systemd 定时器 `xrf-cert-renew.timer` **已启用**（或 cron 生效）；手工跑一次无报错。
- [ ] **日志**：OpenRC 下 `/var/log/xray*.log` 正在写入；考虑 logrotate。
- [ ] **快照**：上线前 `xrf snapshot create pre-go-live`，回滚路径可用。
