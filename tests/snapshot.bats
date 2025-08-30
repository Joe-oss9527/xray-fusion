#!/usr/bin/env bats

setup() {
  export XRF_VAR="/tmp/xrf/var/lib/xray-fusion"
  export XRF_ETC="/tmp/xrf/usr/local/etc"
  mkdir -p "$XRF_VAR" "$XRF_ETC/xray"
  echo '{"hello":"world"}' > "$XRF_ETC/xray/config.json"
  echo '{"topology":"reality-only"}' > "$XRF_VAR/state.json"
}

teardown() {
  rm -rf /tmp/xrf || true
}

@test "snapshot create then restore" {
  run bash -lc 'bin/xrf snapshot create t1'
  [ "$status" -eq 0 ]
  [ -f "/tmp/xrf/var/lib/xray-fusion/snapshots/t1/config.json" ]

  echo '{"hello":"changed"}' > "$XRF_ETC/xray/config.json"
  run bash -lc 'bin/xrf snapshot restore t1'
  [ "$status" -eq 0 ]
  run cat "$XRF_ETC/xray/config.json"
  [[ "$output" == *'"world"'* ]]
}
