#!/bin/bash
# shellcheck disable=SC1091
# Entrypoint script for turbo-cache service
set -euo pipefail

# Configuration
CONFIG_FILE="/etc/turbocache/config.toml"
TEMPLATE_FILE="/etc/turbocache/templates/turbo-cache-config.template"
DATA_DIR="${TURBO_CACHE_DATA_DIR:-/var/lib/turbocache}"
LOG_LEVEL="${TURBO_CACHE_LOG_LEVEL:-info}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] $*"
}

# Ensure data directory exists
setup_data_dir() {
    log "Setting up data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    chmod 755 "$DATA_DIR"
}

# Process configuration template
process_config() {
    log "Processing configuration template..."
    
    if [[ -f "$TEMPLATE_FILE" ]]; then
        # Use envsubst to substitute environment variables
        envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
        log "Configuration generated at $CONFIG_FILE"
        
        # Show config (excluding sensitive data)
        log "Configuration preview:"
        grep -v "api_key" "$CONFIG_FILE" || true
    else
        log "Template file not found: $TEMPLATE_FILE"
        log "Using default configuration"
    fi
}

# Validate configuration
validate_config() {
    log "Validating configuration..."
    
    # Check if data directory is writable
    if [[ ! -w "$DATA_DIR" ]]; then
        log "ERROR: Data directory is not writable: $DATA_DIR"
        exit 1
    fi
    
    # Check if port is valid
    if [[ ! "${TURBO_CACHE_PORT:-3654}" =~ ^[0-9]+$ ]]; then
        log "ERROR: Invalid port number: ${TURBO_CACHE_PORT:-3654}"
        exit 1
    fi
    
    log "Configuration validation passed"
}

# Start the service
start_service() {
    log "Starting turbo-cache service..."
    log "Host: ${TURBO_CACHE_HOST:-0.0.0.0}"
    log "Port: ${TURBO_CACHE_PORT:-3654}"
    log "Data Directory: $DATA_DIR"
    log "Log Level: $LOG_LEVEL"
    
    # Execute the turbo-cache-server with all arguments
    exec /usr/local/bin/turbo-cache-server "$@"
}

# Main execution
main() {
    log "Turbo Cache service starting..."
    
    # Setup
    setup_data_dir
    process_config
    validate_config
    
    # Start service
    start_service "$@"
}

# Handle signals gracefully
cleanup() {
    log "Received shutdown signal, cleaning up..."
    # Add any cleanup tasks here
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run main function with all arguments
main "$@"
