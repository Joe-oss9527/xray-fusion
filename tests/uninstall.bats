#!/usr/bin/env bats

setup() {
  export XRF_DRY_RUN=true
  export XRF_PREFIX="/tmp/xrf/usr/local"
  export XRF_ETC="/tmp/xrf/usr/local/etc"
  export XRF_VAR="/tmp/xrf/var/lib/xray-fusion"
  mkdir -p "$XRF_PREFIX/bin" "$XRF_ETC/xray" "$XRF_VAR/snapshots/s1"
  touch "$XRF_PREFIX/bin/xray" "$XRF_ETC/xray/config.json" "$XRF_VAR/state.json"
}

teardown() {
  rm -rf /tmp/xrf || true
}

@test "uninstall dry-run prints plan" {
  run bash -lc 'bin/xrf uninstall --purge'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uninstall plan"* ]]
  [[ "$output" == *"rm -rf"* ]]
}
