#!/bin/sh
set -e

# Entrypoint script for OmniRoute
# Handles graceful shutdown and proper signal handling

# Signal handler for graceful shutdown
handle_shutdown() {
    echo "Received shutdown signal, stopping gracefully..."
    # OmniRoute handles its own shutdown
    exit 0
}

# Register signal handlers
trap handle_shutdown TERM INT

# Start OmniRoute (passes through to base image CMD: node dev/run-standalone.mjs)
echo "Starting OmniRoute..."
exec "$@"
