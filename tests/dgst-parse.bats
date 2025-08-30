#!/usr/bin/env bats

setup() {
  export TMPDIR="${TMPDIR:-/tmp}"
}

@test "verify::fetch_dgst_sha256 parses multiple formats" {
  tmpzip="$(mktemp ${TMPDIR}/fake.XXXX.zip)"
  echo "abc" > "$tmpzip"
  dgst="${tmpzip}.dgst"
  cat > "$dgst" <<EOF
SHA256=$(printf "abc" | sha256sum | awk '{print $1}')
SHA256 (fake.zip) = deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff  fake.zip
EOF
  run bash -lc '. modules/sec/verify.sh; verify::fetch_dgst_sha256 "file://'"$tmpzip"'"'
  [ "$status" -eq 0 ]
  # first line should be parsed; length 64
  [[ "${output//[$'\r\n']}" =~ ^[0-9a-f]{64}$ ]]
}
