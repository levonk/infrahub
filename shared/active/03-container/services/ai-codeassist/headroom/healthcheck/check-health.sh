#!/bin/bash
# Health check script for headroom proxy

HEALTH_ENDPOINT="${HEADROOM_HEALTH_ENDPOINT:-/health}"
HEADROOM_PORT="${HEADROOM_PORT:-8787}"
HEADROOM_HOST="${HEADROOM_HOST:-localhost}"

# Try to curl the health endpoint
if curl -f -s "http://${HEADROOM_HOST}:${HEADROOM_PORT}${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
    echo "Headroom proxy is healthy"
    exit 0
else
    echo "Headroom proxy health check failed"
    exit 1
fi