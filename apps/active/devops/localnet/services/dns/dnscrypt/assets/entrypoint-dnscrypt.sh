#!/usr/bin/env bash
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/dns/dnscrypt/assets/entrypoint-dnscrypt.sh
# Entrypoint script for dnscrypt-proxy container.
# Substitutes environment variables into the config file and starts dnscrypt-proxy.

set -euo pipefail

# Use the config file passed as an argument from the docker-compose 'command' directive.
# IMPORTANT: Pass ONLY the config name WITHOUT .toml extension (e.g., "dnscrypt-proxy-odoh").
# The script will prepend /etc/dnscrypt-proxy/ and append .toml.template automatically.
# Default to the standard config if no argument is provided.
CONFIG_NAME="${1:-dnscrypt-proxy-std}"
BASE_CONFIG_FILE="/etc/dnscrypt-proxy/${CONFIG_NAME}.toml"
# Construct template filename by appending .template
# e.g., dnscrypt-proxy-odoh → /etc/dnscrypt-proxy/dnscrypt-proxy-odoh.toml.template
TEMPLATE_FILE="/etc/dnscrypt-proxy/${CONFIG_NAME}.toml.template"

WORKING_DIR="/var/cache/dnscrypt-proxy"
# Use the basename of the config file for the working copy
WORKING_CONFIG="${WORKING_DIR}/$(basename "${BASE_CONFIG_FILE}")"

echo "[ENTRYPOINT] Starting dnscrypt-proxy entrypoint script" >&2

# Export all environment variables that were passed in (docker-compose sets them but they need to be exported)
# This ensures they're available to the sed substitution logic below
# Defaults match env.template to ensure consistency across all configurations
export DNS_DNSCRYPT_ODOH_CONTAINER_PORT="${DNS_DNSCRYPT_ODOH_CONTAINER_PORT:-5053}"
export DNS_DNSCRYPT_ANON_CONTAINER_PORT="${DNS_DNSCRYPT_ANON_CONTAINER_PORT:-5054}"
export DNS_DNSCRYPT_STD_CONTAINER_PORT="${DNS_DNSCRYPT_STD_CONTAINER_PORT:-5055}"
export DNS_DNSCRYPT_DOH_CONTAINER_PORT="${DNS_DNSCRYPT_DOH_CONTAINER_PORT:-5056}"
export DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT="${DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT:-5057}"
export DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT="${DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT:-5058}"
export DNS_DNSCRYPT_TOR_CONTAINER_PORT="${DNS_DNSCRYPT_TOR_CONTAINER_PORT:-5053}"
export PROXY_SOCKS5_TOR_IP="${PROXY_SOCKS5_TOR_IP:-172.20.255.70}"
export PROXY_SOCKS5_TOR_CONTAINER_PORT="${PROXY_SOCKS5_TOR_CONTAINER_PORT:-9050}"

# Verify template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[ERROR] Template file not found at $TEMPLATE_FILE" >&2
  echo "[ERROR] BASE_CONFIG_FILE was: $BASE_CONFIG_FILE" >&2
  echo "[ERROR] Available templates in /etc/dnscrypt-proxy/:" >&2
  ls -la /etc/dnscrypt-proxy/*.template 2>/dev/null || echo "[ERROR] No template files found!" >&2
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

# Log all environment variables being used for substitution
echo "[ENTRYPOINT] Environment variables for substitution:" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_ODOH_CONTAINER_PORT=${DNS_DNSCRYPT_ODOH_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_ANON_CONTAINER_PORT=${DNS_DNSCRYPT_ANON_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_STD_CONTAINER_PORT=${DNS_DNSCRYPT_STD_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_DOH_CONTAINER_PORT=${DNS_DNSCRYPT_DOH_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT=${DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT=${DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   DNS_DNSCRYPT_TOR_CONTAINER_PORT=${DNS_DNSCRYPT_TOR_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT]   PROXY_SOCKS5_TOR_IP=${PROXY_SOCKS5_TOR_IP}" >&2
echo "[ENTRYPOINT]   PROXY_SOCKS5_TOR_CONTAINER_PORT=${PROXY_SOCKS5_TOR_CONTAINER_PORT}" >&2

# Dynamically build sed expressions for all environment variables starting with 'DNS_', 'PROXY_SOCKS5_TOR_', or 'DNSCRYPT_PROXY_'
sed_expressions=""
while IFS='=' read -r -d '' name value; do
    if [[ "$name" == DNS_* ]] || [[ "$name" == PROXY_SOCKS5_TOR_* ]] || [[ "$name" == DNSCRYPT_PROXY_* ]]; then
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
