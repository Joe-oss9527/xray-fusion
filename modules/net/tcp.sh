#!/usr/bin/env bash
net::is_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | awk '{print $4}' | grep -E "(^|[.:])${port}($|[[:space:]])" >/dev/null 2>&1 && return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null | grep -E "(^|[.:])${port}($|[[:space:]])" >/dev/null 2>&1 && return 0
  fi
  return 1
}
