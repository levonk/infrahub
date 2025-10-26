#!/bin/sh
set -e

# Ensure runtime directories exist; /run is ephemeral and recreated each start
mkdir -p /run/chrony /var/run/chrony /var/lib/chrony || true
# Best-effort perms without failing if restricted
chmod 755 /run/chrony /var/run/chrony 2>/dev/null || true
chmod 750 /var/lib/chrony 2>/dev/null || true

# Start chronyd as root so it can bind to low ports, then drop to 'chrony'
exec /usr/sbin/chronyd -u chrony "$@"
