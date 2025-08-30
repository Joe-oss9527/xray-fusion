#!/usr/bin/env bats

setup() {
  export XRF_DRY_RUN=true
  export XRF_PREFIX="/tmp/xrf/usr/local"
  export XRF_ETC="/tmp/xrf/usr/local/etc"
  export XRF_VAR="/tmp/xrf/var/lib/xray-fusion"
  mkdir -p "$XRF_PREFIX/bin" "$XRF_ETC" "$XRF_VAR"
}

teardown() {
  rm -rf /tmp/xrf || true
}

@test "xrf install (dry-run) completes" {
  run bash -lc 'bin/xrf install --version v1.8.0 --topology reality-only'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan install Xray"* ]]
}

@test "configure renders JSON (dry-run preview)" {
  run bash -lc 'XRF_DRY_RUN=true XRAY_UUID=11111111-1111-1111-1111-111111111111 bin/xrf install --version v1.8.0'
  [ "$status" -eq 0 ]
}
