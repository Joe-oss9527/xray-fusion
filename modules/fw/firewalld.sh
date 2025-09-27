#!/usr/bin/env bash
fw_firewalld::is_available(){ command -v firewall-cmd >/dev/null 2>&1; }
fw_firewalld::open(){ local rule="${1}"; sudo firewall-cmd --permanent --add-port="${rule}" || true; sudo firewall-cmd --reload || true; }
fw_firewalld::close(){ local rule="${1}"; sudo firewall-cmd --permanent --remove-port="${rule}" || true; sudo firewall-cmd --reload || true; }
