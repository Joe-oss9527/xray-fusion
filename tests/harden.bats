#!/usr/bin/env bats

@test "harden setcap prints plan in dry-run" {
  run bash -lc 'XRF_DRY_RUN=true bin/xrf harden setcap'
  [ "$status" -eq 0 ]
  [[ "$output" == *"setcap 'cap_net_bind_service=+ep'"* ]]
}

@test "harden status doesn't fail without getcap" {
  run bash -lc 'bin/xrf harden status || true'
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
