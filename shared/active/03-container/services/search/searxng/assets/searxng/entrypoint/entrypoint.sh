#!/bin/sh
set -e

# SearXNG entrypoint script
# Starts SearXNG with proper configuration and proxy support

echo "Starting SearXNG..."

# Set default environment variables if not set
SEARXNG_BIND_ADDRESS="${SEARXNG_BIND_ADDRESS:-0.0.0.0}"
SEARXNG_PORT="${SEARXNG_PORT:-8080}"

# Configure proxy settings if NordVPN proxy is available
if [ -n "${HTTP_PROXY}" ]; then
    echo "Using HTTP proxy: ${HTTP_PROXY}"
    export http_proxy="${HTTP_PROXY}"
    export https_proxy="${HTTP_PROXY}"
fi

# Ensure configuration directory exists
mkdir -p /etc/searxng

# Start SearXNG using the official entrypoint
# The official image uses uwsgi or granian as the server
exec /usr/local/searxng/docker-entrypoint.sh