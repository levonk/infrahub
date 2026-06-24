#!/bin/bash
# SearXNG Health Check Script
# Verifies that SearXNG is responding correctly

set -e

HEALTH_URL="${HEALTH_URL:-http://localhost:8080/health}"
TIMEOUT="${TIMEOUT:-10}"

echo "Checking SearXNG health at ${HEALTH_URL}"

# Check if the health endpoint is accessible
if curl -f -s -o /dev/null -w "%{http_code}" --max-time "${TIMEOUT}" "${HEALTH_URL}" | grep -q "200"; then
    echo "✓ SearXNG is healthy"
    exit 0
else
    echo "✗ SearXNG health check failed"
    exit 1
fi