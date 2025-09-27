# Claude Code 开发经验记录

本文档记录在 Claude Code 开发过程中获得的重要经验教训和技术知识，用于指导后续开发工作。

## 调试和日志管理

### 核心教训：函数输出污染问题

**问题**：`core::log` 函数默认输出到 stdout，导致函数返回值被日志污染。

**症状**：
```bash
deploy_release started {"release_dir":"[2025-09-27T07:59:06Z] debug configuring vision-reality topology {} }
```

**解决方案**：
1. 将所有日志输出重定向到 stderr (`>&2`)
2. 添加 debug 级别过滤，只在 `XRF_DEBUG=true` 时显示 debug 消息

**修复后的 `core::log` 函数**：
```bash
core::log() {
  local lvl="${1}"
  shift
  local msg="${1}"
  shift || true
  local ctx="${1-{} }"

  # Filter debug messages unless XRF_DEBUG is true
  if [[ "${lvl}" == "debug" && "${XRF_DEBUG}" != "true" ]]; then
    return 0
  fi

  # All logs go to stderr to avoid contaminating function outputs
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ts":"%s","level":"%s","msg":"%s","ctx":%s}\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  else
    printf '[%s] %-5s %s %s\n' "$(core::ts)" "${lvl}" "${msg}" "${ctx}" >&2
  fi
}
```

**关键原则**：
- 永远不要通过猜测来处理问题，要通过系统性的调试日志
- 使用项目内置的日志模块，不要用 `echo`
- 函数的 stdout 应该只用于返回值，所有日志都应该输出到 stderr

## Xray Vision-Reality 拓扑最佳实践

### 端口配置最佳实践

**官方推荐配置**：
- **Reality**: 端口 443（标准 HTTPS，用于隐秘伪装）
- **Vision**: 端口 8443（真实 TLS，用于域名连接）

**错误配置**：
```bash
# ❌ 错误：让 Caddy 占用 443，Reality 使用其他端口
XRAY_REALITY_PORT=8080  # 违反最佳实践
```

**正确配置**：
```bash
# ✅ 正确：Reality 使用标准端口，Vision 使用备用端口
XRAY_REALITY_PORT=443   # 符合官方最佳实践
XRAY_VISION_PORT=8443   # 标准 Vision 端口
```

### 证书管理和权限

**关键发现**：Xray 服务以 `xray` 用户运行，需要能够读取私钥文件。

**错误权限**：
```bash
chmod 600 "${cert_dir}/privkey.pem"  # ❌ 只有 root 可读
```

**正确权限**：
```bash
chmod 640 "${cert_dir}/privkey.pem"  # ✅ xray 组可读
chown root:xray "${cert_dir}/privkey.pem"
```

### VLESS+REALITY 关键概念

**重要理解**：VLESS+REALITY 协议**不需要域名所有权**
- SNI 域名用于伪装，不需要实际拥有该域名
- `XRAY_SNI=www.microsoft.com` 是合法的伪装配置
- Reality 使用特殊的 TLS 握手，无法通过常规代理（如 Caddy）转发

## 证书自动化最佳实践

### 架构选择

**弃用方案**：acme.sh 方式
- 缺少完整的安装和集成逻辑
- 维护复杂度高

**采用方案**：Caddy 方式
- 成熟的自动证书管理
- 参考 233boy/Xray 的成功实践
- 更好的集成和维护性

### cert-auto 插件关键实现

**证书同步机制**：
```bash
# 从 Caddy 证书目录同步到 Xray 目录
CADDY_CERT_DIR="/root/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"
XRAY_CERT_DIR="/usr/local/etc/xray/certs"
```

**定时同步**：使用 systemd timer 每小时同步证书更新

## 代码质量和架构原则

### 清理原则

**用户要求**：
> "不要做兼容性，没有用户使用。请不要增加维护负担，确保代码干净整洁，不要遗留历史代码"

**实施**：
- 完全删除不完整的 cert-acme 插件
- 删除相关的 acme_sh.sh 模块
- 不保留向后兼容的废弃代码

### 调试方法论

**用户强调**：
> "如果有需要请在脚本加必要的调试日志，而不是通过猜测来处理"
> "继续加必要日志调试啊，不要猜测，把问题解决了"

**核心原则**：
1. **不要做猜测，需要真凭实据**
   - 通过日志分析定位问题，而不是靠猜测修改代码
   - 添加必要的调试日志来获取准确的执行状态
   - 基于实际观察到的现象进行修复

