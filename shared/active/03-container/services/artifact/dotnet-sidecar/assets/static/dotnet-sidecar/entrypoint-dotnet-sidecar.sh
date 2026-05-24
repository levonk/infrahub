#!/bin/sh

# Entry point for dotnet-sidecar
# This script extracts .NET SDK from archive if not already present

set -e

echo "Starting dotnet-sidecar entrypoint..."

# Check if .NET SDK is already extracted
if [ ! -f "/var/lib/dotnet/dotnet" ]; then
    echo ".NET SDK not found, extracting from archive..."

    # Ensure the target directory exists
    mkdir -p /var/lib/dotnet

    # Extract .NET SDK from archive if archive exists
    if [ -f "/dotnet-sidecar/tmp/dotnet-sdk-archive.tar.zstd" ]; then
        echo "Extracting .NET SDK archive..."
        zstd -dc /dotnet-sidecar/tmp/dotnet-sdk-archive.tar.zstd | tar -xf - -C /var/lib/dotnet/
        echo "Archive extraction complete"
    else
        echo "ERROR: .NET SDK archive not found at /dotnet-sidecar/tmp/dotnet-sdk-archive.tar.zstd"
        exit 1
    fi
else
    echo ".NET SDK already available"
fi

# Create symlink for dotnet command if it doesn't exist
if [ ! -f "/usr/local/bin/dotnet" ]; then
    echo "Creating dotnet symlink..."
    mkdir -p /usr/local/bin
    ln -sf /var/lib/dotnet/dotnet /usr/local/bin/dotnet
fi

# Test that dotnet is working
if command -v dotnet >/dev/null 2>&1; then
    echo "dotnet version: $(dotnet --version)"
else
    echo "ERROR: dotnet command not available"
    exit 1
fi

# Create cache directories for NuGet packages
mkdir -p "/home/${USERNAME:-cuser}/.nuget/packages"
mkdir -p "/home/${USERNAME:-cuser}/.cache/dotnet"

# Ensure proper permissions
chown -R 1000:1000 /home/cuser/.nuget 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.cache/dotnet 2>/dev/null || true

echo "dotnet-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
