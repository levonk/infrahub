#!/bin/bash
# FastCode Service Entrypoint Script
# Handles initialization and permission dropping for FastCode container

set -euo pipefail

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Validate required environment variables
validate_env() {
    log "Validating environment variables..."
    
    # Check if required directories exist
    [[ -d "/app" ]] || error_exit "Application directory /app not found"
    
    # Create necessary directories if they don't exist
    mkdir -p /app/data /app/logs /app/repositories
    
    # Set proper ownership
    if [[ "${EUID}" -eq 0 ]]; then
        chown -R "${USERNAME}:${USERNAME}" /app/data /app/logs /app/repositories
    fi
    
    log "Environment validation completed"
}

# Initialize FastCode application
init_app() {
    log "Initializing FastCode application..."
    
    # Change to application directory
    cd /app
    
    # Verify Python environment
    python --version || error_exit "Python not available"
    
    # Check if required modules are available
    python -c "import fastapi" || error_exit "FastAPI not installed"
    python -c "import uvicorn" || error_exit "Uvicorn not installed"
    
    # Create logs directory structure
    mkdir -p logs
    
    log "FastCode application initialized"
}

# Drop privileges if running as root
drop_privileges() {
    if [[ "${EUID}" -eq 0 ]] && [[ -n "${USERNAME}" ]] && [[ -n "${PUID}" ]] && [[ -n "${PGID}" ]]; then
        log "Dropping privileges to ${USERNAME} (UID: ${PUID}, GID: ${PGID})"
        
        # Ensure user exists
        if ! id "${USERNAME}" &>/dev/null; then
            error_exit "User ${USERNAME} does not exist"
        fi
        
        # Set proper ownership of application directory
        chown -R "${USERNAME}:${USERNAME}" /app
        
        # Switch to non-root user
        exec gosu "${USERNAME}" "$@"
    else
        log "Running as current user (UID: ${EUID})"
        exec "$@"
    fi
}

# Health check function
health_check() {
    log "Performing health check..."
    
    # Check if FastCode web app is accessible
    if curl -f -s http://localhost:5000/health >/dev/null 2>&1; then
        log "Health check passed"
        return 0
    else
        log "Health check failed"
        return 1
    fi
}

# Signal handlers for graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    # Add any cleanup tasks here
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution flow
main() {
    log "Starting FastCode service entrypoint..."
    
    # Validate environment
    validate_env
    
    # Initialize application
    init_app
    
    # If health check is requested, run it and exit
    if [[ "${1:-}" == "healthcheck" ]]; then
        health_check
        exit $?
    fi
    
    # Drop privileges and start the application
    log "Starting FastCode web application..."
    drop_privileges "$@"
}

# Run main function with all arguments
main "$@"
