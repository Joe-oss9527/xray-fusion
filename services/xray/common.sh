#!/usr/bin/env bash
# Common Xray service functions shared across modules
# Provides path resolution and utility functions for Xray service management

set -euo pipefail

# Path resolution functions
xray::prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
xray::etc()    { echo "${XRF_ETC:-/usr/local/etc}"; }
xray::var()    { echo "${XRF_VAR:-/var/lib/xray-fusion}"; }
xray::confdir(){ echo "$(xray::etc)/xray"; }
xray::cfg()    { echo "$(xray::confdir)/config.json"; }
xray::bin()    { echo "$(xray::prefix)/bin/xray"; }