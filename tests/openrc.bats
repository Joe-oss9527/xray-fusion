#!/usr/bin/env bats

@test "openrc installer prints plan in dry-run" {
  run bash -lc 'XRF_DRY_RUN=true services/xray/openrc-unit.sh install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan OpenRC install"* ]]
}
