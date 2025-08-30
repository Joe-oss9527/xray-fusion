#!/usr/bin/env bats

@test "reality-only topology emits JSON with name" {
  run bash -lc 'topologies/reality-only.sh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"reality-only"'* ]]
}

@test "vision-reality topology emits JSON with name" {
  run bash -lc 'topologies/vision-reality.sh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"vision-reality"'* ]]
}
