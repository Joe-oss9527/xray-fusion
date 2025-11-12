# Configuration Templates

配置模板系统为常见部署场景提供预定义配置，简化安装流程。

## 概述

模板系统允许用户通过 `--template` 参数快速部署预配置的 Xray 实例，无需手动指定所有参数。模板提供合理的默认值，同时允许通过 CLI 参数覆盖任何配置。

## 设计原则

1. **便捷性优先**: 模板提供开箱即用的配置，最小化用户输入
2. **灵活性保证**: CLI 参数始终优先于模板值
3. **场景导向**: 每个模板针对特定使用场景优化
4. **安全第一**: 所有模板遵循安全最佳实践

## 模板列表

### Home User (home)

**适用场景**: 个人用户，单设备或家庭网络访问

**配置**:
- **拓扑**: reality-only (无需域名)
- **端口**: 443
- **SNI**: www.microsoft.com
- **Reality Dest**: www.microsoft.com:443
- **插件**: 无
- **安全级别**: 中等

**特点**:
- ✅ 零配置，一键部署
- ✅ 无需域名所有权
- ✅ 适合个人使用，1-2台设备
- ✅ 轻量级，资源占用小

**使用示例**:
```bash
# 使用 home 模板安装
curl -sL install.sh | bash -s -- --template home

# 等价于手动指定参数
curl -sL install.sh | bash -s -- --topology reality-only --version latest
```

**系统要求**:
- CPU: 1 core
- RAM: 512MB
- 磁盘: 100MB
- 操作系统: Linux with systemd

---

### Office/Team (office)

**适用场景**: 小型办公室或团队使用，5-20人

**配置**:
- **拓扑**: vision-reality (需要域名)
- **端口**: Vision 8443, Reality 443, Fallback 8080
- **SNI**: www.cloudflare.com
- **Reality Dest**: www.cloudflare.com:443
- **插件**: cert-auto, firewall
- **安全级别**: 高

