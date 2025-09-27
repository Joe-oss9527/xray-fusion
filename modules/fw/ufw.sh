#!/usr/bin/env bash
fw_ufw::is_available(){ command -v ufw >/dev/null 2>&1; }
fw_ufw::open(){ local rule="${1}"; sudo ufw allow "${rule}" || true; }
fw_ufw::close(){ local rule="${1}"; sudo ufw delete allow "${rule}" || true; }
