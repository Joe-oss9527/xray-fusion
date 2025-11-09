# Xray-Fusion Test Suite

本目录包含 xray-fusion 项目的测试套件。

## 目录结构

```
tests/
├── README.md           # 本文件
├── test_helper.bash    # 通用测试辅助函数
├── unit/               # 单元测试
│   ├── test_args_validation.bats
│   └── test_core_functions.bats
├── integration/        # 集成测试（TODO）
└── helpers/            # 测试辅助脚本（TODO）
```

## 测试框架

使用 [bats-core](https://github.com/bats-core/bats-core) - 专为 Bash 设计的测试框架。

### 安装 bats-core

```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS
brew install bats-core

# 手动安装
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## 运行测试

```bash
# 运行所有测试
bats tests/**/*.bats

# 运行单元测试
bats tests/unit/*.bats

# 运行特定测试文件
bats tests/unit/test_args_validation.bats

# 详细输出
bats -t tests/unit/*.bats

# 并行运行
bats -j 4 tests/unit/*.bats
```

## 编写测试

### 基本结构

```bash
#!/usr/bin/env bats

load ../test_helper

setup() {
  setup_test_env
}

teardown() {
  cleanup_test_env
}

@test "描述你的测试" {
  run your_command args
  [ "$status" -eq 0 ]
  [[ "$output" == *"expected"* ]]
}
```

### 可用的辅助函数

- `setup_test_env`: 创建隔离的测试环境
- `cleanup_test_env`: 清理测试环境
- `assert_file_exists <file>`: 断言文件存在
- `assert_dir_exists <dir>`: 断言目录存在
- `assert_equals <expected> <actual>`: 断言相等
- `assert_contains <haystack> <needle>`: 断言包含
- `assert_command_success <cmd> [args]`: 断言命令成功
- `assert_command_fails <cmd> [args]`: 断言命令失败

## 当前测试覆盖

### 单元测试

- ✅ **lib/args.sh**: 参数验证
  - topology 验证
  - domain 验证（包括内部域名阻止）
  - version 验证
  - 配置交叉验证

- ✅ **lib/core.sh**: 核心功能
  - 时间戳生成
  - 日志输出（文本/JSON）
  - 调试日志过滤
  - 重试机制

### TODO

- [ ] **lib/plugins.sh**: 插件系统测试
- [ ] **services/xray/configure.sh**: 配置生成测试
- [ ] **modules/io.sh**: 原子写入测试
- [ ] **integration**: 完整安装流程测试

## CI/CD 集成

测试将自动在 GitHub Actions 中运行（见 `.github/workflows/test.yml`）。

## 最佳实践

1. **隔离性**: 每个测试使用独立的临时目录
2. **幂等性**: 测试可以重复运行
3. **速度**: 单元测试应该快速（< 1秒）
4. **清晰性**: 测试名称应描述期望行为
5. **覆盖率**: 优先测试关键路径和边界情况

## 调试测试

```bash
# 打印每个命令（详细模式）
bats -t tests/unit/test_args_validation.bats

# 只运行特定的测试
bats tests/unit/test_args_validation.bats --filter "accepts valid domain"

# 在失败时停止
bats --no-parallelize-across-files tests/unit/*.bats
```
