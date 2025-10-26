#!/usr/bin/env sh
# CoreDNS entrypoint script
# Expands environment variables in Corefile template and starts CoreDNS

set -euo pipefail

# Source file (template with env var placeholders)
TEMPLATE_FILE="/etc/coredns/Corefile.template"
# Destination file (expanded config)
CONFIG_FILE="/etc/coredns/Corefile"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Corefile template not found at $TEMPLATE_FILE" >&2
  exit 1
fi

# Set default values for environment variables if not already set
export COREDNS_DNS_CONTAINER_PORT="${COREDNS_DNS_CONTAINER_PORT:-15353}"
export COREDNS_HEALTH_PORT="${COREDNS_HEALTH_PORT:-18080}"
export DNS_DNSCRYPT_IP="${DNS_DNSCRYPT_IP:-172.20.255.50}"
export DNSCRYPT_PROXY_CONTAINER_PORT="${DNSCRYPT_PROXY_CONTAINER_PORT:-5053}"

# Expand environment variables in template
# sed handles variable substitution with defaults applied in shell above
if ! sed \
  -e "s|{COREDNS_DNS_CONTAINER_PORT}|$COREDNS_DNS_CONTAINER_PORT|g" \
  -e "s|{COREDNS_HEALTH_PORT}|$COREDNS_HEALTH_PORT|g" \
  -e "s|{DNS_DNSCRYPT_IP}|$DNS_DNSCRYPT_IP|g" \
  -e "s|{DNSCRYPT_PROXY_CONTAINER_PORT}|$DNSCRYPT_PROXY_CONTAINER_PORT|g" \
  "$TEMPLATE_FILE" > "$CONFIG_FILE"; then
  echo "Error: Failed to expand environment variables in Corefile template" >&2
  exit 1
fi

echo "CoreDNS configuration expanded successfully"
echo "Config file: $CONFIG_FILE"
echo "DNS container port: $COREDNS_DNS_CONTAINER_PORT"
echo "Health port: $COREDNS_HEALTH_PORT"
echo "DNSCrypt proxy IP: $DNS_DNSCRYPT_IP"
echo "DNSCrypt proxy port: $DNSCRYPT_PROXY_CONTAINER_PORT"

# Start CoreDNS with the expanded config
exec coredns -conf "$CONFIG_FILE"
