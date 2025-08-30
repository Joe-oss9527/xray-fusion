
# XRAY Fusion — 模块化架构方案设计文档

> 目标：为 **xray-fusion** 打造一个“安全优先、可演化、可测试、可观测”的 Bash 脚本体系，覆盖安装、配置、服务化、诊断、快照/回滚与证书生命周期管理，并对标社区主流优秀脚本的最佳实践。

---

## 1. 背景与参考

- 现有仓库（用户给定）：`Joe-oss9527/xray-fusion`，强调模块化、结构化日志、双拓扑、快照等能力（见 README 要点：特性、命令、路径与安全说明）。
- 行业参考：
  - **XTLS/Xray-install**：单文件安装器，主要面向 systemd 平台，开箱快，长期维护活跃。
  - **v2fly/fhs-install-v2ray**：遵循 FHS 布局、校验压缩包摘要、落地 systemd unit 等，注重“文件布局与安装流程”的规范性。
  - **acme.sh**：成熟的纯 Shell ACME 客户端，丰富的颁发/续签/部署接口，适合作为证书后端。

> 我们的目标是在保留 “一键体验” 的同时，将安装脚本“工程化”。与单体脚本相比，本方案更关注可维护性、可测试性、可审计性与可扩展性。

---

## 2. 设计原则

1. **模块化分层**：CLI / commands / services / modules / lib / templates (modular) / topologies / tests。
2. **契约优先**：模块 API 以命名空间约定（如 `pkg::ensure`、`svc::start`、`fw::open`）暴露，避免隐式耦合。
3. **最小权限与原子落盘**：只在必要处使用 `sudo`；配置先写临时文件，再原子替换；敏感文件设定最小权限。
4. **可观测**：所有命令可 `--json` 输出，关键步骤结构化日志（时间、级别、payload）。
5. **可测试**：以 `bats` 编写模块级与流程级用例；CI 在主流发行版矩阵做 lint + test + smoke。
6. **可回滚**：全量快照（最小起步为 `config.json` + `state.json`），一键恢复；失败路径设计必须“默认安全”。
7. **可演进**：抽象层尽量稳定；实现层可插拔（包管理器、init 系统、防火墙、证书后端等）。

---

## 3. 总体架构（分层）

```
bin/xrf                # 统一 CLI，解析子命令并分发到 commands/*
commands/              # 任务编排层（install / status / doctor / snapshot / uninstall / service / cert / harden）
  install.sh           # 依赖准备 -> 拉取 Xray -> 渲染配置 -> 保存 state
  status.sh            # 平台识别、包管理器、state 汇总，支持 --json
  doctor.sh            # 端口探测、防火墙/Init 检测
  snapshot.sh          # 快照/回滚（config.json + state.json）
  uninstall.sh         # 卸载/清理（--purge 支持）
  service.sh           # 服务装/卸（自动识别 systemd / OpenRC）
  cert.sh              # 证书自动续期调度（systemd timer / cron）
  harden.sh            # 安全加固（setcap权限管理）

services/              # 业务装配（跨模块组合）
  xray/install.sh      # 下载/解压/安装二进制（FHS 布局）
  xray/configure.sh    # 模板渲染、可选 xray -test 校验
  xray/systemd-unit.sh # 安装/移除 systemd unit
  xray/openrc-unit.sh  # 安装/移除 OpenRC init 脚本
  xray/common.sh       # Xray路径函数（消除重复定义）
  xray/topology.sh     # 拓扑抽象层（修复跨层违规）
  xray/client-links.sh # 客户端连接链接和QR码生成

modules/               # 可复用能力（稳定契约）
  pkg/apt.sh dnf.sh pkg.sh  # 包管理调度/后端
  svc/svc.sh systemd.sh openrc.sh  # 服务管理
  fw/fw.sh ufw.sh firewalld.sh     # 防火墙管理
  net/tcp.sh network.sh            # 网络探测和IP检测
  cert/cert.sh acme_sh.sh          # 证书后端（acme.sh）
  sec/verify.sh                    # 安全验证（SHA256/GPG）
  ui/progress.sh                   # 用户界面和进度追踪
  user/user.sh                     # 系统用户管理（专用用户）
  io.sh                            # 原子写/目录创建/文件安装
  state.sh                         # 状态读写（state.json）

topologies/            # 部署配方（输出 JSON 上下文）
  reality-only.sh
  vision-reality.sh

templates/             # 模块化配置模板（envsubst 渲染）
  xray/base.json.tmpl           # 核心框架（日志、路由、出站配置）
  xray/inbound-reality.json.tmpl       # Reality 协议入站配置
  xray/inbound-vision.json.tmpl        # Vision 协议入站配置（TLS）
  xray/inbound-reality-dual.json.tmpl  # Reality 双协议入站配置

lib/                   # 核心库（严格模式、企业级错误处理、日志、OS 检测等）
  core.sh              # 严格模式、结构化日志、企业级错误处理（错误行号与命令上下文）
  os.sh                # 操作系统检测和平台抽象

tests/                 # bats 用例（pkg/svc/fw/doctor/cert/install/topologies/state/...）
packaging/             # systemd/OpenRC unit 与定时器、证书续期脚本
  systemd/             # systemd units 和 timers
  openrc/              # OpenRC init 脚本
  libexec/             # 证书自动续期后台脚本

.github/               # CI 工作流、发行模板、Issue 模板
docs/                  # 架构/运维/安全/贡献文档
```

