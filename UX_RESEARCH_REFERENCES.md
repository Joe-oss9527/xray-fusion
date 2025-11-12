# UX Research References: Top CLI Tools to Study

This document provides specific references for researching UX patterns mentioned in the main analysis.

## 1. Error Message UX Patterns

### Docker CLI - Friendly Error Messages
**Example**: When Docker desktop is not running
```
error during connect: this error may indicate that the docker daemon is not running
```

**Pattern to research**:
- Contextual problem statement
- Possible causes listed
- Link to troubleshooting documentation
- Suggested next action

**Reference**: `docker ps` when Docker is not running

**Application to xray-fusion**:
- When domain validation fails: Show why (e.g., "contains private IP address")
- When Xray download fails: Show network diagnostic suggestions
- When config fails: Show validation errors with fixes

### GitHub CLI - Did-You-Mean Suggestions
**Example**: Typo in subcommand
```
$ gh isue list
'issue' is not a gh command. Did you mean 'issue'?
```

**Pattern to research**:
- Fuzzy matching algorithm (Levenshtein distance)
- Suggestion formatting
- Confidence threshold

**Reference**: `gh <command> --help` output structure

**Application to xray-fusion**:
- Typo in topology: "--topology ralityonly" → suggest "reality-only"
- Unknown parameter: "--domian" → suggest "--domain"
- Invalid plugin: "--plugins bad-id" → suggest available plugins

### npm - Error Context with Recovery
**Example**: Missing dependency error
```
npm ERR! code ERESOLVE
npm ERR! ERESOLVE unable to resolve dependency tree
npm ERR!
npm ERR! While resolving: myapp@1.0.0
npm ERR! Found: react@17.0.0
...
npm ERR! Fix the upstream dependency conflict, or retry
npm ERR! this command with --force or --legacy-peer-deps
```

**Pattern to research**:
- Error code and explanation
- Affected component and version
- Specific recovery instructions
- Reference link to documentation

**Application to xray-fusion**:
- Dependency missing: Show system package command to install
- Disk space low: Show cleanup suggestions
- Permission denied: Show commands to fix permissions

---

## 2. Progress Indication Patterns

### Docker - Layered Progress
**Example**: Building image
```
Step 1/5 : FROM ubuntu:20.04
 ---> f643c72bc25d
Step 2/5 : RUN apt-get update && apt-get install -y curl
 ---> Running in 12345abcde
...
Step 5/5 : CMD ["./app"]
 ---> Running in fedcba54321
 ---> abc123def456
Successfully built abc123def456
```

**Pattern to research**:
- Step counter (Step N/Total)
- Container ID tracking
- Layer identification
- Build time tracking

**Reference**: `docker build .` output

**Application to xray-fusion**:
```
Step 1/6 : Checking system requirements
Step 2/6 : Downloading Xray v1.8.1 [████████░░░░░░░░░░░░] 45%
Step 3/6 : Verifying checksum ✓
Step 4/6 : Configuring topology...
Step 5/6 : Installing systemd units
Step 6/6 : Starting Xray service
```

### Terraform - Operation Progress
**Example**: Terraform apply
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

instance_ip = "192.168.1.100"
...
Apply took 2m45s
```

**Pattern to research**:
- Clear operation start/end
- Resource tracking (added/changed/destroyed)
- Summary statistics
- Elapsed time

**Reference**: `terraform apply` output

**Application to xray-fusion**:
```
[INFO] Install started: reality-only topology
[INFO] Downloading Xray v1.8.1...
[INFO] Verifying integrity...
[INFO] Installing service files...
[INFO] Creating configuration...
[SUCCESS] Install complete in 15s

Configuration:
  Topology: reality-only
  Port: 443
  Status: Running ✓
```

### curl/wget - Download Progress
**Example**: File download
```
$ curl -# -O https://example.com/file.zip
######################################################################## 100.0%
```

**Pattern to research**:
- Simple ASCII progress bar
- Percentage display
- Size information
- ETA (estimated time)

**Reference**: `curl -# <url>` or `wget` default output

**Application to xray-fusion**:
```
[INFO] Downloading Xray v1.8.1
  Connecting: ✓
  Receiving: ████████████░░░░░░░░░ 58% (5.2 MB / 9.0 MB) ETA 3s
```

---

## 3. Output Formatting Patterns

### Kubernetes (kubectl) - Table Output
**Example**: List pods
```
$ kubectl get pods -o wide
NAME                              READY   STATUS    RESTARTS   AGE    IP             NODE
nginx-deployment-66b6c48dd5-abc   1/1     Running   0          2d     10.244.0.5     worker-1
nginx-deployment-66b6c48dd5-def   1/1     Running   1          3d     10.244.0.6     worker-2
```

**Pattern to research**:
- Column-based layout
- Column width adjustment
- `--output` flag support (wide, json, yaml)
- Color highlighting for status

**Reference**: `kubectl get --help` output flags

