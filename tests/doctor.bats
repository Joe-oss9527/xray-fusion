#!/usr/bin/env bats

@test "doctor outputs json with keys" {
  run bash -lc 'XRF_JSON=true bin/xrf doctor --ports 80,443'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"os"'* ]]
  [[ "$output" == *'"pkg_manager"'* ]]
  [[ "$output" == *'"init"'* ]]
  [[ "$output" == *'"firewall"'* ]]
  [[ "$output" == *'"ports"'* ]]
}
