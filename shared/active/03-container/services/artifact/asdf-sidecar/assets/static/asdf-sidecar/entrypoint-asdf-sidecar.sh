#!/bin/sh

# Entry point for asdf-sidecar
# This script ensures asdf is available on the shared volume

set -e

echo "Starting asdf-sidecar entrypoint..."

# Check if asdf is already initialized on the shared volume
if [ ! -f "/home/cuser/.asdf/.initialized" ]; then
    echo "asdf not found on shared volume, extracting from archive..."
    
    # Ensure the shared volume directory exists
    mkdir -p /home/cuser/.asdf
    
    # Extract asdf from archive if archive exists
    if [ -f "/asdf-sidecar/tmp/asdf-archive.tar.zstd" ]; then
        echo "Extracting asdf archive to shared volume..."
        zstd -dc /asdf-sidecar/tmp/asdf-archive.tar.zstd | tar -xf - -C /home/cuser/.asdf/
        echo "Archive extraction complete"
    else
        echo "No archive found, initializing empty asdf installation..."
    fi
    
    # Create initialization marker
    touch /home/cuser/.asdf/.initialized
    echo "asdf initialization complete"
else
    echo "asdf already available on shared volume"
fi

# Create cache directories if needed
mkdir -p /home/cuser/.cache/asdf

# Ensure proper permissions
chown -R 1000:1000 /home/cuser/.asdf 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.cache/asdf 2>/dev/null || true

# Create symlinks for asdf command if needed
if [ -f "/home/cuser/.asdf/bin/asdf" ] && [ ! -f "/usr/local/bin/asdf" ]; then
    echo "Creating asdf symlink..."
    mkdir -p /usr/local/bin
    ln -sf /home/cuser/.asdf/bin/asdf /usr/local/bin/asdf || true
fi

# Source asdf if available
if [ -f "/home/cuser/.asdf/asdf.sh" ]; then
    . /home/cuser/.asdf/asdf.sh 2>/dev/null || true
fi

# Test that asdf is working
if command -v asdf >/dev/null 2>&1; then
    echo "asdf version: $(asdf version)"
else
    echo "WARNING: asdf command not available in PATH"
fi

echo "asdf-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
