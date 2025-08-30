#!/usr/bin/env bats

@test "openrc unit includes supervise-daemon and ulimit" {
  run bash -lc 'grep -q supervise-daemon packaging/openrc/xray && grep -q ulimit packaging/openrc/xray'
  [ "$status" -eq 0 ]
}
