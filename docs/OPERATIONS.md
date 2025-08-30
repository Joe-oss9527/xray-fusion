# OPERATIONS

## Quickstart

```bash
# Dry run install
XRF_DRY_RUN=true bin/xrf install --topology reality-only

# Health check
bin/xrf doctor --json

# Snapshot and restore
bin/xrf snapshot create pre-change
bin/xrf snapshot restore pre-change

# Uninstall (keep state)
bin/xrf uninstall

# Uninstall and purge everything
bin/xrf uninstall --purge
```

## Paths (defaults)

- Binary: `/usr/local/bin/xray`
- Config: `/usr/local/etc/xray/config.json`
- State:  `/var/lib/xray-fusion/state.json`
- Snapshots: `/var/lib/xray-fusion/snapshots/*`
