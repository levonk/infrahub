#!/bin/sh

# Entry point for nx-sidecar
# This script ensures nx is installed and cache directory is ready
# Depends on pnpm-sidecar shared volume for pnpm tooling

set -e

echo "Starting nx-sidecar entrypoint..."

# Ensure pnpm is available from shared volume
if [ -d "/home/cuser/.local/share/pnpm" ]; then
    export PNPM_HOME="/home/cuser/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    echo "PNPM home set to: $PNPM_HOME"
else
    echo "WARNING: pnpm shared volume not mounted at /home/cuser/.local/share/pnpm"
    echo "NX installation may fail"
fi

# Install nx globally using pnpm if not already installed
if [ ! -f "/home/cuser/.local/share/pnpm/nx" ] && [ ! -f "/home/cuser/.local/share/pnpm/bin/nx" ]; then
    echo "Installing nx package via pnpm..."
    if command -v pnpm >/dev/null 2>&1; then
        pnpm add -g nx
        echo "nx installation complete"
    else
        echo "WARNING: pnpm not available, cannot install nx"
    fi
else
    echo "nx already installed via pnpm"
fi

# Create nx cache directory structure per spec: /var/cache/nx-cache/vANY/
# FHS-compliant layout: hashes/, terminalOutputs/, outputs/
if [ ! -f "/var/cache/nx-cache/.initialized" ]; then
    echo "Initializing nx cache directory structure..."
    mkdir -p /var/cache/nx-cache/vANY/hashes
    mkdir -p /var/cache/nx-cache/vANY/terminalOutputs
    mkdir -p /var/cache/nx-cache/vANY/outputs

    # Create initialization marker
    touch /var/cache/nx-cache/.initialized
    echo "nx cache directory structure initialized"
else
    echo "nx cache directory already initialized"
fi

# Ensure proper permissions on cache directory
chown -R 1000:1000 /var/cache/nx-cache 2>/dev/null || true

# Test that nx is working
if command -v nx >/dev/null 2>&1; then
    echo "nx version: $(nx --version 2>/dev/null || echo 'unknown')"
else
    echo "WARNING: nx command not available in PATH"
fi

echo "nx-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
