#!/usr/bin/env bash
# CoreDNS entrypoint script
# Expands environment variables in Corefile template and starts CoreDNS

set -uo pipefail

BASE_CONFIG_PATH="/etc/coredns"
TEMPLATE_CONFIG_NAME="Corefile"
# Construct template filename by appending .template
# e.g., coredns → /etc/coredns/coredns.conf.template
TEMPLATE_FILE="/templates${BASE_CONFIG_PATH}/${TEMPLATE_CONFIG_NAME}.template"
DEST_CONFIG_FILE="${BASE_CONFIG_PATH}/${TEMPLATE_CONFIG_NAME}"

echo "[ENTRYPOINT] Starting coredns entrypoint script" >&2

# Verify template file exists
if [ ! -r "$TEMPLATE_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Template file not found at $TEMPLATE_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Available templates in /templates/etc/coredns/:" >&2 || true
  ls -la "/templates/$BASE_CONFIG_PATH" 2>/dev/null || echo "[ENTRYPOINT]ERROR: No template files found!" >&2
  exit 1
fi

# Log all environment variables being used for substitution
echo "[ENTRYPOINT] Environment variables for substitution:" >&2
echo "[ENTRYPOINT]   DNS_COREDNS_MAIN_CONTAINER_PORT=${DNS_COREDNS_MAIN_CONTAINER_PORT}" >&2

# Dynamically build sed expressions for all environment variables starting with 'DNS_', 'DNSDIST_'
# Initialize sed_expressions as an empty array
sed_expressions=()

# Enumerate env vars in a POSIX-compatible way and build sed expressions
# Use 'env' (no -0) and read only on the first '=' to keep the full value
while IFS='=' read -r name value; do
  if [[ "$name" == DNS_* ]]; then
    # Escape for sed replacement: backslash, ampersand, and our '|' delimiter
    value_escaped=${value//\\/\\\\}
    value_escaped=${value_escaped//&/\\&}
    value_escaped=${value_escaped//|/\\|}
    echo "[ENTRYPOINT] Substituting ${name}=${value}" >&2
    sed_expressions+=(-e "s|{${name}}|${value_escaped}|g")
  fi
done < <(env)

# Substitute all variables in one pass
if [ ${#sed_expressions[@]} -gt 0 ]; then
    # Use the array expansion "${sed_expressions[@]}" to pass arguments safely
    sed "${sed_expressions[@]}" "$TEMPLATE_FILE"  | iconv -f us-ascii -t utf-8 > "$DEST_CONFIG_FILE"
else
    # Optional: Copy the file if no substitutions were made
    cp "$TEMPLATE_FILE" "$DEST_CONFIG_FILE"
fi

# Verify config file exists
if [ ! -r "$DEST_CONFIG_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Config file not found at $DEST_CONFIG_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Template file was: $TEMPLATE_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Available files in ${BASE_CONFIG_PATH}:" >&2 || true
  ls -la "${BASE_CONFIG_PATH}" 2>/dev/null || echo "[ENTRYPOINT]ERROR: No files found!" >&2 || true
  exit 1
fi


echo "CoreDNS configuration expanded successfully"
echo "Config file: $DEST_CONFIG_FILE"
echo "DNS container port: $DNS_COREDNS_MAIN_CONTAINER_PORT"
echo "Health port: $DNS_COREDNS_MAIN_HEALTH_CONTAINER_PORT"

# Start CoreDNS with the expanded config
export AUTOMAXPROCS_LOG_LEVEL=warn
exec coredns -conf "$DEST_CONFIG_FILE"
