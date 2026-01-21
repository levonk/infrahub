#!/bin/sh
set -eu

# Note: Heavy integrity checks run via supercronic (nix store verify --all)
# This healthcheck only verifies basic operational readiness

# Ensure Nix binaries are in the PATH
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Source Nix environment if available
if [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi

# Check if nix is operational
if ! command -v nix > /dev/null 2>&1; then
    echo "❌ healthcheck: nix not in PATH (\$PATH)"
    exit 1
fi

# Core functionality check: verify nix develop works (this is the main purpose of nix-sidecar)
if [ -f /nix-sidecar/flake.nix ]; then
    echo "🔍 healthcheck: Testing nix develop functionality..."
    if ! nix develop /nix-sidecar --command echo "nix develop test successful" > /dev/null 2>&1; then
        echo "❌ healthcheck: nix develop failed - core functionality broken"
        exit 1
    fi
    echo "✅ healthcheck: nix develop is working"
else
    echo "❌ healthcheck: /nix-sidecar/flake.nix not found"
    exit 1
fi

# Check if supercronic is running (when container is running in scheduler mode)
if [ -f /nix-sidecar/supercronic.crond ]; then
    echo "🔍 healthcheck: Checking supercronic scheduler..."
    # Check if supercronic process is running
    if ! pgrep -f "supercronic" > /dev/null 2>&1; then
        echo "❌ healthcheck: supercronic scheduler not running"
        exit 1
    fi
    echo "✅ healthcheck: supercronic scheduler is running"
fi

# Basic nix version check as additional verification
nix --version > /dev/null || { echo "❌ healthcheck: nix --version failed"; exit 1; }

echo "✅ healthcheck: Nix sidecar is healthy"
exit 0
