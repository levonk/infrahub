#!/bin/bash
# Microbin Health Check Script
# Performs comprehensive health checks for the service

set -euo pipefail

# Configuration
SERVICE_NAME="microbin"
SERVICE_PORT=""
HEALTH_ENDPOINT=""
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service is running
check_service_running() {
    if docker ps --format "table {{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        log_info "Service ${SERVICE_NAME} is running"
        return 0
    else
        log_error "Service ${SERVICE_NAME} is not running"
        return 1
    fi
}

# Check service health via HTTP endpoint
check_http_health() {
    local url="http://localhost:${SERVICE_PORT}${HEALTH_ENDPOINT}"

    if curl -f --max-time $TIMEOUT --silent "$url" > /dev/null 2>&1; then
        log_info "HTTP health check passed"
        return 0
    else
        log_error "HTTP health check failed"
        return 1
    fi
}

# Check resource usage
check_resources() {
    local container_stats
    container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "^${SERVICE_NAME}")

    if [[ -n "$container_stats" ]]; then
        log_info "Resource usage: $container_stats"
        return 0
    else
        log_warn "Could not retrieve resource usage"
        return 1
    fi
}

# Main health check function
main() {
    log_info "Starting health check for ${SERVICE_NAME}"

    local failed_checks=0

    if ! check_service_running; then
        ((failed_checks++))
    fi

    if ! check_http_health; then
        ((failed_checks++))
    fi

    if ! check_resources; then
        # Resource check failure is not critical
        log_warn "Resource check failed, but continuing"
    fi

    if [[ $failed_checks -eq 0 ]]; then
        log_info "All health checks passed"
        exit 0
    else
        log_error "$failed_checks health check(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"
