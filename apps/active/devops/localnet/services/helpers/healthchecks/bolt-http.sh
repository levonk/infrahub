#!/usr/bin/env sh
set -eu

TARGET="${1:-}"

if [ -z "${TARGET}" ]; then
  echo "usage: bolt-http.sh <bolt://host:port|http(s)://host/path>" >&2
  exit 2
fi

log() {
  printf "%s\n" "$1" >&2
}

curl_probe() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" >/dev/null
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$1" >/dev/null
    return 0
  fi

  log "neither curl nor wget is available for HTTP probe"
  return 1
}

bolt_probe_python() {
  python3 - "$1" "$2" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])

with socket.create_connection((host, port), timeout=5) as sock:
    sock.sendall(b"\x60\x60\xB0\x17\x00\x00\x00\x01")  # BOLT handshake marker
PY
}

bolt_probe_nc() {
  nc -z "$1" "$2"
}

bolt_probe_bash() {
  /bin/bash -c "exec 3<>/dev/tcp/$1/$2" >/dev/null 2>&1
}

case "$TARGET" in
  http://*|https://*)
    curl_probe "$TARGET"
    ;;
  bolt://*)
    HOSTPORT="${TARGET#bolt://}"
    HOST="${HOSTPORT%%:*}"
    PORT="${HOSTPORT##*:}"

    if command -v python3 >/dev/null 2>&1; then
      bolt_probe_python "$HOST" "$PORT"
    elif command -v nc >/dev/null 2>&1; then
      bolt_probe_nc "$HOST" "$PORT"
    elif [ -x /bin/bash ]; then
      bolt_probe_bash "$HOST" "$PORT"
    else
      log "no supported client (python3, nc, bash) available for bolt probe"
      exit 3
    fi
    ;;
  *)
    log "unsupported target scheme: $TARGET"
    exit 2
    ;;
esac
