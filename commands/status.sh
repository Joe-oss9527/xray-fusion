#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/core.sh"
. "$HERE/lib/os.sh"
. "$HERE/modules/state.sh"

HERE2="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=modules/pkg/pkg.sh
. "$HERE2/modules/pkg/pkg.sh"

main() {
  dc=$(pkg::detect || true); local os_json; os_json="$(os::detect)"
  if [[ "${XRF_JSON}" == "true" ]]; then
    printf '{"ok":true,"os":%s,"pkg_manager":"%s"}\n' "$os_json" "$dc"
  else
    core::log info "Platform" "$os_json"; core::log info "Pkg" "$(printf '{"manager":"%s"}' "$dc")"; core::log info "State" "$st"
  fi
}
main "$@"