**Application to xray-fusion**:
```
$ xrf status --output wide
STATUS    TOPOLOGY        VERSION   DOMAIN              PORTS              
Running   vision-reality  v1.8.1    example.com         8443(Vision), 443(Real)

$ xrf links --output json
{
  "vision": "vless://...",
  "reality": "vless://..."
}
```

### Terraform - Diff Output
**Example**: Plan output
```
Terraform will perform the following actions:

# aws_instance.example will be created
  + resource "aws_instance" "example" {
      + ami           = "ami-0c55b159cbfafe1f0"
      + instance_type = "t2.micro"
      + tags          = {
          + "Name" = "test-instance"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

**Pattern to research**:
- Resource operation symbols (+ = -)
- Nested field indentation
- Colored output (green for additions)
- Summary line with operation counts

**Reference**: `terraform plan` output

**Application to xray-fusion**:
```
Preview: --topology reality-only --domain example.com

Changes to be made:
  + Install Xray v1.8.1
  + Configure vision-reality topology
  + Create Xray user account
  + Install systemd units
  + Enable auto-certificate management

Apply changes? [y/N]
```

### GitHub CLI - Structured JSON
**Example**: Issue list with JSON
```
$ gh issue list --json title,state,author --limit 3
[
  {
    "author": {
      "login": "octocat"
    },
    "state": "OPEN",
    "title": "Found a bug"
  },
  ...
]
```

**Pattern to research**:
- Field selection via `--json` flags
- Structured output (valid JSON)
- Consistent formatting

**Reference**: `gh <command> --json` pattern

**Application to xray-fusion**:
```
$ xrf status --json
{
  "status": "running",
  "topology": "vision-reality",
  "version": "v1.8.1",
  "xray": {
    "vision_port": 8443,
    "reality_port": 443
  }
}
```

---

## 4. Interactive Mode Patterns

### GitHub CLI - Authentication Flow
**Example**: Interactive login
```
$ gh auth login
? What is your preferred protocol for Git operations? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Paste an authentication token
Paste your authentication token: ****
✓ Authentication complete. You're logged in as octocat.
```

**Pattern to research**:
- Multi-step questionnaire
- Input validation per step
- Summary of choices made
- Confirmation prompt

**Reference**: `gh auth login` interactive flow

**Application to xray-fusion**:
```
$ xrf install --interactive

Step 1: Choose deployment topology
  [1] reality-only (no domain required)
  [2] vision-reality (requires domain, auto cert)
  > 1

Step 2: Choose Xray version
  [1] latest (recommended)
  [2] v1.8.1
  [3] other (specify version)
  > 1

Step 3: Enable plugins
  Available: cert-auto, firewall, logrotate-obs
  Enable? [cert-auto,firewall]: 
  
Summary:
  Topology: reality-only
  Xray: latest
  Plugins: cert-auto, firewall
  
Continue? [Y/n]: y
```

### npm - Initialization Wizard
**Example**: npm init
```
$ npm init
This utility will walk you through creating a package.json file.
It only covers the most common items, and tries to guess sensible defaults.

Press ^C at any time to quit.
package name: (myapp) my-awesome-app
version: (1.0.0) 0.1.0
description: My awesome application
...
Is this OK? (yes) yes
```

**Pattern to research**:
- Default values in parentheses
- Clear field descriptions
- Inline editing with defaults
- Final confirmation

**Reference**: `npm init` interaction flow

**Application to xray-fusion**:
```
Configuration Review:
Topology: reality-only
Port: 443
Plugins: cert-auto

Proceed with installation? [y/N]: y
```

---

## 5. Pre-flight Check Patterns

### Docker - System Requirements
**Example**: Docker on unsupported OS
```
ERROR: Docker requires virtualization to be enabled
ERROR: CPU does not support required capabilities
```

**Pattern to research**:
- System capability detection
- Hardware requirement verification
- Feature availability checks
- Clear error with resolution

**Reference**: Docker initialization checks

**Application to xray-fusion**:
```
Pre-flight checks:
  ✓ OS: Linux
  ✓ Bash 4.0+
  ✓ curl available
  ✓ Disk space: 500MB+ ✓
  ✓ Network connectivity ✓
  ✗ unzip not found → install with: apt-get install unzip
  ⚠ systemd not detected (systemd timer sync will not work)

Ready to proceed? [y/N]:
```

### Ansible - Host Requirements
**Example**: Playbook validation
```
PLAY [all] *****
TASK [Gathering Facts] ****
ok: [host1]
failed: [host2] (unsupported OS)

FATAL ERROR! Host compatibility check failed.
See: https://docs.ansible.com/ansible/latest/user_guide/...
```

**Pattern to research**:
- Per-host validation
- Failure grouping
- Reference documentation
- Graceful degradation

**Reference**: Ansible task execution and error reporting

**Application to xray-fusion**:
```
Validating system...
  host: ✓
  architecture: ✓
  os: Linux ✓
  
Checking dependencies...
  curl: ✓
  unzip: ✗ (required)
  systemd: ⚠ (optional)
  
