#!/bin/sh

# Entry point for conda-sidecar
# This script ensures conda is available on the shared volume

set -e

echo "Starting conda-sidecar entrypoint..."

# Check if conda is already initialized on the shared volume
if [ ! -f "/home/cuser/.conda/.initialized" ]; then
    echo "conda not found on shared volume, extracting from archive..."
    
    # Ensure the shared volume directory exists
    mkdir -p /home/cuser/.conda
    
    # Extract conda from archive if archive exists
    if [ -f "/conda-sidecar/tmp/conda-archive.tar.zstd" ]; then
        echo "Extracting conda archive to shared volume..."
        zstd -dc /conda-sidecar/tmp/conda-archive.tar.zstd | tar -xf - -C /home/cuser/.conda/
        echo "Archive extraction complete"
    else
        echo "No archive found, initializing empty conda installation..."
    fi
    
    # Create initialization marker
    touch /home/cuser/.conda/.initialized
    echo "conda initialization complete"
else
    echo "conda already available on shared volume"
fi

# Create cache directories if needed
mkdir -p /home/cuser/.cache/conda

# Ensure proper permissions
chown -R 1000:1000 /home/cuser/.conda 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.cache/conda 2>/dev/null || true

# Create symlinks for conda command if needed
if [ -f "/home/cuser/.conda/bin/conda" ] && [ ! -f "/usr/local/bin/conda" ]; then
    echo "Creating conda symlink..."
    mkdir -p /usr/local/bin
    ln -sf /home/cuser/.conda/bin/conda /usr/local/bin/conda || true
fi

# Test that conda is working
if command -v conda >/dev/null 2>&1; then
    echo "conda version: $(conda --version)"
else
    echo "WARNING: conda command not available in PATH"
fi

echo "conda-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
