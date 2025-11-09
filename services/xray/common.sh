#!/usr/bin/env bash
# Common Xray paths
# NOTE: This file is sourced. Strict mode is set by core::init() from the calling script
xray::prefix() { echo "${XRF_PREFIX:-/usr/local}"; }
xray::etc() { echo "${XRF_ETC:-/usr/local/etc}"; }
xray::confbase() { echo "$(xray::etc)/xray"; }
xray::releases() { echo "$(xray::confbase)/releases"; }
xray::active() { echo "$(xray::confbase)/active"; }
xray::bin() { echo "$(xray::prefix)/bin/xray"; }
