# Error Codes Reference

> **Version**: Phase 1 - UX Optimization
> **Last Updated**: 2025-11-11

xray-fusion uses structured error codes to provide clear, actionable error messages with recovery guidance.

---

## Error Code Format

```
XRF-CATEGORY-NUMBER
```

**Categories**:
- `CONFIG` - Configuration and parameter errors
- `NETWORK` - Network connectivity errors
- `CERT` - Certificate-related errors
- `XRAY` - Xray binary and configuration errors
- `SYSTEM` - System requirements and permissions
- `PLUGIN` - Plugin-related errors

---

## Configuration Errors (CONFIG)

### XRF-CONFIG-001: Invalid Domain

**Cause**: The provided domain name is invalid or not allowed.

**Common Reasons**:
- Private IP addresses (RFC 1918): `192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`
- Link-local addresses (RFC 3927): `169.254.x.x`
- Special-use TLDs (RFC 6761): `.test`, `.invalid`
- IPv6 private addresses: `::1`, `fc00::/7`, `fe80::/10`
- Localhost or `.local` domains

**Resolution**:
- Use a public domain name for `vision-reality` topology
- Switch to `reality-only` topology which doesn't require a domain

**Examples**:
```bash
# Valid: Use public domain
xrf install --topology vision-reality --domain vpn.example.com

# Valid: Use reality-only (no domain needed)
xrf install --topology reality-only
```

---

### XRF-CONFIG-002: Invalid Topology

**Cause**: The specified topology is not supported.

**Resolution**: Choose one of the supported topologies:
- `reality-only` - Simple setup, no domain required
- `vision-reality` - Dual protocol, requires domain + TLS certificates

**Examples**:
```bash
# Valid topologies
xrf install --topology reality-only
xrf install --topology vision-reality --domain example.com
```

---

### XRF-CONFIG-003: Missing Required Parameter

**Cause**: A required parameter was not provided for the selected configuration.

**Common Scenarios**:
- `--domain` missing for `vision-reality` topology
- `--topology` not specified

**Resolution**: Provide the missing parameter or choose a different configuration.

**Examples**:
```bash
# Fix: Add missing domain
xrf install --topology vision-reality --domain example.com

# Fix: Specify topology
xrf install --topology reality-only
```

---

### XRF-CONFIG-004: Invalid UUID Format

**Cause**: The provided UUID does not match RFC 4122 format (8-4-4-4-12 hexadecimal digits).

**Resolution**:
- Let xray-fusion auto-generate a UUID (recommended)
- Provide a valid UUID
- Use `--uuid-from-string` for memorable identifiers

**Examples**:
```bash
# Auto-generate (recommended)
xrf install --topology reality-only

# Use custom UUID
xrf install --topology reality-only --uuid 6ba85179-d64e-4cb8-901f-bfb8e9e7d5f1

# Generate from string (memorable)
xrf install --topology reality-only --uuid-from-string alice
```

---

## Network Errors (NETWORK)

### XRF-NETWORK-001: Port Conflict

**Cause**: The required port is already in use by another process.

**Resolution**:
1. Stop the conflicting service
2. Use a different port

**Diagnostic Commands**:
```bash
# Check what's using the port
sudo lsof -i :443
sudo netstat -tulpn | grep 443

# Stop conflicting service (example)
sudo systemctl stop nginx
```

**Alternative Configuration**:
```bash
# Use custom port
XRAY_PORT=8443 xrf install --topology reality-only
```

---

## Certificate Errors (CERT)

### XRF-CERT-001: Certificate Not Found

**Cause**: Required TLS certificate files are missing.

**Resolution**:
- **Option 1**: Enable the `cert-auto` plugin for automatic certificate management
- **Option 2**: Manually place certificates in the correct location

**Examples**:
```bash
# Option 1: Automatic certificates (recommended)
xrf install --topology vision-reality --domain example.com --plugins cert-auto

# Option 2: Manual certificate placement
sudo cp fullchain.pem /usr/local/etc/xray/certs/fullchain.pem
sudo cp privkey.pem /usr/local/etc/xray/certs/privkey.pem
```

