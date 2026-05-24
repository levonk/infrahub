#!/bin/bash
# Script to clean up stuck containers
set -e

echo "Force-removing any stuck containers..."
docker ps -a --filter "name=localnet-" --format '{{.Names}}' | xargs -r docker rm -f 2>/dev/null || true
docker ps -a --filter "name=localnet-" --format '{{.Names}}' | xargs -r docker rm -f 2>/dev/null || true
docker ps -a --filter "name=base-" --format '{{.Names}}' | xargs -r docker rm -f 2>/dev/null || true
