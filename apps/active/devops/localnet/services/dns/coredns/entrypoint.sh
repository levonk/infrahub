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
export COREDNS_HEALTH_PORT="${COREDNS_HEALTH_PORT:-18080}"

# Expand environment variables in template
if ! envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"; then
  echo "Error: Failed to expand environment variables in Corefile template" >&2
  exit 1
fi

echo "CoreDNS configuration expanded successfully"
echo "Config file: $CONFIG_FILE"
echo "Health port: $COREDNS_HEALTH_PORT"

# Start CoreDNS with the expanded config
exec coredns -conf "$CONFIG_FILE"
