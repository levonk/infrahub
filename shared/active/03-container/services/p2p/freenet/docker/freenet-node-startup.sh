#!/bin/bash
# Freenet peer node startup script.
# Mirrors the upstream docker/freenet-node/freenet-node-startup.sh, with the
# WS API port overridable via WS_API_PORT (default 7509) and the data/config
# dirs under BASE_DIR (default /root/.cache/freenet).
set -euo pipefail

export RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
export RUST_LOG="${RUST_LOG:-info,freenet=debug,freenet-stdlib=debug,fdev=debug}"

BASE_DIR="${BASE_DIR:-/root/.cache/freenet}"
NODE_DIR="${BASE_DIR}/node"
WS_API_PORT="${WS_API_PORT:-7509}"

mkdir -p "${NODE_DIR}"

exec freenet network \
  --id "freenet-node-${HOSTNAME}" \
  --config-dir "${BASE_DIR}" \
  --data-dir "${NODE_DIR}" \
  --ws-api-port "${WS_API_PORT}" \
  --ws-api-address 0.0.0.0
