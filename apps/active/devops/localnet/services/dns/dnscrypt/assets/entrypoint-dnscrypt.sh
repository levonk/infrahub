#!/usr/bin/env bash
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/dns/dnscrypt/assets/entrypoint-dnscrypt.sh
# Entrypoint script for dnscrypt-proxy container.
# Substitutes environment variables into the config file and starts dnscrypt-proxy.

set -euo pipefail

# Use the config file passed as an argument from the docker-compose 'command' directive.
# Default to the standard config if no argument is provided.
BASE_CONFIG_FILE="${1:-/etc/dnscrypt-proxy/dnscrypt-proxy-std.toml}"
TEMPLATE_FILE="${BASE_CONFIG_FILE}.template"

WORKING_DIR="/var/cache/dnscrypt-proxy"
# Use the basename of the config file for the working copy
WORKING_CONFIG="${WORKING_DIR}/$(basename "${BASE_CONFIG_FILE}")"

echo "[ENTRYPOINT] Starting dnscrypt-proxy entrypoint script" >&2

# Verify template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[ERROR] Template file not found at $TEMPLATE_FILE" >&2
  exit 1
fi

# Ensure working directory exists with secure permissions
if [ ! -d "$WORKING_DIR" ]; then
  mkdir -p "$WORKING_DIR"
fi
chmod 700 "$WORKING_DIR"

# Copy to writable location for substitution
echo "[ENTRYPOINT] Preparing config file..." >&2
cp "$TEMPLATE_FILE" "$WORKING_CONFIG"
chmod 600 "$WORKING_CONFIG"

# Dynamically build sed expressions for all environment variables starting with 'DNS_'
sed_expressions=""
while IFS='=' read -r -d '' name value; do
    if [[ "$name" == DNS_* ]]; then
        echo "[ENTRYPOINT] Substituting ${name}=${value}" >&2
        # Add a sed expression for the current variable
        sed_expressions+="-e 's|{${name}}|${value}|g' "
    fi
done < <(printenv -0)

# Substitute all variables in one pass
if [ -n "$sed_expressions" ]; then
    # Use eval to correctly handle the space-separated sed expressions
    eval sed -i "$sed_expressions" "$WORKING_CONFIG"
fi

echo "[ENTRYPOINT] Config ready, starting dnscrypt-proxy..." >&2

# Start dnscrypt-proxy with the modified config
exec /usr/local/bin/dnscrypt-proxy -config "$WORKING_CONFIG"
