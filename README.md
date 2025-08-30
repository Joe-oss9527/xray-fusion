# xray-fusion

Modular, safe-by-default installer & manager for **Xray**.

## Features
- Strict-mode shell + structured logs (`--json`)
- Idempotent modules (pkg/svc/fw/cert/io)
- Atomic config writes + dry-run previews
- Topologies: `reality-only`, `vision-reality`
- Snapshot/restore, uninstall `--purge`, hardening (setcap)
- Tests (Bats) + CI matrix (Debian/Ubuntu/Rocky/Alma)

## Quickstart

```bash
# Dry-run installation
XRF_DRY_RUN=true bin/xrf install --version v1.8.0 --topology reality-only

# Health check
bin/xrf doctor --json

# Snapshot & restore
bin/xrf snapshot create pre-upgrade
bin/xrf snapshot restore pre-upgrade

# Uninstall (keep state) / Purge all
bin/xrf uninstall
bin/xrf uninstall --purge
```

See more in `docs/OPERATIONS.md` and `docs/ARCHITECTURE.md`.


See **docs/CHECKLIST.md** for a deployment checklist.
