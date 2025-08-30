#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=modules/cert/acme_sh.sh
. "$HERE/modules/cert/acme_sh.sh"

# Contract:
# cert::issue <domain> <email> <out_dir>
# cert::renew <domain> <out_dir>
# cert::exists <out_dir>  -> prints JSON {"exists":bool,"fullchain":"...", "privkey":"..."}

cert::issue() { acme_sh::issue "$@"; }
cert::renew() { acme_sh::renew "$@"; }
cert::exists(){ acme_sh::exists "$@"; }
