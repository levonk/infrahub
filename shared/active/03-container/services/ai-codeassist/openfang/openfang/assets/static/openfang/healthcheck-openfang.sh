#!/bin/bash

# OpenFang Health Check Script
# This script checks if the OpenFang service is healthy and responding

set -euo pipefail

# Configuration
OPENFANG_HOST="${OPENFANG_HOST:-localhost}"
OPENFANG_PORT="${OPENFANG_PORT:-4200}"
HEALTH_CHECK_TIMEOUT="${OPENFANG_HEALTH_TIMEOUT:-10}"
OPENFANG_BIN=""

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to check if OpenFang process is running
check_process() {
    # Find OpenFang binary
    for path in /usr/local/bin/openfang /opt/openfang/bin/openfang /usr/bin/openfang; do
        if [ -x "$path" ]; then
            OPENFANG_BIN="$path"
            break
        fi
    done

    if [ -z "$OPENFANG_BIN" ]; then
        log "Error: OpenFang binary not found"
        return 1
    fi

    # Check if OpenFang process is running
    if pgrep -f "$OPENFANG_BIN" >/dev/null 2>&1; then
        log "OpenFang process is running"
        return 0
    else
        log "Error: OpenFang process is not running"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http() {
    # Try to access the health endpoint or main page
    local url="http://${OPENFANG_HOST}:${OPENFANG_PORT}/health"
    
    # First try the dedicated health endpoint
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s --max-time "$HEALTH_CHECK_TIMEOUT" "$url" >/dev/null 2>&1; then
            log "Health endpoint responded successfully"
            return 0
        fi
        
        # If health endpoint doesn't exist, try the main page
        url="http://${OPENFANG_HOST}:${OPENFANG_PORT}/"
        if curl -f -s --max-time "$HEALTH_CHECK_TIMEOUT" "$url" >/dev/null 2>&1; then
            log "Main page responded successfully"
            return 0
        fi
        
        log "Error: HTTP endpoints not responding"
        return 1
    elif command -v wget >/dev/null 2>&1; then
        # Fallback to wget
        if wget -q --timeout="$HEALTH_CHECK_TIMEOUT" --tries=1 "$url" -O /dev/null 2>&1; then
            log "Health endpoint responded successfully (wget)"
            return 0
        fi
        
        url="http://${OPENFANG_HOST}:${OPENFANG_PORT}/"
        if wget -q --timeout="$HEALTH_CHECK_TIMEOUT" --tries=1 "$url" -O /dev/null 2>&1; then
            log "Main page responded successfully (wget)"
            return 0
        fi
        
        log "Error: HTTP endpoints not responding (wget)"
        return 1
    else
        log "Warning: Neither curl nor wget available for HTTP health check"
        return 0  # Don't fail if HTTP tools aren't available
    fi
}

# Function to check data directory
check_data_dir() {
    local data_dir="${OPENFANG_DATA_DIR:-/data/openfang}"
    
    if [ -d "$data_dir" ]; then
        log "Data directory exists: $data_dir"
        
        # Check if directory is writable
        if [ -w "$data_dir" ]; then
            log "Data directory is writable"
            return 0
        else
            log "Warning: Data directory is not writable"
            return 1
        fi
    else
        log "Error: Data directory does not exist: $data_dir"
        return 1
    fi
}

# Function to check configuration
check_config() {
    local config_dir="${OPENFANG_CONFIG_DIR:-/config/openfang}"
    local config_file="$config_dir/config.toml"
    
    if [ -f "$config_file" ]; then
        log "Configuration file exists: $config_file"
        
        # Basic syntax check for TOML (if python is available)
        if command -v python3 >/dev/null 2>&1; then
            if python3 -c "import tomllib; tomllib.load(open('$config_file', 'rb'))" 2>/dev/null; then
                log "Configuration file syntax is valid"
                return 0
            else
                log "Warning: Configuration file syntax may be invalid"
                return 1
            fi
        else
            log "Warning: Python3 not available for TOML syntax check"
            return 0  # Don't fail if syntax checker isn't available
        fi
    else
        log "Warning: Configuration file does not exist: $config_file"
        return 1
    fi
}

# Function to check port connectivity
check_port() {
    if command -v nc >/dev/null 2>&1; then
        if nc -z "$OPENFANG_HOST" "$OPENFANG_PORT" 2>/dev/null; then
            log "Port $OPENFANG_PORT is accessible"
            return 0
        else
            log "Error: Port $OPENFANG_PORT is not accessible"
            return 1
        fi
    elif command -v telnet >/dev/null 2>&1; then
        # Fallback to telnet
        if timeout "$HEALTH_CHECK_TIMEOUT" telnet "$OPENFANG_HOST" "$OPENFANG_PORT" </dev/null >/dev/null 2>&1; then
            log "Port $OPENFANG_PORT is accessible (telnet)"
            return 0
        else
            log "Error: Port $OPENFANG_PORT is not accessible (telnet)"
            return 1
        fi
    else
        log "Warning: Neither nc nor telnet available for port check"
        return 0  # Don't fail if port tools aren't available
    fi
}

# Main health check logic
main() {
    local exit_code=0
    
    log "Starting OpenFang health check..."
    
    # Check process
    if ! check_process; then
        exit_code=1
    fi
    
    # Check port connectivity
    if ! check_port; then
        exit_code=1
    fi
    
    # Check HTTP endpoint
    if ! check_http; then
        exit_code=1
    fi
    
    # Check data directory
    if ! check_data_dir; then
        exit_code=1
    fi
    
    # Check configuration
    if ! check_config; then
        exit_code=1
    fi
    
    if [ $exit_code -eq 0 ]; then
        log "OpenFang health check passed"
    else
        log "OpenFang health check failed"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
