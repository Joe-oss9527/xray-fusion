# xray-fusion

Enterprise-grade, modular installer & manager for **Xray**.

## ✨ Key Features

- **🔒 Security-First Design**: Strict-mode shell with atomic operations & structured audit logging
- **🏗️ Modular Architecture**: Idempotent modules (pkg/svc/fw/cert/io) with clean separation
- **🚀 Production Ready**: Dual topologies (`reality-only`, `vision-reality`) with dry-run previews
- **📊 Advanced Diagnostics**: JSON-structured logs and comprehensive health checks
- **🔄 State Management**: Configuration snapshots, atomic rollback & complete purge options
- **🧪 Battle-Tested**: Full CI matrix across Debian/Ubuntu/Rocky/Alma distributions

## 🚀 Installation

### Basic Installation
```bash
# Reality-only topology (recommended)
bin/xrf install --topology reality-only

# Dry-run preview (safe)
XRF_DRY_RUN=true bin/xrf install --topology reality-only
```

### Domain-based Installation
```bash
# Install with custom domain (Vision + Reality topology)
XRAY_DOMAIN="your-domain.com" bin/xrf install --topology vision-reality

# Preview domain installation (safe)
XRAY_DOMAIN="your-domain.com" XRF_DRY_RUN=true bin/xrf install --topology vision-reality
```

## 🛠️ Management Operations

```bash
# System health & diagnostics
bin/xrf doctor --json

# Configuration snapshots
bin/xrf snapshot create pre-upgrade
bin/xrf snapshot restore pre-upgrade

# Clean removal options
bin/xrf uninstall              # Keep configuration
bin/xrf uninstall --purge      # Complete removal
```

See more in `docs/OPERATIONS.md` and `docs/ARCHITECTURE.md`.


See **docs/CHECKLIST.md** for a deployment checklist.
