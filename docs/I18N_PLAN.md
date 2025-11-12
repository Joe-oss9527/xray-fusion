# Internationalization (i18n) Plan

## Executive Summary

This document outlines the plan to internationalize xray-fusion by standardizing all user-facing content to English. Currently, the codebase contains mixed Chinese and English content, which creates barriers for international contributors and users.

## Scope Analysis

### Code Files with Chinese Content (by character count)

| File | Chinese Chars | Type | Priority |
|------|--------------|------|----------|
| install.sh | 2,836 | User-facing installer | **P0** |
| uninstall.sh | 1,758 | User-facing uninstaller | **P0** |
| modules/web/caddy.sh | 606 | Module | **P1** |
| lib/preview.sh | 603 | Library | **P1** |
| scripts/caddy-cert-sync.sh | 595 | System script | **P1** |
| plugins/available/cert-auto/plugin.sh | 96 | Plugin | **P2** |
| services/xray/client-links.sh | 58 | Service | **P2** |
| lib/health_check.sh | 30 | Library | **P2** |
| lib/sni_validator.sh | 18 | Library | **P2** |
| commands/backup.sh | 11 | Command | **P2** |
| Other files | <10 each | Various | **P3** |

### Content Categories

1. **User-facing messages** (P0)
   - Installation progress indicators
   - Error messages and warnings
   - Success confirmations
   - Help text and usage instructions

2. **Log messages** (P1)
   - Debug logging
   - Info/warn/error logs
   - System operation logs

3. **Internal comments** (P2)
   - Code documentation
   - Function descriptions
   - Inline explanations

4. **Documentation** (P3)
   - README.md
   - CONTRIBUTING.md
   - Other *.md files (can be kept in Chinese or translated separately)

## Implementation Strategy

### Phase 1: Critical User-Facing Content (P0) - 1 day

**Goal**: Translate all user-visible installation/uninstallation messages

**Files**:
- `install.sh` - Online installer with progress indicators
- `uninstall.sh` - Uninstallation script

**Translation Approach**:
```bash
# Before (Chinese)
log_step 1 7 "检查核心依赖"
log_substep "下载工具可用" "✓"
error_exit "当前非 ROOT用户，请使用 sudo 运行此脚本"

# After (English)
log_step 1 7 "Checking core dependencies"
log_substep "Download tools available" "✓"
error_exit "Not running as ROOT user, please use sudo to run this script"
```

**Deliverables**:
- [ ] Translate all `log_*` function calls
- [ ] Translate all `error_exit` messages
- [ ] Translate retry/progress messages
- [ ] Translate help text in `source_args_module()`
- [ ] Update validation error messages

### Phase 2: Module and Library Messages (P1) - 1 day

**Goal**: Translate internal log messages and module outputs

**Files**:
- `modules/web/caddy.sh` - Caddy installation and configuration
- `lib/preview.sh` - Configuration preview
- `scripts/caddy-cert-sync.sh` - Certificate synchronization

**Translation Approach**:
```bash
# Before
core::log info "开始安装 Caddy" "{}"
core::log error "Caddy 安装失败" "$(printf '{"code":%d}' "$?")"

# After
core::log info "starting caddy installation" "{}"
core::log error "caddy installation failed" "$(printf '{"code":%d}' "$?")"
```

**Deliverables**:
- [ ] Translate all `core::log` messages
- [ ] Translate preview display text
- [ ] Translate certificate sync messages
- [ ] Update module-specific error messages

### Phase 3: Commands and Services (P2) - 0.5 days

**Goal**: Translate remaining command outputs and service messages

