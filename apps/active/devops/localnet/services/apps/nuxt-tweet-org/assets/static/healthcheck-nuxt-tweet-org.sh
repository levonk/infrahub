#!/bin/bash
# Nuxt Tweet Organizer Health Check Script

set -euo pipefail

# Configuration
HEALTH_URL="http://localhost:${APPS_NUXT_TWEET_ORG_CONTAINER_PORT:-3000}"
TIMEOUT=10

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [healthcheck] $*"
}

# Check if the application is responding
check_health() {
    local response_code
    response_code=$(curl -f -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$HEALTH_URL" || echo "000")
    
    case "$response_code" in
        200|201|204)
            log "Health check passed (HTTP $response_code)"
            return 0
            ;;
        000)
            log "Health check failed: No response from $HEALTH_URL"
            return 1
            ;;
        *)
            log "Health check failed: HTTP $response_code from $HEALTH_URL"
            return 1
            ;;
    esac
}

# Main health check
if check_health; then
    exit 0
else
    exit 1
fi
