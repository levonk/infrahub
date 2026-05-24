#!/bin/bash
set -euo pipefail

# HAPI Server Health Check
# This script checks the HAPI server functionality and basic system health

# Check if HAPI server process is running
if ! pgrep -f "hapi server" > /dev/null; then
    echo "HAPI server process not found"
    exit 1
fi

# Check if HAPI server is responding on the expected port
LISTEN_PORT=${HAPI_LISTEN_PORT:-3006}
LISTEN_HOST=${HAPI_LISTEN_HOST:-0.0.0.0}

if ! curl -f -s "http://localhost:${LISTEN_PORT}/health" > /dev/null 2>&1; then
    echo "HAPI server health endpoint not responding"
    exit 1
fi

# Check Node.js is available (required for HAPI)
if ! command -v node &> /dev/null; then
    echo "Node.js not found"
    exit 1
fi

# Check HAPI CLI is available
if ! command -v hapi &> /dev/null; then
    echo "HAPI CLI not found"
    exit 1
fi

# Verify data directory exists and is accessible
HAPI_HOME=${HAPI_HOME:-/root/.hapi}
if [ ! -d "${HAPI_HOME}" ]; then
    echo "HAPI data directory ${HAPI_HOME} not found"
    exit 1
fi

# Check if we can write to data directory
if ! touch "${HAPI_HOME}/.healthcheck" 2>/dev/null; then
    echo "Cannot write to HAPI data directory"
    exit 1
fi
rm -f "${HAPI_HOME}/.healthcheck"

# Check system resources
if [ "$(df / | awk 'NR==2 {print $5}' | sed 's/%//')" -gt 90 ]; then
    echo "Warning: Root filesystem usage above 90%"
fi

echo "✅ HAPI server is healthy and operational"
exit 0
