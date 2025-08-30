#!/usr/bin/env bats

@test "fw::detect returns plausible value" {
  run bash -lc '. modules/fw/fw.sh; fw::detect'
  [ "$status" -ge 0 ]
  [[ "$output" == "ufw" || "$output" == "firewalld" || "$output" == "none" ]]
}
