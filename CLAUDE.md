# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xray-fusion is a modular, safe-by-default installer and manager for Xray. It's written entirely in Bash with a layered architecture emphasizing strict-mode, atomic operations, and idempotency.

## Development Commands

### Linting
```bash
make lint
# Or directly: shellcheck -S style -x $(git ls-files '*.sh' 'bin/*' 'commands/*' 'lib/*' 'modules/**/*')
```
Note: shellcheck may need to be installed first (`apt-get install shellcheck` or `dnf install shellcheck`)

### Testing
```bash
make test
# Or directly: bats -r tests
```
Note: bats may need to be installed first (`apt-get install bats` or `dnf install bats`)

### Running a Single Test
```bash
bats tests/<test-file>.bats
# Example: bats tests/install.bats
```

### Main CLI Usage
```bash
# Dry-run mode (safe preview) - automatically uses latest Xray version
XRF_DRY_RUN=true bin/xrf install --topology reality-only

# One-command installation - includes service setup and startup
bin/xrf install --topology reality-only

# With custom domain
XRAY_DOMAIN="your.domain.com" bin/xrf install --topology vision-reality

# With JSON output
bin/xrf doctor --json

# Debug mode
bin/xrf status --debug

# Complete uninstall
bin/xrf uninstall --purge
```

## Architecture

The codebase follows a strict layered architecture:

1. **Entry Point** (`bin/xrf`): Thin dispatcher that routes to commands
2. **Commands** (`commands/*.sh`): User-facing operations (install, doctor, snapshot, etc.)
3. **Services** (`services/*.sh`): Business logic assembly for Xray operations
4. **Modules** (`modules/*.sh`): OS/platform abstractions providing idempotent operations:
   - `pkg/`: Package management (apt/dnf/apk)
   - `svc/`: Service management (systemd/openrc)
   - `fw/`: Firewall management (ufw/firewalld/iptables)
   - `cert/`: Certificate management and auto-renewal
   - `net/`: Network utilities
   - `sec/`: Security operations (setcap)
   - `user/`: System user management with idempotent operations
   - `ui/`: User interface and progress tracking for installation feedback
   - `io.sh`: Atomic file I/O operations
   - `state.sh`: State persistence
5. **Templates** (`templates/xray/*.tmpl`): Modular Xray configuration components
   - `base.json.tmpl`: Core framework with dynamic inbound injection
   - `inbound-*.json.tmpl`: Protocol-specific inbound configurations
6. **Topologies** (`topologies/*.sh`): Deployment recipes that output context JSON
7. **Libraries** (`lib/*.sh`):
   - `core.sh`: Strict mode, logging, JSON output, error trapping
   - `os.sh`: OS detection and platform abstractions

## Key Design Principles

- **Strict Mode**: All scripts use `set -euo pipefail` with ERR trap
- **Atomic Operations**: File writes use temporary files + mv for atomicity  
- **Idempotency**: All module operations are safe to run multiple times
- **Security-First**: Automatic random credential generation, mandatory SHA256 verification
- **Dry-Run Support**: `XRF_DRY_RUN=true` environment variable for safe previews
- **Structured Logging**: JSON output mode with `--json` flag
- **Cross-Platform**: Supports Debian/Ubuntu/Rocky/Alma/Alpine with appropriate abstractions
- **One-Command Experience**: Complete installation including service setup and startup
- **Enterprise UX**: Professional progress tracking, service status feedback, and installation summaries
- **Dedicated Service Users**: Uses dedicated system users instead of generic 'nobody' for enhanced security

## Testing Requirements

- Run both `make lint` and `make test` before committing changes
- Add/extend Bats tests for any new module or command
- CI runs tests across multiple distros (Debian 12, Ubuntu 24.04, Rocky 9, Alma 9, Alpine)

## Code Standards

- Use POSIX-ish shell with Bash features
- Avoid `eval` and complex regex
- Keep PRs scoped to single layer/contract
- Follow existing patterns for error handling and logging via `core::log`
- **Security Requirements**: Never use hardcoded credentials; always generate random values
- **Error Handling**: Zero-tolerance for error traps; investigate and fix root causes
- **File Handling**: Use `chmod 600` for temporary files containing sensitive data
- **Official Standards**: Prefer official tool parameters over workarounds (e.g., `xray -format json`)

## Security and Quality Standards

### Mandatory Security Features
- **Random Credentials**: UUID and short IDs must be cryptographically random
- **Download Verification**: SHA256 checksums are mandatory, not optional
- **Privilege Transparency**: Notify users before sudo operations
- **Credential Isolation**: Temporary files with sensitive data use restricted permissions

### Code Quality Requirements  
- **Root Cause Analysis**: Replace all workarounds with proper solutions
- **Cross-Platform Support**: Dynamic OS detection for system-specific configurations
- **One-Command UX**: Install command includes complete service setup
- **Zero Error Output**: All error traps and warnings must be eliminated
- **User Experience Excellence**: Professional installation progress, clear error messages, and comprehensive summaries

### Best Practices
- Always consult official documentation before implementing custom solutions
- Use official tool parameters instead of file manipulation workarounds
- Implement systematic testing to identify actual root causes
- Prioritize code elegance and maintainability over quick fixes

## Recent Architecture Improvements

### Enhanced User Experience (2025-08-30)
- **Progress Tracking Module** (`modules/ui/progress.sh`): 8-step installation progress with dual-mode output (user-friendly + JSON logging)
- **Client Links Generation** (`services/xray/client-links.sh`): Automatic vless:// URL generation with QR codes for Reality and Vision protocols
- **Installation Summaries**: Post-installation service status, management commands, and documentation links

### Security Enhancements (2025-08-30)  
- **Dedicated Service Users** (`modules/user/user.sh`): Creates dedicated `xray:xray` system users instead of using generic `nobody`
- **Systemd Security Compliance**: Eliminates "Special user nobody" warnings through proper user management
- **Service Reload Improvements**: Uses systemd's `reload-or-restart` for robust configuration updates without error messages

### Code Quality Improvements (2025-08-30)
- **Eliminated Duplicate Definitions**: Extracted shared Xray functions to `services/xray/common.sh`
- **Architecture Compliance**: All new modules strictly follow the layered architecture and naming conventions
- **Error-Free Installation**: Comprehensive testing ensures zero error messages during installation process

### Template Architecture Overhaul (2025-08-30)
- **Modular Template System**: Replaced monolithic templates with component-based architecture
  - `base.json.tmpl`: Core Xray configuration framework (logging, routing, outbounds)
  - `inbound-reality.json.tmpl`: Reality protocol with `flow: "xtls-rprx-vision"` (single topology)
  - `inbound-vision.json.tmpl`: Vision+TLS protocol with certificates and `flow: "xtls-rprx-vision"`
  - `inbound-reality-dual.json.tmpl`: Reality protocol for dual-topology deployments
- **DRY Principle**: Eliminated significant code duplication through modular design
- **Dynamic Composition**: Templates are dynamically assembled based on topology requirements
- **Official Compliance**: All configurations strictly follow XTLS/Xray official standards
  - Reality protocol MUST use `flow: "xtls-rprx-vision"` (not empty string)
  - Vision uses TLS security layer, Reality uses reality security layer
- **Port Optimization**: 
  - Reality-only: Port 443 for better camouflage
  - Vision-Reality dual: Port 443 for Reality, Port 8443 for Vision+TLS