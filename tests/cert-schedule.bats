#!/usr/bin/env bats

@test "cert schedule prints plan (systemd timer or cron)" {
  run bash -lc 'XRF_DRY_RUN=true bin/xrf cert schedule'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan systemd timer install"* || "$output" == *"Plan cron install"* ]]
}