**Files**:
- `services/xray/client-links.sh`
- `lib/health_check.sh`
- `lib/sni_validator.sh`
- `commands/backup.sh`
- Other commands/*.sh with <10 Chinese chars

**Deliverables**:
- [ ] Translate health check messages
- [ ] Translate SNI validation output
- [ ] Translate backup command messages
- [ ] Translate client link generation output

### Phase 4: Comments and Documentation (P3) - Optional

**Goal**: Translate code comments and technical documentation

**Approach**:
- Keep CLAUDE.md and AGENTS.md in Chinese (internal development docs)
- Translate README.md, CONTRIBUTING.md (external-facing)
- Code comments can be either language (prefer English for consistency)

**Note**: This phase can be done gradually and is not blocking for release.

## Translation Guidelines

### Message Style

1. **Concise and clear**: Use simple English, avoid jargon
2. **Consistent terminology**:
   - "检查" → "checking" / "verifying"
   - "安装" → "installing" / "installation"
   - "失败" → "failed" / "failure"
   - "成功" → "succeeded" / "success"
   - "依赖" → "dependencies"
   - "配置" → "configuration" / "config"
   - "证书" → "certificate" / "cert"

3. **Log level conventions**:
   - **error**: "failed to X", "cannot Y", "missing Z"
   - **warn**: "X not found", "Y is deprecated", "skipping Z"
   - **info**: "starting X", "completed Y", "using Z"
   - **debug**: "checking X", "found Y", "using Z"

4. **Error messages must include context**:
```bash
# Bad
core::log error "installation failed" "{}"

# Good
core::log error "xray installation failed" "$(printf '{"version":"%s","code":%d}' "${version}" "${code}")"
```

### Testing Requirements

After each phase:
1. **Unit tests**: All 472 tests must pass
2. **Shellcheck**: No new warnings
3. **Format**: Code must be formatted with shfmt
4. **Manual test**: Run `install.sh` and verify output is readable

### Validation Checklist

Before marking a file as complete:
- [ ] No Chinese characters in user-facing messages
- [ ] All log messages use lowercase (following project convention)
- [ ] Error messages include actionable hints
- [ ] Progress indicators remain clear and informative
- [ ] Help text is grammatically correct
- [ ] Tests pass without modification (if messages are in test assertions, update tests)

## Migration Process

### Step-by-Step Workflow

For each file:

1. **Read entire file** to understand context
2. **Extract all Chinese strings** to a translation list
3. **Translate messages** following style guide
4. **Update code** with English messages
5. **Run tests** to catch assertion mismatches
6. **Manual verification** of output
7. **Commit** with clear message

### Commit Message Template

```
i18n: translate [file/module] to English

Translate user-facing messages in [file] from Chinese to English:
- Installation progress indicators
- Error/warning/info messages
- Help text and usage instructions

Part of comprehensive i18n effort to standardize on English.

Phase: [P0/P1/P2/P3]
Files: [comma-separated list]
```

## Timeline

| Phase | Duration | Completion Date | Dependencies |
|-------|----------|-----------------|--------------|
| P0: User-facing | 1 day | Day 1 | None |
| P1: Modules | 1 day | Day 2 | P0 complete |
| P2: Services | 0.5 days | Day 2-3 | P1 complete |
| P3: Docs (optional) | As needed | Future | None |

**Total effort**: 2-3 days of focused work

## Testing Strategy

### Automated Tests
- Unit tests: `make test-unit` (472 tests must pass)
- Linting: `make lint` (no shellcheck warnings)
- Formatting: `make fmt` (code must be clean)

### Manual Tests
1. **Installation flow**:
   ```bash
   curl -sL install.sh | bash -s -- --topology reality-only
   ```
   Verify all messages are in English

2. **Error scenarios**:
   - Missing dependencies
   - Network failures
   - Invalid parameters
   Verify error messages are clear and helpful

3. **Uninstallation**:
   ```bash
   xrf uninstall
   ```
   Verify prompts and confirmations are understandable

## Risk Mitigation

### Potential Issues

1. **Test assertion failures**
   - **Risk**: Tests may check for specific Chinese strings
   - **Mitigation**: Update test assertions to match new English messages
   - **Files**: `tests/unit/*.bats`

2. **Breaking changes for existing users**
   - **Risk**: Scripts that parse Chinese output may break
   - **Mitigation**: Version this as a breaking change, update CHANGELOG
   - **Note**: Output is primarily human-readable, not machine-parsed

3. **Incomplete translations**
   - **Risk**: Missing translations lead to inconsistent UX
   - **Mitigation**: Systematic grep-based validation after each phase
   - **Command**: `grep -r '[一-龥]' commands/ lib/ services/ modules/`

## Success Criteria

✅ **Phase complete when**:
1. No Chinese characters in target files (verified by grep)
2. All unit tests pass
3. No shellcheck warnings
4. Manual installation test successful
5. Error messages are clear and actionable

## Post-Implementation

### Maintenance
- Add pre-commit hook to warn on Chinese in code files
- Update CONTRIBUTING.md with English-only guideline
- Consider i18n framework for future multi-language support (if needed)

### Documentation Updates
- Update README.md with language policy
- Add i18n section to CONTRIBUTING.md
- Note language change in CHANGELOG.md

## References

- [Project Conventions](../AGENTS.md#logging-standards)
- [Error Code Standards](../lib/error_codes.sh)
- [Commit Guidelines](../CONTRIBUTING.md)

---

**Status**: Draft
**Author**: Claude (AI Assistant)
**Date**: 2025-11-12
**Version**: 1.0
