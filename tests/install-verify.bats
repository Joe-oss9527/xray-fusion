#!/usr/bin/env bats

setup() {
  export XRF_DRY_RUN=false
  export XRF_PREFIX="/tmp/xrf/usr/local"
  export XRF_ETC="/tmp/xrf/usr/local/etc"
  export XRF_VAR="/tmp/xrf/var/lib/xray-fusion"
  mkdir -p "$XRF_PREFIX/bin" "$XRF_ETC" "$XRF_VAR"
}

teardown() {
  rm -rf /tmp/xrf || true
}

@test "install fetch-only verifies SHA256 with override" {
  # create a fake zip and compute sha256
  tmpzip="$(mktemp /tmp/xrf/fake.XXXX.zip)"
  echo "HELLO" > /tmp/xrf/hello.txt
  (cd /tmp/xrf && zip -q "$tmpzip" hello.txt)
  sha="$(sha256sum "$tmpzip" | awk '{print $1}')"
  run bash -lc 'XRAY_URL="file://'"$tmpzip"'" XRAY_SHA256="'"$sha"'" XRAY_FETCH_ONLY=true services/xray/install.sh --version v0.0.0'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Verifying SHA256"* ]]
}
