#!/usr/bin/env bats

@test "svc::detect returns a plausible init" {
  run bash -lc '. modules/svc/svc.sh; . modules/svc/systemd.sh; . modules/svc/openrc.sh; svc::detect'
  [ "$status" -ge 0 ]
  [[ "$output" == "systemd" || "$output" == "openrc" || "$output" == "unknown" ]]
}
