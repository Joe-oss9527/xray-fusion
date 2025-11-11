# Claude Code Configuration

This directory contains example configuration for Claude Code on the web.

## SessionStart Hook

The `hooks/SessionStart` script automatically installs development tools when a new Claude Code web session starts.

### Installation

Copy the example configuration to `.claude/`:

```bash
cp -r .claude.example/ .claude/
```

### What it Does

The SessionStart hook automatically installs:

- **shfmt v3.8.0** - Shell script formatter
- **shellcheck v0.10.0** - Shell script linter

These tools are installed to `~/.local/bin/` and only downloaded if not already present.

### Customization

Edit `.claude/hooks/SessionStart` to:
- Add more development tools
- Change tool versions
- Add project-specific initialization

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

- The `.claude/` directory is gitignored (user-specific configuration)
- Each developer can customize their own environment
- No manual tool installation needed in future sessions
