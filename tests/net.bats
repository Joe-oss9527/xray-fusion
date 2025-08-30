#!/usr/bin/env bats

@test "net::is_listening returns false on a high port likely unused" {
  run bash -lc '. modules/net/tcp.sh; net::is_listening 65535'
  [ "$status" -ne 0 ]
}