2. **系统性调试方法**：
   - 系统性地添加 debug 日志追踪执行流程
   - 使用项目的日志框架，不要自创日志方式
   - 先诊断问题根因，再制定解决方案

3. **有必要则添加调试日志**：
   - 在关键执行路径添加状态日志
   - 记录重要变量值和函数返回值
   - 追踪函数调用链和数据流向

### 文档优先原则

**用户要求**：
> "如有需要请先查询相关官方文档，避免使用过期废弃的方式"

**实施策略**：
1. **优先查阅官方文档**
   - 实现功能前先查询官方最新文档
   - 验证所采用的方法是否为当前推荐做法
   - 避免使用已废弃或过时的 API/配置方式

2. **技术选型验证**
   - 对比官方示例和最佳实践
   - 查看官方 GitHub 仓库的最新 examples
   - 关注官方社区的讨论和建议

3. **避免过期方式**
   - 定期检查依赖的技术栈更新
   - 及时淘汰已废弃的实现方式
   - 选择有长期维护保证的技术方案

**实际案例**：
- ❌ 错误：基于网络教程实现 acme.sh 集成（缺少官方支持）
- ✅ 正确：查阅 Xray 官方文档，采用推荐的端口配置（443 for Reality）
- ✅ 正确：参考 233boy/Xray 成熟实践，使用 Caddy 自动证书管理

## 变量命名演变

**历史变更**：
- `XRAY_REALITY_SNI` → `XRAY_SNI`（统一命名）
- 注意检查代码中的过时变量名引用

## 测试验证

### 端点连接测试

**基本连接测试**：
```bash
# Vision 端点测试
timeout 3 bash -c "</dev/tcp/r.950288.xyz/8443" && echo "Vision port 8443 accessible"

# Reality 端点测试
timeout 3 bash -c "</dev/tcp/104.194.91.33/443" && echo "Reality port 443 accessible"
```

**服务状态验证**：
```bash
systemctl status xray  # 检查服务状态
netstat -tlnp | grep xray  # 检查监听端口
```

## 成功的最终配置

### 客户端链接示例

```bash
# Vision（域名连接，真实 TLS）
vless://uuid@r.950288.xyz:8443?security=tls&flow=xtls-rprx-vision&sni=r.950288.xyz&fp=chrome#Vision-r.950288.xyz

# Reality（隐秘连接，伪装 TLS）
vless://uuid@104.194.91.33:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=key&sid=id&spx=/#REALITY-104.194.91.33
```

### 服务运行状态

- Xray 服务：监听 443（Reality）和 8443（Vision）
- 证书：自动管理，正确权限设置
- 日志：清晰的 stdout/stderr 分离

---

## 总结

这次开发过程的核心收获：

1. **调试方法论**：系统性日志记录比猜测修改更有效
2. **架构理解**：深入理解 VLESS+REALITY 协议特性和最佳实践
3. **权限管理**：正确配置服务用户的文件访问权限
4. **代码质量**：保持代码整洁，不做无用的兼容性处理
5. **技术选型**：选择成熟方案（Caddy）而非重复造轮子（acme.sh）
6. **真凭实据**：不做猜测，必须基于实际日志和观察进行分析
7. **文档优先**：优先查阅官方文档，避免使用过期废弃的方式

## 开发工作流程

### 标准问题解决流程

1. **现象观察**：详细记录错误现象和日志输出
2. **添加调试**：在关键路径添加调试日志获取更多信息
3. **查阅文档**：查询官方文档确认正确的实施方式
4. **根因分析**：基于日志和文档分析真正的问题根因
5. **方案制定**：制定基于官方最佳实践的解决方案
6. **实施验证**：实施修复并通过日志验证效果
7. **文档记录**：记录经验教训供后续参考

### 禁止行为

- ❌ 基于猜测进行代码修改
- ❌ 使用过时的网络教程或非官方方案
- ❌ 保留废弃代码进行兼容性处理
- ❌ 忽略日志输出直接修改配置
- ❌ 跳过官方文档查阅环节

### 推荐行为

- ✅ 系统性添加调试日志追踪问题
- ✅ 优先查阅最新官方文档和示例
- ✅ 选择有长期维护保证的成熟方案
- ✅ 基于实际观察现象进行根因分析
- ✅ 保持代码整洁，及时清理废弃代码

这些经验将指导后续的开发工作，确保高质量的代码和可靠的系统架构。