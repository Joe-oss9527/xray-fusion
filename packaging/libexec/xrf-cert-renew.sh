#!/usr/bin/env sh
# xrf-cert-renew wrapper: run acme.sh --cron with sane PATH, then reload xray
set -eu
PATH="/usr/local/bin:/usr/bin:/bin:/root/.acme.sh:$PATH"
if command -v acme.sh >/dev/null 2>&1; then
  acme.sh --cron || true
elif [ -x "/root/.acme.sh/acme.sh" ]; then
  /root/.acme.sh/acme.sh --cron || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl reload xray || true
elif command -v rc-service >/dev/null 2>&1; then
  rc-service xray reload || rc-service xray restart || true
fi
