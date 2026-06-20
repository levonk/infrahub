#!/bin/bash
set -euo pipefail

# Get username from environment or default to ansible
USERNAME=${USERNAME:-ansible}

# Since we're already running as the target user (set in Dockerfile), just check Nix
# Verify Nix command exists
if ! command -v nix &> /dev/null; then
    echo "nix not found"
    exit 1
fi

exit 0
