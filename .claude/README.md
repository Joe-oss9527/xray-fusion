# Claude Code Configuration

This directory contains Claude Code configuration for the xray-fusion project.

## SessionStart Hook

The `hooks/SessionStart` script automatically runs when a new Claude Code web session starts.

### What it Does

The SessionStart hook automatically installs:

- **shfmt v3.8.0** - Shell script formatter
- **shellcheck v0.10.0** - Shell script linter

These tools are installed to `~/.local/bin/` and only downloaded if not already present.

### Customization

The hook is committed to git as the project standard. To customize:

1. **For personal use**: Edit `.claude/hooks/SessionStart` locally and keep as uncommitted changes
2. **For team-wide changes**: Edit, commit, and push to share with all developers
3. The hook is designed to be idempotent (safe to run multiple times)

### Testing

Test the hook manually:

```bash
./.claude/hooks/SessionStart
```

### How It Works

When you start a new Claude Code web session:

1. Claude Code automatically executes `.claude/hooks/SessionStart`
2. The hook checks for required tools
3. Missing tools are downloaded and installed to `~/.local/bin/`
4. Tools are ready for `make fmt`, `make lint`, etc.

### Note

- Only `hooks/` directory is committed to git (project-wide automation)
- Other files in `.claude/` are gitignored (user-specific settings)
- Tools are installed per-user to `~/.local/bin/` (no sudo required)
- No manual tool installation needed in future Claude Code web sessions
