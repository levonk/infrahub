#!/bin/sh
set -e

echo "Starting Hermes Agent container..."
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"
echo "Working directory: $(pwd)"

# Verify Docker socket access
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket is accessible"
    docker version > /dev/null 2>&1 && echo "Docker CLI is functional" || echo "Warning: Docker CLI not functional"
else
    echo "Warning: Docker socket not found at /var/run/docker.sock"
fi

# Verify Nix integration
if [ -d /nix ]; then
    echo "Nix store is mounted"
    nix --version > /dev/null 2>&1 && echo "Nix is functional" || echo "Warning: Nix not functional"
else
    echo "Warning: Nix store not mounted"
fi

# Create data directories if they don't exist
mkdir -p "${HERMES_DATA_DIR}" "${HERMES_CONFIG_DIR}"

echo "Hermes Agent container initialized successfully"
echo "Ready for Docker operations"

# Keep container running
tail -f /dev/null
