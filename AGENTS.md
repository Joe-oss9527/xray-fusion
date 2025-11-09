# Repository Guidelines

## Project Structure & Module Organization
- `bin/xrf`: CLI entrypoint (install/status/uninstall/plugin).
- `commands/`: High‑level workflows (e.g., `install.sh`, `status.sh`).
- `lib/`: Core utilities (`core.sh`, `args.sh`, `plugins.sh`).
- `modules/`: Reusable helpers (`io.sh`, `state.sh`, `fw/*`, `user/*`, `web/*`).
- `services/xray/`: Xray install/configure/systemd logic.
- `plugins/available/<id>/plugin.sh`: Built‑in plugins; `plugins/enabled/` is auto‑managed.
- `packaging/systemd/`: Unit templates.

## Build, Test, and Development Commands
- `make fmt` — Format all Bash with shfmt (2‑space, Bash mode).
- `make lint` — ShellCheck across scripts (errors/warnings, `-x`).
- Run locally:
  - `bin/xrf install --topology reality-only`
  - `bin/xrf status`, `bin/xrf links`, `bin/xrf uninstall`
  - Example safe sandbox: `XRF_PREFIX=$PWD/tmp/prefix XRF_ETC=$PWD/tmp/etc bin/xrf install --topology reality-only`

## Coding Style & Naming Conventions
- Language: Bash; start files with `#!/usr/bin/env bash` and `set -euo pipefail` where applicable.
- Indentation: 2 spaces; UTF‑8; LF (see `.editorconfig`).
- Namespacing: `namespace::function` (e.g., `core::log`, `io::atomic_write`).
- Variables: lowercase `local` vars; exported/env vars UPPER_SNAKE (e.g., `XRAY_*`, `XRF_*`).
- File names: kebab‑case; plugins use ID `[a-zA-Z0-9_-]+` and functions via `plugins::fn_prefix`.
- Use helpers: `io::ensure_dir`, `io::atomic_write`, `core::log`, `core::with_flock`.

## Testing Guidelines
- Test framework: bats-core with 96 unit tests across 5 test files.
- Fast feedback: `make lint && make fmt && make test-unit`.
- Run tests:
  - `make test` — Run all tests (unit + integration)
  - `make test-unit` — Run unit tests only
  - `bats -t tests/unit/*.bats` — Run with verbose output
- Functional checks:
  - Dry config test is automatic and cannot be skipped (see ADR-007).
  - Avoid touching system paths by overriding `XRF_PREFIX` and `XRF_ETC` to a temp dir.
- Prefer validating inputs and error codes; don't print secrets.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, scoped (e.g., “Fix …”, “Add …”, “Implement …”).
- Group related changes; keep diffs minimal; reference areas (commands/lib/services/plugins) in the body when useful.
- PRs must include:
  - Summary of changes and rationale
  - How to validate (exact commands/env vars)
  - Screenshots or logs if behavior changes
  - Linked issues (if any)

## Plugin Tips
- Add new plugin at `plugins/available/<id>/plugin.sh` with metadata:
  - `XRF_PLUGIN_ID`, `XRF_PLUGIN_VERSION`, `XRF_PLUGIN_DESC`, `XRF_PLUGIN_HOOKS`.
- Supported hooks include: `configure_pre|configure_post|deploy_post|service_setup|service_remove|links_render|uninstall_pre`.
- Validate IDs with `plugins::validate_id`; never traverse paths; use repo helpers.

