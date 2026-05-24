#!/bin/sh
# Health check script for 9Router service

set -e

# Health endpoint
HEALTH_URL="http://127.0.0.1:${PORT:-20128}/health"

# Perform health check
if wget --no-verbose --tries=1 --spider --timeout=5 "$HEALTH_URL" 2>/dev/null; then
    exit 0
else
    exit 1
fi
