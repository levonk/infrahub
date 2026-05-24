#!/bin/bash
# Health check script for RustFS service
# Checks both S3 API and Console endpoints

set -euo pipefail

# Configuration
S3_API_PORT="${CLOUD_RUSTFS_CONTAINER_PORT:-9000}"
CONSOLE_PORT="${CLOUD_RUSTFS_CONSOLE_CONTAINER_PORT:-9001}"
TIMEOUT="${CLOUD_RUSTFS_HEALTH_TIMEOUT:-10}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [healthcheck] $*"
}

# Health check function
check_endpoint() {
    local port="$1"
    local path="$2"
    local url="http://127.0.0.1:${port}${path}"
    
    log "Checking endpoint: ${url}"
    
    if curl -f -s --max-time "${TIMEOUT}" "${url}" > /dev/null 2>&1; then
        log "✅ Endpoint ${url} is healthy"
        return 0
    else
        log "❌ Endpoint ${url} is unhealthy"
        return 1
    fi
}

# Main health check
main() {
    local failed=0
    
    log "Starting RustFS health check..."
    
    # Check S3 API health endpoint
    if ! check_endpoint "${S3_API_PORT}" "/health"; then
        failed=1
    fi
    
    # Check Console health endpoint
    if ! check_endpoint "${CONSOLE_PORT}" "/rustfs/console/health"; then
        failed=1
    fi
    
    # Check if RustFS process is running
    if ! pgrep -f "rustfs" > /dev/null 2>&1; then
        log "❌ RustFS process is not running"
        failed=1
    else
        log "✅ RustFS process is running"
    fi
    
    # Check data directory accessibility
    if [ ! -d "/data" ]; then
        log "❌ Data directory /data is not accessible"
        failed=1
    else
        log "✅ Data directory is accessible"
    fi
    
    # Check logs directory accessibility
    if [ ! -d "/app/logs" ]; then
        log "❌ Logs directory /app/logs is not accessible"
        failed=1
    else
        log "✅ Logs directory is accessible"
    fi
    
    # Final status
    if [ "${failed}" -eq 0 ]; then
        log "🟢 RustFS health check passed"
        exit 0
    else
        log "🔴 RustFS health check failed"
        exit 1
    fi
}

# Run main function
main "$@"
