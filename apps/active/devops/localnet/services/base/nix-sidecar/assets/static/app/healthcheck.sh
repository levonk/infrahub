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
if ! command -v nix-env > /dev/null 2>&1; then
    echo "❌ healthcheck: nix-env not in PATH (\$PATH)"
    exit 1
fi

# Basic check
nix-env --version > /dev/null || { echo "❌ healthcheck: nix-env execution failed"; exit 1; }

echo "✅ Nix is healthy"
exit 0
