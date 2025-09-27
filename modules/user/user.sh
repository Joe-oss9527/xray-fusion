#!/usr/bin/env bash
user::ensure_system_user() {
  local u="${1:-xray}" g="${2:-xray}"
  getent group "${g}" > /dev/null 2>&1 || sudo groupadd --system "${g}" || true
  getent passwd "${u}" > /dev/null 2>&1 || sudo useradd --system --gid "${g}" --home-dir /var/lib/"${u}" --no-create-home --shell /usr/sbin/nologin "${u}" || true
}
