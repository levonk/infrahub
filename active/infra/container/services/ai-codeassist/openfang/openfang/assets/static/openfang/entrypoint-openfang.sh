#!/bin/bash

# OpenFang Service Entrypoint Script
# This script initializes and starts the OpenFang Agent Operating System

set -euo pipefail

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to handle signals
cleanup() {
    log "Received shutdown signal, stopping OpenFang..."
    if [ -n "${OPENFANG_PID:-}" ]; then
        kill "$OPENFANG_PID" 2>/dev/null || true
        wait "$OPENFANG_PID" 2>/dev/null || true
    fi
    log "OpenFang stopped"
    exit 0
}

# Set signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Ensure we're running as the correct user
if [ "$(id -u)" != "${PUID:-1000}" ]; then
    log "Warning: Running as user $(id -u), expected PUID=${PUID:-1000}"
fi

# Create directories if they don't exist
mkdir -p "${OPENFANG_DATA_DIR:-/data/openfang}"
mkdir -p "${OPENFANG_CONFIG_DIR:-/config/openfang}"
mkdir -p "${HOME}/.local/share/openfang"

# Set proper permissions
chown -R "$(id -u):$(id -g)" "${OPENFANG_DATA_DIR:-/data/openfang}" "${OPENFANG_CONFIG_DIR:-/config/openfang}" "${HOME}/.local/share/openfang" 2>/dev/null || true

# Initialize OpenFang if not already initialized
if [ ! -f "${OPENFANG_CONFIG_DIR:-/config/openfang}/config.toml" ]; then
    log "Initializing OpenFang..."
    
    # Run openfang init if available
    if command -v openfang >/dev/null 2>&1; then
        openfang init --data-dir="${OPENFANG_DATA_DIR:-/data/openfang}" --config-dir="${OPENFANG_CONFIG_DIR:-/config/openfang}" || {
            log "Warning: OpenFang init failed, continuing with defaults"
        }
    else
        log "Warning: OpenFang binary not found, attempting to locate..."
        # Try common locations
        OPENFANG_BIN=""
        for path in /usr/local/bin/openfang /opt/openfang/bin/openfang /usr/bin/openfang; do
            if [ -x "$path" ]; then
                OPENFANG_BIN="$path"
                break
            fi
        done
        
        if [ -n "$OPENFANG_BIN" ]; then
            log "Found OpenFang at: $OPENFANG_BIN"
            "$OPENFANG_BIN" init --data-dir="${OPENFANG_DATA_DIR:-/data/openfang}" --config-dir="${OPENFANG_CONFIG_DIR:-/config/openfang}" || {
                log "Warning: OpenFang init failed, continuing with defaults"
            }
        else
            log "Error: OpenFang binary not found in expected locations"
            exit 1
        fi
    fi
fi

# Configure OpenFang settings
cat > "${OPENFANG_CONFIG_DIR:-/config/openfang}/config.toml" << EOF
[server]
host = "0.0.0.0"
port = 4200
data_dir = "${OPENFANG_DATA_DIR:-/data/openfang}"
config_dir = "${OPENFANG_CONFIG_DIR:-/config/openfang}"

[logging]
level = "info"
file = "${OPENFANG_DATA_DIR:-/data/openfang}/openfang.log"

[security]
enable_auth = ${OPENFANG_ENABLE_AUTH:-false}
api_key = "${OPENFANG_API_KEY:-}"

[agents]
max_concurrent = ${OPENFANG_MAX_AGENTS:-10}
default_timeout = ${OPENFANG_AGENT_TIMEOUT:-300}
EOF

# Set environment variables for OpenFang
export OPENFANG_DATA_DIR="${OPENFANG_DATA_DIR:-/data/openfang}"
export OPENFANG_CONFIG_DIR="${OPENFANG_CONFIG_DIR:-/config/openfang}"
export OPENFANG_LOG_FILE="${OPENFANG_DATA_DIR:-/data/openfang}/openfang.log"

# Find the OpenFang binary
OPENFANG_BIN=""
for path in /usr/local/bin/openfang /opt/openfang/bin/openfang /usr/bin/openfang; do
    if [ -x "$path" ]; then
        OPENFANG_BIN="$path"
        break
    fi
done

if [ -z "$OPENFANG_BIN" ]; then
    log "Error: OpenFang binary not found"
    exit 1
fi

log "Starting OpenFang Agent Operating System..."
log "Binary: $OPENFANG_BIN"
log "Data directory: ${OPENFANG_DATA_DIR:-/data/openfang}"
log "Config directory: ${OPENFANG_CONFIG_DIR:-/config/openfang}"
log "Web interface will be available at http://localhost:4200"

# Start OpenFang in the background
exec "$OPENFANG_BIN" start --data-dir="${OPENFANG_DATA_DIR:-/data/openfang}" --config-dir="${OPENFANG_CONFIG_DIR:-/config/openfang}" &

# Store the PID for cleanup
OPENFANG_PID=$!

# Wait for OpenFang to start
sleep 5

# Check if OpenFang is still running
if ! kill -0 "$OPENFANG_PID" 2>/dev/null; then
    log "Error: OpenFang failed to start"
    exit 1
fi

log "OpenFang started successfully (PID: $OPENFANG_PID)"

# Wait for the process to finish
wait "$OPENFANG_PID"
