#!/usr/bin/env bats

@test "reality-only topology emits JSON with name" {
  export XRAY_PORT=8443
  export XRAY_UUID="test-uuid-1234"
  export XRAY_REALITY_SNI="test.example.com"
  export XRAY_SHORT_ID="testshortid123"
  
  run bash -lc 'topologies/reality-only.sh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"reality-only"'* ]]
  [[ "$output" == *'"uuid":"test-uuid-1234"'* ]]
}

@test "vision-reality topology emits JSON with name" {
  export XRAY_VISION_PORT=443
  export XRAY_REALITY_PORT=8443
  export XRAY_UUID_VISION="test-uuid-vision"
  export XRAY_UUID_REALITY="test-uuid-reality"
  export XRAY_DOMAIN="example.com"
  export XRAY_REALITY_SNI="test.example.com"
  export XRAY_SHORT_ID="testshortid567"
  
  run bash -lc 'topologies/vision-reality.sh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"vision-reality"'* ]]
  [[ "$output" == *'"uuid_vision":"test-uuid-vision"'* ]]
  [[ "$output" == *'"uuid_reality":"test-uuid-reality"'* ]]
}
