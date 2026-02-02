#!/bin/bash
set -euo pipefail

if [ ! -d "/root/.local/share/devbox" ]; then
  echo "devbox dir missing"
  exit 1
fi
exit 0
