#!/bin/sh
# tor Health Check Script
# Checks if the Tor SOCKS port is accessible.

set -e

# Configuration
SERVICE_NAME="tor"
SOCKS_PORT=${SOCKS_PORT:-9050}
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_socks_port() {
    log_info "Checking if SOCKS port $SOCKS_PORT is open..."
    if nc -z -w $TIMEOUT localhost $SOCKS_PORT;
    then
        log_info "Tor SOCKS port $SOCKS_PORT is accessible."
        return 0
    else
        log_error "Tor SOCKS port $SOCKS_PORT is not accessible."
        return 1
    fi
}

main() {
    log_info "Starting health check for ${SERVICE_NAME}"
    if check_socks_port; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
