#!/usr/bin/env bats

setup() {
  export XRF_DRY_RUN=true
  export TMPDIR="${TMPDIR:-/tmp}"
}

@test "cert::exists false by default" {
  run bash -lc '. modules/cert/cert.sh; cert::exists /tmp/nonexistent-dir-xyz'
  [ "$status" -ne 0 ]
  [[ "$output" == *'"exists":false'* ]]
}

@test "cert::issue dry-run succeeds" {
  run bash -lc '. modules/cert/cert.sh; cert::issue example.com admin@example.com "$TMPDIR/certs-test"'
  [ "$status" -eq 0 ]
}


@test "cert::issue non-dry-run path with stub acme.sh" {
  export PATH="/tmp/xrf/fakebin:$PATH"
  mkdir -p /tmp/xrf/fakebin
  cat >/tmp/xrf/fakebin/acme.sh <<'EOS'
#!/usr/bin/env bash
# very small stub for CI: handle --issue/--install-cert/--renew
case "$1" in
  --register-account) exit 0 ;;
  --issue) exit 0 ;;
  --install-cert)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --fullchain-file) full="$2"; shift 2 ;;
        --key-file) key="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$full")"
    echo FAKEFULL > "$full"
    echo FAKEKEY > "$key"
    exit 0
    ;;
  --renew) exit 0 ;;
esac
EOS
  chmod +x /tmp/xrf/fakebin/acme.sh

  tmpd="$(mktemp -d)"
  run bash -lc ". modules/cert/cert.sh; XRF_DRY_RUN=false cert::issue example.com admin@example.com "$tmpd" && test -f "$tmpd/fullchain.pem" && test -f "$tmpd/privkey.pem""
  [ "$status" -eq 0 ]
}
