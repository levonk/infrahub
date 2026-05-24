#!/bin/bash
set -euo pipefail

# Check if mise directory exists
if [ ! -d "/root/.local/share/mise" ]; then
  echo "mise dir missing"
  exit 1
fi

# Validate mise installation and cache
if ! /usr/local/bin/mise doctor --quiet > /dev/null 2>&1; then
  echo "mise doctor failed"
  exit 1
fi

# Check cache directory is accessible
if ! /usr/local/bin/mise cache path > /dev/null 2>&1; then
  echo "mise cache path failed"
  exit 1
fi

echo "mise healthy"
exit 0