Would you like to install missing dependencies? [Y/n]: y
Installing: unzip...
✓ Installation complete
```

---

## 6. Help System Patterns

### Docker - Help with Examples
**Example**: Command help
```
$ docker run --help
Usage: docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

Run a command in a new container

Options:
  --detach, -d                     Run container in background
  --name string                    Assign a name to the container
  -e, --env list                   Set environment variables
  --port list                      Publish a port
  
Examples:
  $ docker run -d -p 80:80 nginx
  $ docker run -it ubuntu /bin/bash
  $ docker run --name myapp myimage:latest
```

**Pattern to research**:
- Option name with short flag
- Description and default
- Type information
- Real usage examples
- Related commands

**Reference**: `docker run --help` output

**Application to xray-fusion**:
```
$ xrf install --help
Install and configure Xray proxy server

Usage:
  xrf install [options]

Options:
  -t, --topology TOPOLOGY  Deployment topology
                            - reality-only: Single Reality protocol (recommended)
                            - vision-reality: Vision + Reality (requires domain)
  -d, --domain DOMAIN      Domain name for TLS certificates (vision-reality only)
  -v, --version VERSION    Xray version (default: latest)
  -p, --plugins PLUGINS    Comma-separated plugin list
  --dry-run               Show what will be installed without making changes

Examples:
  # Basic Reality-only installation
  $ xrf install --topology reality-only
  
  # Vision-Reality with automatic certificates
  $ xrf install --topology vision-reality --domain example.com --plugins cert-auto
  
  # Preview changes before installation
  $ xrf install --topology reality-only --dry-run

See also: xrf links, xrf status, xrf plugin
For more info: https://docs.example.com
```

---

## 7. Specific Implementation References

### Bash Spinner Implementation
**Research source**: Linux community spinner patterns

**Example structure**:
```bash
spinner() {
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  
  while :; do
    printf "\r%s " "${frames[i++ % ${#frames[@]}]}"
    sleep 0.1
  done
}
```

**Application to xray-fusion**:
```bash
# Show spinner during download
spin::start "Downloading Xray..."
curl -fsSL "${url}" -o "${tmp}/xray.zip"
spin::stop "✓ Downloaded"
```

### ASCII Table for Bash
**Research source**: Bash table generation libraries

**Pattern**:
- Column widths
- Border characters
- Alignment (left/right/center)
- Header separation

**Application to xray-fusion**:
```
┌─────────────────┬──────────────────┐
│ Configuration   │ Value            │
├─────────────────┼──────────────────┤
│ Topology        │ vision-reality   │
│ Domain          │ example.com      │
│ Ports (Vision)  │ 8443             │
│ Ports (Reality) │ 443              │
│ Plugins         │ cert-auto        │
└─────────────────┴──────────────────┘
```

### Colored Output in Bash
**Research source**: ANSI escape code standards

**Common patterns**:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

echo -e "${GREEN}✓ Success${NC}"
echo -e "${RED}✗ Failed${NC}"
echo -e "${YELLOW}⚠ Warning${NC}"
echo -e "${BLUE}ℹ Info${NC}"
```

**Application to xray-fusion**:
```bash
core::log_color() {
  local level="${1}" msg="${2}"
  case "${level}" in
    success) echo -e "${GREEN}✓${NC} ${msg}" ;;
    error) echo -e "${RED}✗${NC} ${msg}" ;;
    warn) echo -e "${YELLOW}⚠${NC} ${msg}" ;;
  esac
}
```

---

## Research Tasks Summary

### High Priority Research
1. **Docker error messages**: Study Docker's approach to "problem → next steps"
2. **Spinner implementations**: Find Bash spinner patterns
3. **Table formatting**: Research ASCII table generation for Bash
4. **Kubernetes help**: Analyze `kubectl explain` and help text structure

### Medium Priority Research
1. **Terraform plan/apply**: Study preview before apply pattern
2. **GitHub CLI fuzzy matching**: Understand did-you-mean implementation
3. **npm init**: Study interactive questionnaire UX
4. **Pre-flight checks**: Research system capability verification patterns

### Lower Priority Research
1. **Log file management**: Study log rotation and file output patterns
2. **Progress bars**: Research curl/wget style progress bars
3. **Colored output**: Study color standard libraries for Bash
4. **Timing information**: Research performance profiling output

---

## Tools & Libraries to Investigate

### Bash-Specific
- **ShellCheck**: For static analysis (already used)
- **bats-core**: For testing (already used)
- **shfmt**: For formatting (already used)
- **bartender**: Simple Bash argument parser
- **Colors.sh**: ANSI color library for Bash

### Cross-Platform
- **GNU getopt/getopts**: Parameter parsing
- **less**: Pager for long output
- **column**: Text column formatter
- **awk/sed**: Text processing

### Inspiration Projects
- **asdf**: Multi-language version manager (excellent help)
- **nvm**: Node version manager (interactive prompts)
- **rbenv**: Ruby version manager (clear documentation)
- **oh-my-zsh**: Shell framework (plugin discovery)

---

