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
trap handle_shutdown SIGTERM SIGINT

# Start OmniRoute
echo "Starting OmniRoute..."
exec node /app/dist/server.js "$@"
