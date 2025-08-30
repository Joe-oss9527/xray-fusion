#!/usr/bin/env bats

@test "pkg::detect returns a known manager or unknown" {
  run bash -lc '. modules/pkg/pkg.sh; pkg::detect'
  [ "$status" -ge 0 ]
  [[ "$output" == "apt" || "$output" == "dnf" || "$output" == "unknown" ]]
}
