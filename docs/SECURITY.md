# SECURITY

- Shell strict mode: `set -euo pipefail` and `trap` on `ERR`
- Input validation: prefer whitelists and explicit parsing
- Atomic writes: render to temp, then `mv` same-filesystem
- Least privilege: create files/dirs with minimal perms; `sudo` only as fallback
- Secrets hygiene: private keys 600; logs avoid printing secrets by default
- Supply chain: download assets with checksums/signatures (TODO: add signatures)
