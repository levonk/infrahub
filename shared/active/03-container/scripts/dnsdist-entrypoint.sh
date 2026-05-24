#!/bin/bash
set -e

echo "Waiting for upstream DNS services to be resolvable..."

# Wait for coredns to be resolvable
until getent hosts coredns > /dev/null 2>&1; do
    echo "Waiting for coredns hostname to resolve..."
    sleep 2
done
echo "✓ coredns is resolvable"

# Wait for dnscrypt-proxy to be resolvable
until getent hosts dnscrypt-proxy > /dev/null 2>&1; do
    echo "Waiting for dnscrypt-proxy hostname to resolve..."
    sleep 2
done
echo "✓ dnscrypt-proxy is resolvable"

echo "All upstream services are resolvable. Starting dnsdist..."
exec dnsdist --config=/etc/dnsdist/dnsdist.conf
