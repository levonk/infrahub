#!/bin/bash
# Startup script for LocalStack with automatic platform detection

set -e

# Detect Platform
if grep -qEi "(Microsoft|WSL)" /proc/version; then
    PLATFORM="wsl"
    echo "Detected WSL2/Windows environment."
    echo "Using dockerproxy-rw for Docker socket access."
else
    PLATFORM="linux"
    echo "Detected Linux environment."
    echo "Using Sysbox runtime for Docker socket access."
fi

COMPOSE_FILES="-f docker-compose.cloud.base.yml -f docker-compose.cloud.${PLATFORM}.yml"

echo "Starting LocalStack with configuration: ${COMPOSE_FILES}"
docker-compose ${COMPOSE_FILES} up -d

echo "LocalStack started."