---

## 4. 模块职责与契约（关键 API 摘要）

### 4.1 包管理（`modules/pkg/*.sh`）
- **契约**：`pkg::detect -> apt|dnf|unknown`；`pkg::refresh`；`pkg::ensure <name>`
- **后端**：`apt_pkg::*`、`dnf_pkg::*`（可扩展 `apk`, `zypper`…）

### 4.2 服务管理（`modules/svc/*.sh`）
- **契约**：`svc::detect -> systemd|openrc|unknown`；`svc::enable|start|reload|status|is_healthy|stop`
- **后端**：
  - `systemd.sh`：`systemctl is-active/show`；`status` 返回 `{"active":bool,"sub":"running|..."}`
  - `openrc.sh`：`rc-service`/`rc-update` 真实现

### 4.3 防火墙（`modules/fw/*.sh`）
- **契约**：`fw::detect -> ufw|firewalld|none`；`fw::open|close|list`
- **后端**：`ufw.sh`、`firewalld.sh`（支持 `XRF_DRY_RUN` 预演）

### 4.4 网络探测（`modules/net/tcp.sh`）
- **契约**：`net::is_listening <port>`（优先 `ss`，回退 `lsof`/`netstat`）

### 4.5 证书（`modules/cert/*.sh`）
- **契约**：`cert::issue <domain> <email> <out_dir>`；`cert::renew <domain> <out_dir>`；`cert::exists <out_dir>`
- **后端**：`acme_sh.sh`，支持 `XRF_DRY_RUN` 预演；调度器在 `commands/cert.sh` 中以 systemd timer 或 cron 落地。

### 4.6 I/O 与状态（`modules/io.sh`, `modules/state.sh`）
- **I/O**：`io::ensure_dir`、`io::atomic_write`、`io::install_file`（遇不可写自动回退 `sudo`）
- **状态**：`state.json` 保存安装上下文（拓扑、版本、时间戳、关键参数），供 `status` 与回滚使用。

---

## 5. 配置与拓扑

### 5.1 模板渲染
- 模板：`templates/xray/config.json.tmpl`（默认 Reality+Vision 口味可切换）。
- 渲染：`envsubst` -> `jq` 校验 ->（可选）`xray -test -config` 验证 -> `io::atomic_write` 原子落盘。

### 5.2 拓扑上下文
- `topologies/reality-only.sh` 与 `topologies/vision-reality.sh` 输出上下文 JSON：
  ```json
  {"name":"reality-only","xray":{"port":8443,"uuid":"...","reality_sni":"...","short_id":"..."}}
  ```
- `install` 解析 `--topology`，将上下文注入环境变量供模板渲染，并持久化到 `state.json`。

---

## 6. 关键流程（时序）

### 6.1 安装（`xrf install`）
1. 识别包管理器并安装依赖（`curl/unzip/jq/gettext`）。  
2. 下载并解压 Xray（FHS 布局：`/usr/local/bin/xray`、`/usr/local/etc/xray/`）。  
3. 拓扑解析并渲染配置 -> 可选 `xray -test` -> 原子落盘。  
4. 保存 `state.json`（拓扑/版本/时间）。  
5. 可选：`xrf service setup` 安装 systemd/OpenRC 单元并启用。

### 6.2 诊断（`xrf doctor`）
- 汇总：OS / pkg / init / firewall；
- 端口探测（默认 `80,443,8443,10000`，可 `--ports` 自定义）；
- 支持 `--json` 输出给自动化系统。

### 6.3 快照/回滚（`xrf snapshot`）
- `create <name>`：保存 `config.json` 与 `state.json` 到 `snapshots/<name>/`；
- `restore <name>`：原子恢复配置并尝试 `svc::reload xray`。

### 6.4 卸载（`xrf uninstall [--purge]`）
- 停止服务 -> 删除二进制与配置；
- `--purge` 额外删除 `state/snapshots` 等数据。

### 6.5 证书续期（`xrf cert schedule|unschedule`）
- 优先 systemd timer（`xrf-cert-renew.timer`），无 systemd 时回退 cron；
- 定时运行 `acme.sh --cron` 后尝试 `reload xray`。

---

## 7. 安全基线

