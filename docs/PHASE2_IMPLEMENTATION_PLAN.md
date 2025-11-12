# Phase 2 Implementation Plan: Advanced UX Features

> **Status**: Planning
> **Estimated Time**: 16-21 hours
> **Dependencies**: Phase 1 completed
> **Goal**: Enhance user experience with advanced features for configuration, monitoring, and maintenance

## Overview

Phase 2 builds upon Phase 1's foundation to provide advanced user experience features that simplify daily operations, improve observability, and reduce maintenance burden.

### Phase 1 Achievements (Baseline)

- ✅ Friendly error messages with recovery guidance
- ✅ Installation preview with confirmation
- ✅ SNI domain validation
- ✅ Post-installation health check
- ✅ Enhanced parameter validation

### Phase 2 Goals

1. **Simplify Configuration**: Pre-built templates for common scenarios
2. **Improve Observability**: Enhanced logging and monitoring
3. **Enable Recovery**: Backup/restore and rollback capabilities
4. **Streamline Upgrades**: Safe version upgrades with validation
5. **Provide Insights**: Traffic statistics and system metrics

---

## Task Breakdown

### Task 1: Configuration Template System (3-4h)

**Goal**: Provide pre-built configuration templates for common use cases.

**User Story**: As a user, I want to select from pre-built templates (home, office, server) instead of manually configuring every parameter.

#### Sub-tasks

**1.1 Design Template System** (30-45min)
- Define template structure (JSON format)
- Design template categories (home, office, server, custom)
- Plan template storage location (`/usr/local/etc/xray-fusion/templates/`)

**1.2 Create Built-in Templates** (1-1.5h)
- Home template: Single user, moderate security
- Office template: Multi-user, high security
- Server template: Production-grade, strict security
- Define template metadata (name, description, topology, ports, etc.)

**1.3 Implement Template Engine** (1-1.5h)
- `templates::list()` - List available templates
- `templates::load(id)` - Load template configuration
- `templates::apply(id)` - Apply template to installation
- `templates::validate(id)` - Validate template structure

**1.4 Integrate with Install Flow** (30-45min)
- Add `--template <id>` parameter to install command
- Template parameters override defaults
- User can still customize template values

**1.5 Testing and Documentation** (30-45min)
- Unit tests for template engine (15 tests)
- Integration test with install command
- Update README with template examples

**Acceptance Criteria**:
- [ ] `xrf install --template home` installs with home template
- [ ] `xrf templates list` shows available templates
- [ ] Templates are validated before application
- [ ] User can override template values with CLI parameters
- [ ] All tests passing

**Implementation Example**:
```bash
# Install with home template
xrf install --template home

# Install with office template and custom domain
xrf install --template office --domain vpn.company.com

# List available templates
xrf templates list
```

---

### Task 2: Enhanced Logging and Viewing (2-3h)

**Goal**: Provide easy access to Xray logs with filtering and formatting.

**User Story**: As a user, I want to quickly view Xray logs filtered by level and time range without using journalctl commands.

#### Sub-tasks

**2.1 Design Log Viewer** (30min)
- Define log filtering options (level, time range, tail/follow)
- Plan integration with journalctl
- Design output format (colored, timestamped)

**2.2 Implement Log Functions** (1-1.5h)
- `logs::view(level, since, lines)` - View logs with filters
- `logs::follow()` - Real-time log streaming
- `logs::export(file)` - Export logs to file
- `logs::stats()` - Log statistics (error count, warn count)

**2.3 Create xrf logs Command** (30-45min)
- `xrf logs [--level <level>] [--since <time>] [--lines <n>]`
- `xrf logs --follow` - Live tail
- `xrf logs --export <file>` - Export to file

**2.4 Testing and Documentation** (30-45min)
- Unit tests for log functions (12 tests)
- Integration test with actual logs
- Update help documentation

**Acceptance Criteria**:
- [ ] `xrf logs` shows recent Xray logs
- [ ] `xrf logs --level error` filters error logs only
- [ ] `xrf logs --follow` streams logs in real-time
- [ ] Logs are colored and formatted for readability
- [ ] All tests passing

**Implementation Example**:
```bash
# View recent logs
xrf logs

# View only errors from last hour
xrf logs --level error --since "1 hour ago"

# Follow logs in real-time
xrf logs --follow

# Export logs to file
xrf logs --export xray-logs-$(date +%Y%m%d).txt
```

