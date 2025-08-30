#!/usr/bin/env bats

setup() {
  export XRF_JSON=true
}

@test "core::log outputs json" {
  run bash -lc '. lib/core.sh; core::init; core::log info "hello" "{}"'
  [ "$status" -eq 0 ]
  [[ "$output" =~ \"level\":\"info\" ]] && [[ "$output" =~ \"msg\":\"hello\" ]]
}