- **严格模式**：`set -euo pipefail -E` 与企业级错误处理（错误行号与命令上下文）。  
- **输入校验**：避免 `eval`/复杂 regex，使用安全子命令与参数构造。  
- **权限控制**：私钥 `600`；配置 `644`；专用系统用户 `xray:xray`；只有在目录不可写时使用 `sudo`。  
- **供应链**：强制性 **SHA256 校验**与可选 **GPG 签名校验**；安全下载策略。  
- **审计日志**：结构化记录关键动作（不打印敏感字段）。

---

## 8. 测试与 CI

- **Bats** 用例覆盖：pkg/svc/fw/net/doctor/cert/install/topologies/state/snapshot/uninstall/service/cert-schedule 等。
- **CI**：
  - Lint（shellcheck）+ Test（bats）。
  - `smoke-install`：在 Ubuntu 环境执行 `XRF_DRY_RUN=true bin/xrf install`。
  - 可扩展矩阵至 Debian/Ubuntu/Rocky/Alma/Alpine（OpenRC 分支）。

---

## 9. 可扩展性与演进路线

- **包管理器**：新增 `apk`/`zypper` 后端只需实现 `is_available/refresh/ensure`。  
- **Init**：扩展 `launchd`（macOS）或 `runit/s6`。  
- **防火墙**：接入 `iptables/nftables` 细粒度规则。  
- **证书后端**：接入 `lego` 或云厂商 DNS 插件；完善证书安装 Hook。  
- **配置系统**：模板换 `gomplate`/`ytt`；引入 schema 校验与语义验证。  
- **观测**：统一日志格式与字段；对接 journald/ELK/OpenTelemetry（通过外部 sidecar）。

---

## 10. 与主流脚本对比（摘录）

| 维度 | Xray-install | fhs-install-v2ray | 本方案 |
| --- | --- | --- | --- |
| 架构 | 单文件、功能聚合 | 单文件、重视 FHS 与校验 | 多模块分层、可插拔 |
| 平台 | 主流 systemd | 主流 systemd | systemd + OpenRC，易扩展 |
| 配置 | 直接写入 | FHS 与校验完善 | 模板渲染 + `xray -test` + 原子落盘 |
| 回滚 | 一般 | 一般 | 内置快照/回滚 |
| 证书 | 可选 | 可选 | acme.sh 后端 + 自动续期调度 |
| 观测 | 常规输出 | 常规输出 | 结构化日志 + `--json` |
| 安全 | 良好 | 良好（摘要校验） | 严格模式 + 最小权限 + 原子写 + 审计 |

> 结论：在保持“易用”的同时，本方案显著提升了**工程化与可维护性**，适合团队与生产环境长期演进。

---

## 11. 版本与发布

- 采用 **语义化版本**：`MAJOR.MINOR.PATCH`。  
- 变更分类：Breaking / Features / Fixes / Docs / Chores；Release Notes 自动聚合标签。  
- 发布资产：补丁（patch）、归档（zip/tar），并在 README/Docs 同步能力矩阵。

---

## 12. 风险与回滚策略

- 任何写入配置的步骤都应可逆：写前自动创建临时快照。  
- 服务重载失败时应保持旧配置并回滚至可用状态。  
- 证书续期失败不影响现网（沿用旧证书），并记录清晰告警。

---

## 13. 目录约定与默认路径（FHS）

- 二进制：`/usr/local/bin/xray`  
- 配置：`/usr/local/etc/xray/config.json`  
- 状态：`/var/lib/xray-fusion/state.json`  
- 快照：`/var/lib/xray-fusion/snapshots/*`  
- systemd unit：`/etc/systemd/system/xray.service`（或 OpenRC `/etc/init.d/xray`）

---

## 14. 落地清单（与实现映射）

- PR#1~#3：CLI + OS/pkg/svc 抽象与 `status` 集成  
- PR#4：防火墙抽象 + `doctor` + 端口探测  
- PR#5：证书后端（acme.sh）与测试  
- PR#6：Xray 二进制安装（FHS + 原子写）与配置渲染  
- PR#7：拓扑层与 `state.json`  
- PR#8：`snapshot create/restore`  
- PR#9：`uninstall --purge` + 文档/许可证  
- PR#10：CI/README/Release 模板  
- PR#11：systemd unit + `xrf service`  
- PR#12：OpenRC 实现与自动识别  
- PR#13：证书自动续期调度（systemd timer / cron）

> 以上 PR 已按“单一变更集”粒度实现并提供补丁与整仓包，便于审查与回滚。

---

## 15. 结语

本方案把“一键脚本”工程化：以**稳定契约**与**分层抽象**保证长期可维护；以**原子写/快照/回滚**保证运维安全；以**结构化日志/--json**增强可观测性；以**可插拔后端**确保不同环境与未来演进的适配能力。
