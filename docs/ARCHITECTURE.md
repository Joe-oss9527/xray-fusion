# ARCHITECTURE

This repo implements a layered, modular shell architecture for installing and managing **Xray**:

- `bin/xrf` – a thin CLI that dispatches into `commands/*`
- `lib/*` – pure utilities (strict mode, logging, json helpers)
- `modules/*` – OS/service/firewall/cert/io abstractions (idempotent actions)
- `services/*` – business assembly (xray install/configure)
- `topologies/*` – deployment recipes that emit **context JSON**
- `commands/*` – user-facing flows (`install`, `status`, `doctor`, `snapshot`, `uninstall`)

Key properties: strict-mode, atomic writes, dry-run, structured logs, tests and CI.
