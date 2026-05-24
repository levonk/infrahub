#!/bin/bash
set -euo pipefail

# HAPI Client Health Check
# This script checks both the base-dev environment and HAPI-specific functionality

# Check if we're root, if so, run as cuser with nix environment
if [ "$(id -u)" = "0" ]; then
    # We're root, so run the healthcheck as cuser with nix environment
    # First set up the PATH, then use gosu to switch to cuser
    # Source the Nix environment variables if available
    if [ -f /hapi-client/nix-env.sh ]; then
        source /hapi-client/nix-env.sh
    fi

    exec gosu cuser bash /hapi-client/healthcheck-hapi-client.sh
fi

# Set the correct PATH manually to override host PATH interference
# Ensure Nix binaries are in the PATH, searching multiple profile locations
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/home/cuser/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Source the Nix environment variables if available
if [ -f /home/cuser/.nix-profile/etc/profile.d/nix.sh ]; then
    source /home/cuser/.nix-profile/etc/profile.d/nix.sh
fi

# Verify Nix command exists
if ! command -v nix &> /dev/null; then
    echo "nix not found"
    exit 1
fi

# Verify essential development tools
if ! git --version &> /dev/null; then
    echo "git not found"
    exit 1
fi

# Check HAPI CLI availability
if ! command -v hapi &> /dev/null; then
    echo "hapi CLI not found"
    exit 1
fi

# Check if HAPI server is reachable (if configured)
if [ -n "${HAPI_API_URL:-}" ]; then
    if ! curl -f -s "${HAPI_API_URL}/health" > /dev/null 2>&1; then
        echo "HAPI server at ${HAPI_API_URL} is not reachable"
        exit 1
    fi
    echo "✅ HAPI server is reachable"
fi

# Node.js may not be available due to SSL certificate issues
# Check if it's available, but don't fail if it's not
if ! node --version &> /dev/null; then
    echo "⚠️ node not found (may be due to SSL certificate issues)"
fi

# Verify fzf functionality
if ! fzf --version &> /dev/null; then
    echo "⚠️ fzf not found (may be due to SSL certificate issues)"
fi

# Basic responsiveness check
if ! jq --version &> /dev/null; then
    echo "⚠️ jq not responsive (may be due to SSL certificate issues)"
fi

echo "✅ HAPI client container is operational"
exit 0
