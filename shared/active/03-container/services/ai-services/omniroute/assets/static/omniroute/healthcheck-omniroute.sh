#!/bin/sh
set -e

# Healthcheck script for OmniRoute
# Checks if the API endpoint is responding

PORT="${AI_OMNIROUTE_CONTAINER_PORT:-20128}"

# Try to reach the health endpoint or models endpoint
if wget -qO- "http://localhost:${PORT}/v1/models" > /dev/null 2>&1; then
    exit 0
fi

# Fallback: check if port is open
if nc -z localhost "${PORT}"; then
    exit 0
fi

exit 1
