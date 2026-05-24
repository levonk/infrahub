#!/bin/sh
set -e

# NX Sidecar Health Check
# Verifies nx cache directory structure and nx command availability

echo "Running nx-sidecar health check..."

# Verify nx cache directory structure exists
if [ ! -d "/var/cache/nx-cache/vANY/hashes" ]; then
    echo "NX cache hashes directory not found"
    exit 1
fi

if [ ! -d "/var/cache/nx-cache/vANY/outputs" ]; then
    echo "NX cache outputs directory not found"
    exit 1
fi

if [ ! -d "/var/cache/nx-cache/vANY/terminalOutputs" ]; then
    echo "NX cache terminalOutputs directory not found"
    exit 1
fi

# Verify nx command is available (installed via pnpm)
if ! command -v nx > /dev/null 2>&1; then
    echo "nx command not found in PATH"
    exit 1
fi

# Verify nx is responsive
if ! nx --version > /dev/null 2>&1; then
    echo "nx command not responsive"
    exit 1
fi

echo "nx-sidecar health check passed"
exit 0