---

### Task 3: Backup and Restore System (4-5h)

**Goal**: Enable users to backup, restore, and migrate Xray configurations.

**User Story**: As a user, I want to backup my configuration before making changes and restore it if something goes wrong.

#### Sub-tasks

**3.1 Design Backup System** (45min-1h)
- Define backup format (tar.gz with metadata)
- Plan backup storage location (`/var/lib/xray-fusion/backups/`)
- Design backup metadata (timestamp, topology, version, hash)

**3.2 Implement Backup Functions** (1.5-2h)
- `backup::create(name)` - Create configuration backup
- `backup::list()` - List available backups
- `backup::restore(name)` - Restore from backup
- `backup::delete(name)` - Delete backup
- `backup::verify(name)` - Verify backup integrity

**3.3 Create Backup Commands** (1-1.5h)
- `xrf backup create [--name <name>]` - Create backup
- `xrf backup list` - List backups
- `xrf backup restore <name>` - Restore backup
- `xrf backup delete <name>` - Delete backup

**3.4 Integrate Auto-backup** (45min-1h)
- Auto-backup before install/upgrade
- Auto-backup before configuration changes
- Backup retention policy (keep last N backups)

**3.5 Testing and Documentation** (45min-1h)
- Unit tests for backup functions (18 tests)
- Integration test (backup → modify → restore)
- Update documentation

**Acceptance Criteria**:
- [ ] `xrf backup create` creates valid backup
- [ ] `xrf backup restore` restores configuration correctly
- [ ] Auto-backup before install/upgrade
- [ ] Backup integrity verification with hash
- [ ] All tests passing

**Implementation Example**:
```bash
# Create backup
xrf backup create --name pre-upgrade

# List backups
xrf backup list

# Restore from backup
xrf backup restore pre-upgrade

# Auto-backup (automatic during install)
xrf install --topology vision-reality --domain new.example.com
```

---

### Task 4: Safe Version Upgrade (3-4h)

**Goal**: Provide safe and reliable Xray version upgrades with validation and rollback.

**User Story**: As a user, I want to upgrade Xray version safely with automatic validation and rollback on failure.

#### Sub-tasks

**4.1 Design Upgrade System** (30-45min)
- Define upgrade workflow (backup → download → validate → switch)
- Plan version validation (compatibility checks)
- Design rollback mechanism

**4.2 Implement Upgrade Functions** (1.5-2h)
- `upgrade::check_available()` - Check for new versions
- `upgrade::validate_version(version)` - Validate version compatibility
- `upgrade::perform(version)` - Execute upgrade
- `upgrade::rollback()` - Rollback to previous version

**4.3 Create Upgrade Command** (1-1.5h)
- `xrf upgrade [--version <version>]` - Upgrade to version
- `xrf upgrade --check` - Check for updates
- `xrf upgrade --rollback` - Rollback last upgrade

**4.4 Testing and Documentation** (45min-1h)
- Unit tests for upgrade functions (15 tests)
- Integration test (upgrade → validate → rollback)
- Update documentation

**Acceptance Criteria**:
- [ ] `xrf upgrade` upgrades to latest version safely
- [ ] Auto-backup before upgrade
- [ ] Configuration validation after upgrade
- [ ] Rollback on validation failure
- [ ] All tests passing

**Implementation Example**:
```bash
# Check for updates
xrf upgrade --check

# Upgrade to latest version
xrf upgrade

# Upgrade to specific version
xrf upgrade --version v1.8.9

# Rollback if issues
xrf upgrade --rollback
```

---

### Task 5: Traffic and System Monitoring (4-5h)

**Goal**: Provide real-time traffic statistics and system resource monitoring.

**User Story**: As a user, I want to see traffic statistics and system metrics to understand usage and performance.

#### Sub-tasks

**5.1 Design Monitoring System** (45min-1h)
- Define metrics to collect (traffic, connections, CPU, memory)
- Plan data collection method (Xray API + system stats)
- Design output format (dashboard + JSON)

**5.2 Implement Monitoring Functions** (2-2.5h)
- `monitor::traffic_stats()` - Get traffic statistics
- `monitor::connections()` - Get active connections
- `monitor::system_resources()` - Get CPU/memory usage
- `monitor::uptime()` - Get service uptime