---

## Xray Errors (XRAY)

### XRF-XRAY-001: Configuration Test Failed

**Cause**: Xray configuration validation failed (syntax or logical errors).

**Resolution**: Review configuration files for syntax errors.

**Diagnostic Commands**:
```bash
# Manually test configuration
sudo /usr/local/bin/xray -test -confdir /usr/local/etc/xray/active

# Check recent configuration changes
ls -lt /usr/local/etc/xray/active/

# View Xray logs
sudo journalctl -u xray -n 50
```

**Common Issues**:
- JSON syntax errors (missing commas, brackets)
- Invalid parameter values
- Incompatible protocol combinations

---

## System Errors (SYSTEM)

### XRF-SYSTEM-001: Missing System Dependency

**Cause**: A required command or package is not installed.

**Resolution**: Install the missing package using your system's package manager.

**Examples**:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install <package>

# CentOS/RHEL
sudo yum install <package>

# Alpine
sudo apk add <package>
```

**Common Dependencies**:
- `curl` - Download Xray releases
- `jq` - JSON processing
- `openssl` - Certificate operations
- `systemd` - Service management

---

## Plugin Errors (PLUGIN)

### XRF-PLUGIN-001: Plugin Not Found

**Cause**: The specified plugin does not exist.

**Resolution**: Check available plugins and verify the plugin ID is correct.

**Examples**:
```bash
# List available plugins
xrf plugin list

# Install with correct plugin names
xrf install --plugins cert-auto,firewall
```

**Available Plugins**:
- `cert-auto` - Automatic certificate management (Caddy + Let's Encrypt)
- `firewall` - Firewall port management
- `logrotate-obs` - Log rotation and observability
- `links-qr` - QR code generation for client links

---

## Error Output Formats

### Text Format (Default)

```
[ERROR] XRF-CONFIG-001: Invalid domain

Reason:
  Domain '192.168.1.1' is invalid: RFC 1918 private IP address

Resolution:
  Use a public domain name for vision-reality topology, or
  Switch to reality-only topology which doesn't require a domain.

Examples:
  xrf install --topology vision-reality --domain vpn.example.com
  xrf install --topology reality-only  # No domain needed

Learn more: https://github.com/Joe-oss9527/xray-fusion#error-codes
```

### JSON Format

Set `XRF_JSON=true` for machine-readable output:

```json
{
  "ts": "2025-11-11T12:34:56Z",
  "level": "error",
  "error_code": "XRF-CONFIG-001",
  "title": "Invalid domain",
  "reason": "Domain '192.168.1.1' is invalid: RFC 1918 private IP address",
  "resolution": "Use a public domain name for vision-reality topology, or switch to reality-only topology which doesn't require a domain.",
  "examples": "xrf install --topology vision-reality --domain vpn.example.com\nxrf install --topology reality-only",
  "docs": "https://github.com/Joe-oss9527/xray-fusion#error-codes"
}
```

---

## Troubleshooting

### General Workflow

1. **Read the error code** - Identify the category and specific error
2. **Review the reason** - Understand why the error occurred
3. **Follow the resolution** - Apply the suggested fix
4. **Check examples** - Refer to working configurations
5. **Consult documentation** - Visit the learn more link for detailed information

### Getting Help

If you encounter an error not covered in this guide:

1. **Check logs**:
   ```bash
   sudo journalctl -u xray -n 100
   XRF_DEBUG=true xrf install --topology reality-only
   ```

2. **Search existing issues**:
   https://github.com/Joe-oss9527/xray-fusion/issues

3. **Report a bug**:
   Include the complete error message and error code

---

## Related Documentation

- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - General troubleshooting guide
- [AGENTS.md](../AGENTS.md) - Development guidelines
- [README.md](../README.md) - Usage documentation

---

**Last Updated**: 2025-11-11
**Maintainer**: xray-fusion development team
