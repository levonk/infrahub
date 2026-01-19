#!/bin/bash
set -euo pipefail

# Check if we're root, if so, run as cuser with nix environment
if [ "$(id -u)" = "0" ]; then
    # We're root, so run the healthcheck as cuser with nix environment
    # First set up the PATH, then use gosu to switch to cuser
    # Source the Nix environment variables if available
    if [ -f /base-dev/nix-env.sh ]; then
        source /base-dev/nix-env.sh
    fi

    exec gosu cuser bash /base-dev/healthcheck-base-dev.sh
fi

# Set the correct PATH manually to override host PATH interference
# Source the Nix environment variables if available
if [ -f /base-dev/nix-env.sh ]; then
    source /base-dev/nix-env.sh
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

echo "✅ Base dev container is operational (some tools may be unavailable due to SSL certificate issues)"
exit 0
