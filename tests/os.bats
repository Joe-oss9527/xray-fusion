#!/usr/bin/env bats

@test "os::detect returns required keys" {
  run bash -lc '. lib/os.sh; os::detect'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id"'* ]]
  [[ "$output" == *'"version_id"'* ]]
  [[ "$output" == *'"arch"'* ]]
}