**特点**:
- ✅ 自动证书管理 (Let's Encrypt)
- ✅ 防火墙规则自动配置
- ✅ 双模式支持 (Vision + Reality)
- ✅ 适合团队协作

**使用示例**:
```bash
# 使用 office 模板 + 自定义域名
curl -sL install.sh | bash -s -- --template office --domain vpn.company.com

# 添加额外插件
curl -sL install.sh | bash -s -- --template office --domain vpn.company.com --plugins logrotate-obs
```

**系统要求**:
- CPU: 2 cores
- RAM: 2GB
- 磁盘: 1GB
- 操作系统: Linux with systemd
- **域名所有权**: 必需

**端口要求**:
- 443: Reality 入口
- 8443: Vision (TLS) 入口
- 8080: Caddy fallback (HTTP)
- 8444: Caddy HTTPS 管理端口

---

### Production Server (server)

**适用场景**: 生产环境，高性能，50+并发用户

**配置**:
- **拓扑**: vision-reality (需要域名)
- **端口**: Vision 8443, Reality 443, Fallback 8080
- **SNI**: www.apple.com,www.icloud.com (多 SNI)
- **Reality Dest**: www.apple.com:443
- **插件**: cert-auto, firewall, monitoring
- **安全级别**: 严格
- **性能**: 优化配置

**特点**:
- ✅ 严格安全设置 (TLS 1.3 only, cert pinning)
- ✅ 高性能优化 (大缓冲区, TCP 优化)
- ✅ 监控和日志
- ✅ 生产级可靠性

**使用示例**:
```bash
# 使用 server 模板 + 自定义域名
curl -sL install.sh | bash -s -- --template server --domain vpn.production.com

# 指定版本
curl -sL install.sh | bash -s -- --template server --domain vpn.production.com --version v1.8.0
```

**系统要求**:
- CPU: 2+ cores
- RAM: 4GB
- 磁盘: 10GB
- 操作系统: Linux with systemd
- **域名所有权**: 必需
- **网络**: 稳定带宽，低延迟

**性能配置**:
- 最大连接数: 2000
- 缓冲区大小: xlarge
- TCP 优化: 启用
- 流量嗅探: 启用

**安全配置**:
- TLS 版本: 1.3 only
- 证书固定: 启用
- 防火墙规则: 严格
- 速率限制: 启用

---

## 模板使用

### 查看可用模板

```bash
# 文本格式列表
bin/xrf templates list

# JSON 格式输出
bin/xrf templates list --json
```

**输出示例**:
```
Available Templates:

  [home] Home User
      Category: personal
      Optimized for home users with single device access

  [office] Office/Team
      Category: business
      Optimized for small office or team use with multiple users

  [server] Production Server
      Category: production
      Production-grade configuration with strict security and high performance
```

### 查看模板详情

```bash
# 文本格式详情
bin/xrf templates show home

# JSON 格式输出
bin/xrf templates show home --json
```

**输出示例**:
```
Template: Home User [home]

Description:
  Optimized for home users with single device access

Configuration:
  Topology:  reality-only
  Version:   latest

Requirements:
  - No domain required
  - Single device or home network use
  - Moderate security settings

Notes:
  - Suitable for 1-2 concurrent users
  - No domain ownership required
  - Lightweight configuration
```

### 验证模板

```bash
# 验证模板结构
bin/xrf templates validate home

# 输出
Template home is valid ✓
```

### 使用模板安装

```bash
# 基础使用
curl -sL install.sh | bash -s -- --template <template-id>

# 示例
curl -sL install.sh | bash -s -- --template home
curl -sL install.sh | bash -s -- --template office --domain example.com
curl -sL install.sh | bash -s -- --template server --domain vpn.prod.com
```

---

## 参数覆盖

### 覆盖规则

模板值作为**默认值**，CLI 参数具有**最高优先级**。

**优先级顺序**:
1. CLI 显式参数（最高）
2. 模板值
3. 系统默认值（最低）

### 覆盖示例

#### 覆盖拓扑

```bash
# office 模板默认 vision-reality，但这里覆盖为 reality-only
bin/xrf install --template office --topology reality-only

# 最终配置:
# - topology: reality-only (CLI 覆盖)
# - plugins: cert-auto,firewall (模板值)
```

#### 覆盖版本

```bash
# server 模板默认 latest，这里指定特定版本
bin/xrf install --template server --domain vpn.com --version v1.8.0

# 最终配置:
# - version: v1.8.0 (CLI 覆盖)
# - topology: vision-reality (模板值)
```

#### 插件合并

插件参数采用**合并策略**，CLI 插件和模板插件会合并。

```bash
# office 模板包含 cert-auto,firewall，这里添加 logrotate-obs
bin/xrf install --template office --domain vpn.com --plugins logrotate-obs

# 最终启用插件: cert-auto,firewall,logrotate-obs (合并)
```

#### 完全自定义

```bash
# 使用模板作为基础，但大量自定义
bin/xrf install \
  --template server \
  --domain custom.example.com \
  --version v1.8.1 \
  --topology reality-only \
  --plugins firewall

# 最终配置:
# - domain: custom.example.com (CLI)
# - version: v1.8.1 (CLI 覆盖)
# - topology: reality-only (CLI 覆盖，忽略模板的 vision-reality)
# - plugins: firewall,cert-auto,firewall,monitoring (合并，CLI + 模板)
```

---

## 模板结构

### JSON 格式

```json
{
  "metadata": {
    "id": "template-id",
    "name": "Template Name",
    "description": "Template description",
    "category": "personal|business|production",
    "author": "xray-fusion",
    "version": "1.0.0",
    "min_xray_version": "v1.8.0"
  },
  "config": {
    "topology": "reality-only|vision-reality",
    "xray": {
      "version": "latest",
      "port": 443,
      "vision_port": 8443,
      "reality_port": 443,
      "fallback_port": 8080,
      "sni": "example.com",
      "reality_dest": "example.com:443",
      "sniffing": true|false
    },
    "plugins": ["plugin1", "plugin2"],
    "security": {
      "level": "moderate|high|strict",
      "features": {
        "tls13_only": true|false,
        "cert_pinning": true|false,
        "firewall_rules": true|false
      }
    },
    "performance": {
      "max_connections": 1000,
      "buffer_size": "small|medium|large|xlarge"
    }
  },
  "requirements": [
    "Requirement 1",
    "Requirement 2"
  ],
  "notes": [
    "Note 1",
    "Note 2"
  ]
}
```

### 必需字段

**Metadata**:
- `id`: 模板唯一标识符
- `name`: 模板显示名称
- `description`: 模板描述

**Config**:
- `topology`: 拓扑类型 (reality-only | vision-reality)
- `xray`: Xray 配置对象
  - `version`: Xray 版本

### 可选字段

- `plugins`: 插件列表
- `security`: 安全配置
- `performance`: 性能配置
- `requirements`: 系统要求列表
- `notes`: 使用说明列表

---

## 自定义模板

### 用户模板目录

用户可以在 `/usr/local/etc/xray-fusion/templates/` 创建自定义模板。

```bash
# 创建用户模板目录
sudo mkdir -p /usr/local/etc/xray-fusion/templates

# 创建自定义模板
sudo cat > /usr/local/etc/xray-fusion/templates/custom.json <<'EOF'
{
  "metadata": {
    "id": "custom",
    "name": "Custom Template",
    "description": "My custom configuration"
  },
  "config": {
    "topology": "reality-only",
    "xray": {
      "version": "latest",
      "sni": "custom.example.com"
    }
  }
}
EOF

# 验证模板
bin/xrf templates validate custom

# 使用自定义模板
bin/xrf install --template custom
```

### 模板优先级

模板查找顺序:
1. **Built-in templates**: `${PROJECT_ROOT}/templates/built-in/`
2. **User templates**: `/usr/local/etc/xray-fusion/templates/`

用户模板可以覆盖同名的内置模板。

---

## 最佳实践

### 选择合适的模板

1. **个人使用**: 选择 `home` 模板
   - 无需域名
   - 快速部署
   - 资源占用小

2. **团队使用**: 选择 `office` 模板
   - 自动证书管理
   - 防火墙保护
   - 支持多用户

3. **生产环境**: 选择 `server` 模板
   - 严格安全配置
   - 性能优化
   - 监控和日志

### 参数覆盖策略

1. **最小覆盖原则**: 只覆盖必要的参数
   ```bash
   # 好的做法
   --template office --domain vpn.company.com

   # 避免不必要的覆盖
   --template office --domain vpn.company.com --topology vision-reality  # 冗余
   ```

2. **显式配置关键参数**: 关键参数显式指定
   ```bash
   # 生产环境显式指定版本
   --template server --domain vpn.com --version v1.8.0
   ```

3. **插件合并优势**: 利用插件合并添加功能
   ```bash
   # 在模板基础上添加插件
   --template office --domain vpn.com --plugins logrotate-obs
   # 结果: cert-auto,firewall,logrotate-obs (合并)
   ```

### 故障排查

#### 模板不存在

```bash
$ bin/xrf install --template nonexistent
[ERROR] template not found {"id":"nonexistent"}
```

**解决方案**:
- 检查模板 ID 拼写
- 使用 `bin/xrf templates list` 查看可用模板

#### 模板验证失败

```bash
$ bin/xrf templates validate invalid
[ERROR] invalid template JSON {"file":"/path/to/invalid.json"}
```

**解决方案**:
- 检查 JSON 语法
- 确保必需字段存在
- 使用 `jq` 验证 JSON 格式

#### 域名要求未满足

```bash
$ bin/xrf install --template office
[ERROR] missing parameter {"parameter":"domain","context":"vision-reality topology"}
```

**解决方案**:
- vision-reality 拓扑需要域名
- 添加 `--domain` 参数
- 或覆盖拓扑为 reality-only

---

## 技术实现

### 模板加载流程

1. 解析 CLI 参数 (`lib/args.sh`)
2. 检测 `--template` 参数
3. 验证模板存在且有效 (`templates::validate`)
4. 加载模板 JSON (`templates::load`)
5. 导出模板变量 (`templates::export`)
6. 应用覆盖逻辑 (CLI 优先)
7. 合并插件列表
8. 继续正常安装流程

### 关键函数

- `templates::list()`: 列出可用模板
- `templates::load(id)`: 加载模板 JSON
- `templates::validate(id)`: 验证模板结构
- `templates::export(id)`: 导出模板变量
- `templates::show(id)`: 显示模板详情

### 测试覆盖

模板系统包含 29 个单元测试:
- `templates::list` 测试 (3)
- `templates::load` 测试 (5)
- `templates::validate` 测试 (5)
- `templates::export` 测试 (9)
- `templates::show` 测试 (4)
- 模板结构验证 (3)

运行测试:
```bash
make test-unit
bats tests/unit/test_templates.bats
```

---

## 参考

- [Installation Guide](../README.md#快速开始)
- [AGENTS.md](../AGENTS.md) - 开发规范
- [CLAUDE.md](../CLAUDE.md) - 架构决策 (ADR)
- [Phase 2 Implementation Plan](PHASE2_IMPLEMENTATION_PLAN.md)
