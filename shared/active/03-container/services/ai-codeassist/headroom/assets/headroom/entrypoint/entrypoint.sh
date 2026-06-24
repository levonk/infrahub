#!/bin/bash
set -e

# Headroom proxy entrypoint script
# Starts the headroom proxy with configurable upstream proxy support

echo "Starting Headroom Proxy..."

# Default values
HEADROOM_PORT="${HEADROOM_PORT:-8787}"
HEADROOM_HOST="${HEADROOM_HOST:-0.0.0.0}"
HEADROOM_DATA_DIR="${HEADROOM_DATA_DIR:-/data}"
UPSTREAM_PROXY="${UPSTREAM_PROXY:-}"

# Create data directory if it doesn't exist
mkdir -p "${HEADROOM_DATA_DIR}"

# Configure upstream proxy if provided
if [ -n "$UPSTREAM_PROXY" ]; then
    echo "Configuring upstream proxy: ${UPSTREAM_PROXY}"
    export HTTP_PROXY="${UPSTREAM_PROXY}"
    export HTTPS_PROXY="${UPSTREAM_PROXY}"
    export http_proxy="${UPSTREAM_PROXY}"
    export https_proxy="${UPSTREAM_PROXY}"
fi

# Enable output shaping if requested
if [ "${HEADROOM_OUTPUT_SHAPER:-0}" = "1" ]; then
    echo "Enabling output token reduction"
    export HEADROOM_OUTPUT_SHAPER=1
fi

# Start headroom proxy
echo "Starting headroom proxy on ${HEADROOM_HOST}:${HEADROOM_PORT}"
exec headroom proxy \
    --port "${HEADROOM_PORT}" \
    --host "${HEADROOM_HOST}"