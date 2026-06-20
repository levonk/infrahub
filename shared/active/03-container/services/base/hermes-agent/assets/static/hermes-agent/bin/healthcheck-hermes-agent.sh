#!/bin/sh
set -e

echo "Running Hermes Agent health check..."

# Check if container process is running
if [ ! -f /proc/1/cmdline ]; then
    echo "ERROR: Container process not found"
    exit 1
fi

# Check Docker socket access
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket is accessible"
    docker ps > /dev/null 2>&1 || {
        echo "ERROR: Docker CLI not functional"
        exit 1
    }
    echo "Docker CLI is functional"
else
    echo "ERROR: Docker socket not found at /var/run/docker.sock"
    exit 1
fi

# Check Nix integration (optional warning)
if [ -d /nix ]; then
    nix --version > /dev/null 2>&1 && echo "Nix is functional" || echo "Warning: Nix not functional"
else
    echo "Warning: Nix store not mounted"
fi

# Check data directories
if [ ! -d "${HERMES_DATA_DIR}" ]; then
    echo "ERROR: Data directory not found: ${HERMES_DATA_DIR}"
    exit 1
fi

if [ ! -d "${HERMES_CONFIG_DIR}" ]; then
    echo "ERROR: Config directory not found: ${HERMES_CONFIG_DIR}"
    exit 1
fi

echo "Hermes Agent health check passed"
exit 0
