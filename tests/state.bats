#!/usr/bin/env bats

setup() {
  export XRF_VAR="/tmp/xrf/var/lib/xray-fusion"
  mkdir -p "$XRF_VAR"
}

teardown() {
  rm -rf /tmp/xrf || true
}

@test "state::save and state::load roundtrip" {
  run bash -lc '. modules/state.sh; state::save "{\"a\":1}"; state::load'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"a":1'* ]]
}