**5.3 Create Monitor Command** (1-1.5h)
- `xrf monitor` - Display monitoring dashboard
- `xrf monitor --json` - JSON output for automation
- `xrf monitor --watch` - Real-time monitoring

**5.4 Testing and Documentation** (45min-1h)
- Unit tests for monitor functions (12 tests)
- Integration test with running Xray
- Update documentation

**Acceptance Criteria**:
- [ ] `xrf monitor` shows traffic and system stats
- [ ] Real-time monitoring with `--watch`
- [ ] JSON output for automation
- [ ] Graceful handling when Xray is not running
- [ ] All tests passing

**Implementation Example**:
```bash
# View monitoring dashboard
xrf monitor

# Real-time monitoring
xrf monitor --watch

# JSON output for automation
xrf monitor --json
```

---

## Implementation Order

### Week 1 (8-10h)
1. Task 1: Configuration Template System (3-4h)
2. Task 2: Enhanced Logging and Viewing (2-3h)
3. Task 3: Backup and Restore System (Start) (3h)

### Week 2 (8-11h)
1. Task 3: Backup and Restore System (Complete) (1-2h)
2. Task 4: Safe Version Upgrade (3-4h)
3. Task 5: Traffic and System Monitoring (4-5h)

---

## Success Metrics

### Quantitative
- [ ] All 72+ new tests passing (15+12+18+15+12)
- [ ] No shellcheck warnings
- [ ] Zero regression in existing functionality
- [ ] Code coverage >80% for new modules

### Qualitative
- [ ] Users can install with templates in <30 seconds
- [ ] Users can view logs without journalctl knowledge
- [ ] Users can backup/restore configurations safely
- [ ] Users can upgrade Xray versions confidently
- [ ] Users have visibility into traffic and performance

### UX Maturity Score Target
- **Current**: 7.5/10 (after Phase 1)
- **Target**: 9.0/10 (after Phase 2)

---

## Risk Mitigation

### Technical Risks
1. **Template compatibility**: Mitigated by validation before application
2. **Backup integrity**: Mitigated by hash verification
3. **Upgrade failures**: Mitigated by auto-rollback on validation failure
4. **Monitoring overhead**: Mitigated by efficient data collection

### User Experience Risks
1. **Template complexity**: Mitigated by simple defaults and clear documentation
2. **Backup confusion**: Mitigated by clear naming and metadata
3. **Upgrade anxiety**: Mitigated by auto-backup and rollback

---

## Dependencies

### External Tools
- `jq` - JSON processing (already required)
- `tar` - Backup compression
- `journalctl` - Log access (systemd)
- `ss`/`netstat` - Network stats (already used)

### Internal Modules
- `lib/core.sh` - Logging and utilities
- `lib/validators.sh` - Input validation
- `modules/state.sh` - State management
- `services/xray/common.sh` - Xray utilities

---

## Testing Strategy

### Unit Tests
- Test all new functions in isolation
- Mock external dependencies (systemd, network)
- Validate error handling and edge cases

### Integration Tests
- Test complete workflows (backup → modify → restore)
- Test upgrade scenarios (backup → upgrade → rollback)
- Test monitoring with running Xray

### Manual Testing
- Test on fresh installation
- Test on existing installation with data
- Test error scenarios and recovery

---

## Documentation Updates

### README.md
- Add template system examples
- Add backup/restore examples
- Add monitoring examples

### New Documentation
- TEMPLATES.md - Template reference and customization
- BACKUP.md - Backup and restore guide
- MONITORING.md - Monitoring and metrics guide

### CLAUDE.md Updates
- Add ADR for template system
- Add ADR for backup format
- Add ADR for upgrade strategy

---

## Post-Phase 2 Roadmap (Phase 3 Ideas)

1. **Web UI Dashboard** - Browser-based management interface
2. **Multi-server Management** - Manage multiple Xray instances
3. **Auto-scaling** - Dynamic resource adjustment
4. **Alert System** - Email/webhook notifications
5. **Configuration Wizard** - Interactive TUI for installation

---

**Document Version**: 1.0
**Last Updated**: 2025-11-12
**Author**: Claude (Anthropic)
