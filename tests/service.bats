#!/usr/bin/env bats

@test "service setup prints plan in dry-run" {
  run bash -lc 'XRF_DRY_RUN=true bin/xrf service setup'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan systemd unit install"* ]]
}
