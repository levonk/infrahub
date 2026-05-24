#!/bin/bash
# Test script for Nuxt Tweet Organizer service

set -euo pipefail

# Configuration
SERVICE_NAME="localnet-apps-nuxt-tweet-org"
HOST_PORT="${APPS_NUXT_TWEET_ORG_HOST_PORT:-3000}"
CONTAINER_PORT="${APPS_NUXT_TWEET_ORG_CONTAINER_PORT:-3000}"
SERVICE_IP="${APPS_NUXT_TWEET_ORG_IP:-172.20.255.71}"
HEALTH_URL="http://localhost:${HOST_PORT}"
TIMEOUT=300  # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [test]${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [test] ERROR:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [test] WARNING:${NC} $*"
}

# Function to check if container is running
check_container_running() {
    if docker ps --format "table {{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Function to check service health
check_service_health() {
    local response_code
    response_code=$(curl -f -s -o /dev/null -w "%{http_code}" --max-time 10 "$HEALTH_URL" || echo "000")
    
    case "$response_code" in
        200|201|204)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to wait for service to be ready
wait_for_service() {
    local elapsed=0
    log "Waiting for service to be ready..."
    
    while [ $elapsed -lt $TIMEOUT ]; do
        if check_service_health; then
            log "Service is ready and responding"
            return 0
        fi
        
        if ! check_container_running; then
            log_error "Container is not running"
            return 1
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    echo
    log_error "Service did not become ready within ${TIMEOUT} seconds"
    return 1
}

# Function to test pnpm integration
test_pnpm_integration() {
    log "Testing pnpm integration..."
    
    # Check if pnpm is installed in container
    if docker exec "$SERVICE_NAME" which pnpm > /dev/null 2>&1; then
        log "✓ pnpm is installed in container"
    else
        log_error "✗ pnpm is not installed in container"
        return 1
    fi
    
    # Check if pnpm cache is mounted
    if docker exec "$SERVICE_NAME" ls -la /home/cuser/.cache/pnpm > /dev/null 2>&1; then
        log "✓ pnpm cache directory is mounted"
    else
        log_warning "⚠ pnpm cache directory is not mounted"
    fi
    
    # Check that npm is NOT being used (verify pnpm lock file exists)
    if docker exec "$SERVICE_NAME" test -f /app/pnpm-lock.yaml; then
        log "✓ pnpm lock file exists"
    else
        log_warning "⚠ pnpm lock file not found"
    fi
    
    return 0
}

# Function to test service functionality
test_service_functionality() {
    log "Testing service functionality..."
    
    # Test basic HTTP response
    if curl -f -s "$HEALTH_URL" > /dev/null; then
        log "✓ Service responds to HTTP requests"
    else
        log_error "✗ Service does not respond to HTTP requests"
        return 1
    fi
    
    # Test that it's a Nuxt.js application
    local response_body
    response_body=$(curl -s "$HEALTH_URL" | head -20)
    if echo "$response_body" | grep -q -i "nuxt\|vue\|tweet"; then
        log "✓ Service appears to be a Nuxt.js application"
    else
        log_warning "⚠ Could not confirm Nuxt.js application"
    fi
    
    return 0
}

# Main test execution
main() {
    log "Starting tests for Nuxt Tweet Organizer service..."
    
    # Check if container is running
    if ! check_container_running; then
        log_error "Container $SERVICE_NAME is not running"
        exit 1
    fi
    
    log "✓ Container is running"
    
    # Wait for service to be ready
    if ! wait_for_service; then
        exit 1
    fi
    
    # Run tests
    local test_failed=0
    
    if ! test_pnpm_integration; then
        test_failed=1
    fi
    
    if ! test_service_functionality; then
        test_failed=1
    fi
    
    # Final result
    if [ $test_failed -eq 0 ]; then
        log "✓ All tests passed!"
        exit 0
    else
        log_error "✗ Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"
