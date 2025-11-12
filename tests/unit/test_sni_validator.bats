#!/usr/bin/env bats
# Tests for lib/sni_validator.sh - SNI domain validation

# Setup test environment
setup() {
  # Load the module under test
  HERE="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/.." && pwd)"
  # shellcheck source=lib/core.sh
  . "${HERE}/lib/core.sh"
  core::init

  # shellcheck source=lib/sni_validator.sh
  . "${HERE}/lib/sni_validator.sh"

  # Set up test variables
  export XRF_JSON="false"
  export XRF_DEBUG="false"
}

# ============================================================================
# sni::check_tls13() Tests
# ============================================================================

@test "sni::check_tls13 - requires domain parameter" {
  run sni::check_tls13 ""
  [ "$status" -ne 0 ]
}

@test "sni::check_tls13 - accepts domain parameter" {
  # This test may fail in CI without network, so we skip it
  skip "requires network access"

  run sni::check_tls13 "www.cloudflare.com"
  # Status may be 0 or 1 depending on network/TLS support
  # Just verify it doesn't crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sni::check_tls13 - accepts custom port parameter" {
  # This test may fail in CI without network, so we skip it
  skip "requires network access"

  run sni::check_tls13 "www.cloudflare.com" 443
  # Just verify it doesn't crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sni::check_tls13 - uses default port 443" {
  # Verify function signature accepts single argument
  # This tests parameter handling without network dependency
  run bash -c ". ${HERE}/lib/core.sh && core::init && . ${HERE}/lib/sni_validator.sh && declare -f sni::check_tls13"
  [ "$status" -eq 0 ]
  [[ "$output" =~ 'local port="${2:-443}"' ]]
}

# ============================================================================
# sni::check_http2() Tests
# ============================================================================

@test "sni::check_http2 - requires domain parameter" {
  run sni::check_http2 ""
  [ "$status" -ne 0 ]
}

@test "sni::check_http2 - handles missing curl gracefully" {
  # Temporarily hide curl (if it exists)
  local old_path="${PATH}"
  export PATH="/nonexistent"

  run sni::check_http2 "example.com"
  [ "$status" -eq 1 ]

  export PATH="${old_path}"
}

@test "sni::check_http2 - accepts domain parameter" {
  skip "requires network access and curl"

  run sni::check_http2 "www.cloudflare.com"
  # Just verify it doesn't crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# sni::check_redirect() Tests
# ============================================================================

@test "sni::check_redirect - requires domain parameter" {
  run sni::check_redirect ""
  [ "$status" -ne 0 ]
}

@test "sni::check_redirect - handles missing curl gracefully" {
  # Temporarily hide curl (if it exists)
  local old_path="${PATH}"
  export PATH="/nonexistent"

  run sni::check_redirect "example.com"
  [ "$status" -eq 1 ]

  export PATH="${old_path}"
}

@test "sni::check_redirect - accepts domain parameter" {
  skip "requires network access and curl"

  run sni::check_redirect "www.microsoft.com"
  # Just verify it doesn't crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# sni::validate() Tests - Text Format
# ============================================================================

@test "sni::validate - requires domain parameter" {
  run sni::validate ""
  [ "$status" -ne 0 ]
}

@test "sni::validate - displays text format output by default" {
  skip "requires network access"

  export XRF_JSON="false"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ "Testing SNI:" ]]
}

@test "sni::validate - text format shows all checks" {
  skip "requires network access"

  export XRF_JSON="false"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ "TLS 1.3" ]]
  [[ "$output" =~ "HTTP/2" ]]
  [[ "$output" =~ "redirect" ]]
}

@test "sni::validate - text format shows checkmark or cross" {
  skip "requires network access"

  export XRF_JSON="false"
  run sni::validate "www.cloudflare.com"
  # Should have either ✓ or ✗ symbols
  [[ "$output" =~ "✓" ]] || [[ "$output" =~ "✗" ]]
}

@test "sni::validate - text format shows suitability message" {
  skip "requires network access"

  export XRF_JSON="false"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ "suitable for REALITY" ]] || [[ "$output" =~ "has issues" ]]
}

# ============================================================================
# sni::validate() Tests - JSON Format
# ============================================================================

@test "sni::validate - displays JSON format output when XRF_JSON=true" {
  skip "requires network access"

  export XRF_JSON="true"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ '"domain"' ]]
  [[ "$output" =~ '"checks"' ]]
  [[ "$output" =~ '"passed"' ]]
}

@test "sni::validate - JSON format includes all check results" {
  skip "requires network access"

  export XRF_JSON="true"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ '"tls13"' ]]
  [[ "$output" =~ '"http2"' ]]
  [[ "$output" =~ '"no_redirect"' ]]
}

@test "sni::validate - JSON format shows true/false values" {
  skip "requires network access"

  export XRF_JSON="true"
  run sni::validate "www.cloudflare.com"
  [[ "$output" =~ "true" ]] || [[ "$output" =~ "false" ]]
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "sni_validator module can be sourced without errors" {
  # Already sourced in setup, this tests that it loaded correctly
  [ "$(type -t sni::check_tls13)" = "function" ]
  [ "$(type -t sni::check_http2)" = "function" ]
  [ "$(type -t sni::check_redirect)" = "function" ]
  [ "$(type -t sni::validate)" = "function" ]
}

@test "sni::validate uses default port 443 when not specified" {
  skip "requires network access"

  run sni::validate "www.cloudflare.com"
  # Should not crash when port is omitted
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sni::validate accepts custom port parameter" {
  skip "requires network access"

  run sni::validate "www.cloudflare.com" 443
  # Should not crash with explicit port
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "sni::check_tls13 handles timeout gracefully" {
  skip "requires network access to non-responsive host"

  # Use a non-routable IP to trigger timeout
  run timeout 15 sni::check_tls13 "192.0.2.1" 443
  # Should timeout and fail gracefully
  [ "$status" -eq 1 ] || [ "$status" -eq 124 ]
}

@test "sni::check_http2 handles connection errors gracefully" {
  skip "requires testing with invalid domain"

  # Use an invalid domain
  run sni::check_http2 "this-domain-should-not-exist-12345.invalid"
  [ "$status" -eq 1 ]
}

@test "sni::check_redirect handles connection errors gracefully" {
  skip "requires testing with invalid domain"

  # Use an invalid domain
  run sni::check_redirect "this-domain-should-not-exist-12345.invalid"
  [ "$status" -eq 1 ]
}
