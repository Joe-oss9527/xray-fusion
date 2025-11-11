#!/usr/bin/env bats
# Tests for lib/preview.sh - Installation preview and confirmation

# Setup test environment
setup() {
  # Load the module under test
  HERE="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/.." && pwd)"
  # shellcheck source=lib/core.sh
  . "${HERE}/lib/core.sh"
  core::init

  # shellcheck source=lib/defaults.sh
  . "${HERE}/lib/defaults.sh"
  # shellcheck source=lib/preview.sh
  . "${HERE}/lib/preview.sh"

  # Set up test variables
  export TOPOLOGY="reality-only"
  export VERSION="v1.8.8"
  export XRAY_DOMAIN=""
  export PLUGINS=""
  export XRF_JSON="false"
  export XRF_YES="false"
  export XRF_DRY_RUN="false"
}

# ============================================================================
# preview::show() Tests - Text Format
# ============================================================================

@test "preview::show - displays reality-only configuration in text format" {
  export TOPOLOGY="reality-only"
  export VERSION="v1.8.8"
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Installation Preview" ]]
  [[ "$output" =~ "Topology:    reality-only" ]]
  [[ "$output" =~ "Xray:        v1.8.8" ]]
  [[ "$output" =~ "Ports:       443 (Reality)" ]]
  [[ "$output" =~ "Plugins:     none" ]]
}

@test "preview::show - displays vision-reality configuration in text format" {
  export TOPOLOGY="vision-reality"
  export VERSION="latest"
  export XRAY_DOMAIN="vpn.example.com"
  export PLUGINS="cert-auto,firewall"
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Installation Preview" ]]
  [[ "$output" =~ "Topology:    vision-reality" ]]
  [[ "$output" =~ "Xray:        latest" ]]
  [[ "$output" =~ "Domain:      vpn.example.com" ]]
  [[ "$output" =~ "Ports:       443 (Reality), 8443 (Vision), 8080 (Caddy)" ]]
  [[ "$output" =~ "Plugins:     cert-auto,firewall" ]]
}

@test "preview::show - does not show domain for reality-only" {
  export TOPOLOGY="reality-only"
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Domain:" ]]
}

@test "preview::show - shows domain for vision-reality" {
  export TOPOLOGY="vision-reality"
  export XRAY_DOMAIN="test.example.com"
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Domain:      test.example.com" ]]
}

@test "preview::show - uses custom ports when set" {
  export TOPOLOGY="reality-only"
  export XRAY_PORT="8443"
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Ports:       8443 (Reality)" ]]
}

@test "preview::show - uses default ports when not set" {
  export TOPOLOGY="vision-reality"
  export XRAY_DOMAIN="test.com"
  unset XRAY_VISION_PORT
  unset XRAY_REALITY_PORT
  unset XRAY_FALLBACK_PORT
  export XRF_JSON="false"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Ports:       443 (Reality), 8443 (Vision), 8080 (Caddy)" ]]
}

# ============================================================================
# preview::show() Tests - JSON Format
# ============================================================================

@test "preview::show - displays configuration in JSON format" {
  export TOPOLOGY="reality-only"
  export VERSION="v1.8.1"
  export XRF_JSON="true"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ '"preview"' ]]
  [[ "$output" =~ '"topology": "reality-only"' ]]
  [[ "$output" =~ '"version": "v1.8.1"' ]]
  [[ "$output" =~ '"ports": "443 (Reality)"' ]]
}

@test "preview::show - JSON format includes all fields" {
  export TOPOLOGY="vision-reality"
  export VERSION="latest"
  export XRAY_DOMAIN="vpn.test.com"
  export PLUGINS="cert-auto"
  export XRF_JSON="true"

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ '"topology": "vision-reality"' ]]
  [[ "$output" =~ '"version": "latest"' ]]
  [[ "$output" =~ '"domain": "vpn.test.com"' ]]
  [[ "$output" =~ '"plugins": "cert-auto"' ]]
  [[ "$output" =~ '"ports":' ]]
}

# ============================================================================
# preview::confirm() Tests
# ============================================================================

@test "preview::confirm - auto-confirms when XRF_YES=true" {
  export XRF_YES="true"

  run preview::confirm
  [ "$status" -eq 0 ]
}

@test "preview::confirm - auto-confirms in JSON mode" {
  export XRF_JSON="true"
  export XRF_YES="false"

  run preview::confirm
  [ "$status" -eq 0 ]
}

@test "preview::confirm - auto-confirms in non-interactive mode" {
  export XRF_YES="false"
  export XRF_JSON="false"

  # Simulate non-interactive mode (no stdin)
  run bash -c ". ${HERE}/lib/core.sh && core::init && . ${HERE}/lib/preview.sh && echo | preview::confirm"
  [ "$status" -eq 0 ]
}

# ============================================================================
# preview::is_dry_run() Tests
# ============================================================================

@test "preview::is_dry_run - returns 0 when XRF_DRY_RUN=true" {
  export XRF_DRY_RUN="true"

  run preview::is_dry_run
  [ "$status" -eq 0 ]
}

@test "preview::is_dry_run - returns 1 when XRF_DRY_RUN=false" {
  export XRF_DRY_RUN="false"

  run preview::is_dry_run
  [ "$status" -eq 1 ]
}

@test "preview::is_dry_run - returns 1 when XRF_DRY_RUN unset" {
  unset XRF_DRY_RUN

  run preview::is_dry_run
  [ "$status" -eq 1 ]
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "preview module can be sourced without errors" {
  # Already sourced in setup, this tests that it loaded correctly
  [ "$(type -t preview::show)" = "function" ]
  [ "$(type -t preview::confirm)" = "function" ]
  [ "$(type -t preview::is_dry_run)" = "function" ]
}

@test "preview::show works with minimal configuration" {
  export TOPOLOGY="reality-only"
  export VERSION="latest"
  export XRF_JSON="false"
  unset PLUGINS
  unset XRAY_DOMAIN

  run preview::show
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Installation Preview" ]]
}

@test "preview functions handle empty/unset variables gracefully" {
  # Use empty strings instead of unset (preview expects these to be set by args::parse)
  export TOPOLOGY=""
  export VERSION=""
  export PLUGINS=""
  export XRAY_DOMAIN=""
  export XRF_JSON="false"

  # Should not crash even with empty variables (though they may show as blank)
  run preview::show
  [ "$status" -eq 0 ]
}
