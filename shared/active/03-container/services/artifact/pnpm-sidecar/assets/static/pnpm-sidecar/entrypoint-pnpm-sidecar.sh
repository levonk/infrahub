#!/bin/sh

# Entry point for pnpm-sidecar
# This script ensures pnpm store is available on the shared volume

set -e

echo "Starting pnpm-sidecar entrypoint..."

# Check if pnpm store is already initialized on the shared volume
if [ ! -f "/home/cuser/.local/share/pnpm/.initialized" ]; then
    echo "pnpm store not found on shared volume, extracting from archive..."
    
    # Ensure the shared volume directory exists
    mkdir -p /home/cuser/.local/share/pnpm
    
    # Extract pnpm store from archive if archive exists
    if [ -f "/pnpm-sidecar/tmp/pnpm-store-archive.tar.zstd" ]; then
        echo "Extracting pnpm store archive to shared volume..."
        zstd -dc /pnpm-sidecar/tmp/pnpm-store-archive.tar.zstd | tar -xf - -C /home/cuser/.local/share/pnpm/
        echo "Archive extraction complete"
    else
        echo "No archive found, initializing empty pnpm store..."
    fi
    
    # Create initialization marker
    touch /home/cuser/.local/share/pnpm/.initialized
    echo "pnpm store initialization complete"
else
    echo "pnpm store already available on shared volume"
fi

# Create cache directory if needed
mkdir -p /home/cuser/.cache/pnpm

# Ensure proper permissions
chown -R 1000:1000 /home/cuser/.local/share/pnpm 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.cache/pnpm 2>/dev/null || true

# Test that pnpm is working
if command -v pnpm >/dev/null 2>&1; then
    echo "pnpm version: $(pnpm --version)"
else
    echo "WARNING: pnpm command not available in PATH"
fi

echo "pnpm-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
