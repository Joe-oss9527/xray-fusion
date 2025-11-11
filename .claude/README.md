# Claude Code Configuration

This directory contains Claude Code configuration for the xray-fusion project.

## SessionStart Hook

The SessionStart hook automatically runs when a new Claude Code session starts, ensuring development tools are ready.

### Configuration

Hooks are defined in `.claude/settings.json` following the [official documentation](https://code.claude.com/docs/en/hooks):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/scripts/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

### What it Does

The SessionStart hook automatically installs development tools in **web/iOS environments only**:

- **shfmt v3.8.0** - Shell script formatter
- **shellcheck v0.10.0** - Shell script linter
- **bats-core v1.11.0** - Bash Automated Testing System

**Invocation Source Detection** (Optimized):
- **startup**: First-time session initialization → **Auto-install tools**
- **resume**: Resume from `/resume` or `--resume` → **Skip installation** (tools already available)
- **clear**: After `/clear` command → **Skip installation** (tools already available)
- **compact**: Auto/manual compaction → **Skip installation** (tools already available)

**Environment Detection**:
- **Web/iOS** (`CLAUDE_CODE_REMOTE=true`): Auto-install tools to `~/.local/bin/`
- **Desktop** (`CLAUDE_CODE_REMOTE=false` or unset): Skip auto-install, show manual installation instructions

These tools are installed to `~/.local/bin/` (and `~/.local/share/bats-core/` for bats) and only downloaded if not already present.

### File Structure

```
.claude/
├── settings.json              # Hook configuration (committed)
├── settings.local.json        # User-specific overrides (gitignored)
├── scripts/
│   └── session-start.sh      # SessionStart hook script (committed)
└── README.md                  # This file
```

### Customization

To customize hook behavior:

1. **For personal use**: Create `.claude/settings.local.json` (gitignored)
2. **For team-wide changes**: Edit `.claude/settings.json` and commit

Example `.claude/settings.local.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/scripts/my-custom-hook.sh"
          }
        ]
      }
    ]
  }
}
```

### Testing

Test the hook script manually:

```bash
./.claude/scripts/session-start.sh
```

### How It Works

When you start a new Claude Code session:

1. Claude Code reads `.claude/settings.json` (and `.claude/settings.local.json` if exists)
2. SessionStart hooks are triggered automatically
3. **The hook script detects invocation source** from JSON input (stdin)
4. **If `source == "startup"`**: Install missing tools to `~/.local/bin/`
5. **If `source != "startup"`**: Skip installation (tools already available from initial startup)
6. Tools are ready for `make fmt`, `make lint`, etc.

### Optimization Benefits

**Performance**: Installation tasks only run once at first startup, not on every session resume/clear/compact.

**Reliability**: Existing tools remain available across session operations without redundant reinstallation.

**Backward Compatibility**: Falls back to `startup` behavior if JSON input is unavailable (e.g., older Claude Code versions).

### Notes

- **Committed files**: `settings.json`, `scripts/session-start.sh` (project-wide automation)
- **Gitignored files**: `settings.local.json` (user-specific overrides)
- **Installation**: Tools are installed per-user to `~/.local/bin/` (no sudo required)
- **Idempotent**: Safe to run multiple times, won't reinstall existing tools

### References

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [SessionStart Hook Guide](https://code.claude.com/docs/en/hooks#sessionstart)
