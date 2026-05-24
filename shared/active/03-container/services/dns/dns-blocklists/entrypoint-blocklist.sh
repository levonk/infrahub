#!/bin/bash
set -e

echo "🔧 Blocklist Compiler Entrypoint"
echo "Fixing permissions for PUID=${PUID:-1000} PGID=${PGID:-1000}..."

# Ensure directories exist
mkdir -p /blocklists/sources /blocklists/compiled

# Fix permissions
chown -R "${PUID:-1000}:${PGID:-1000}" /blocklists

# Execute the passed command as the user
echo "Executing: $@"
exec gosu "${PUID:-1000}:${PGID:-1000}" "$@"
