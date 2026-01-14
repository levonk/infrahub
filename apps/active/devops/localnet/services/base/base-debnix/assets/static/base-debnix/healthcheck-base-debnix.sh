#!/bin/bash
set -euo pipefail

# Check if we're root, if so, run as cuser with nix environment
if [ "$(id -u)" = "0" ]; then
    # We're root, so run the healthcheck as cuser with nix environment
    # First set up the PATH, then use gosu to switch to cuser

    exec gosu cuser bash /base-debnix/healthcheck-base-debnix.sh
fi

# Verify Nix command exists
if ! command -v nix &> /dev/null; then
    echo "nix not found"
    exit 1
fi

exit 0
