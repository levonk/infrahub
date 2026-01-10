#!/bin/bash
set -euo pipefail

# Check if nix is operational using modern commands
if ! command -v nix > /dev/null 2>&1; then
    echo "❌ nix not in PATH"
    exit 1
fi

# Check modern nix functionality
if ! nix --version > /dev/null 2>&1; then
    echo "❌ nix command failed"
    exit 1
fi

# Verify flake functionality works
if ! nix flake --help > /dev/null 2>&1; then
    echo "❌ nix flake functionality not available"
    exit 1
fi

# Test that we can access the base environment
if ! nix develop /app#default --command bash -c "which bash" > /dev/null 2>&1; then
    echo "❌ nix develop environment failed"
    exit 1
fi

echo "✅ Nix is healthy with modern flake support"
exit 0
