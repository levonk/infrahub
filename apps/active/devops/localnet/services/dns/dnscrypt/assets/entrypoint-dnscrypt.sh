#!/usr/bin/env bash
# Shellcheck bash
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/dns/dnscrypt/assets/entrypoint-dnscrypt.sh
# Entrypoint script for dnscrypt-proxy container.
# Substitutes environment variables into the config file and starts dnscrypt-proxy.

set -uo pipefail

# Use the config file passed as an argument from the docker-compose 'command' directive.
# IMPORTANT: Pass ONLY the config name WITHOUT .toml extension (e.g., "dnscrypt-proxy-odoh").
# The script will prepend /etc/dnscrypt-proxy/ and append .toml.template automatically.
# Default to the standard config if no argument is provided.
CONFIG_NAME="${2:-dnscrypt-proxy-std}"
echo "[ENTRYPOINT] 0 index input: $0"
echo "[ENTRYPOINT] 1 index input: $1"
echo "[ENTRYPOINT] 2 index input: $2"
echo "[ENTRYPOINT] Using config: $CONFIG_NAME"
BASE_CONFIG_FILE="/etc/dnscrypt-proxy/${CONFIG_NAME}.toml"
# Construct template filename by appending .template
# e.g., dnscrypt-proxy-odoh → /etc/dnscrypt-proxy/dnscrypt-proxy-odoh.toml.template
TEMPLATE_FILE="/templates${BASE_CONFIG_FILE}.template"

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
if [ ! -r "$TEMPLATE_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Template file not found at $TEMPLATE_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: BASE_CONFIG_FILE was: $BASE_CONFIG_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Available templates in /templates/etc/dnscrypt-proxy/:" >&2 || true
  ls -la /templates/etc/dnscrypt-proxy/*.template 2>/dev/null || echo "[ENTRYPOINT]ERROR: No template files found!" >&2
  exit 1
fi

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
# Initialize sed_expressions as an empty array
sed_expressions=()

# Read environment variables null-separated
while IFS='=' read -r -d '' name value; do
    # Check if the variable name matches the required prefixes
    if [[ "$name" == DNS_* ]] || [[ "$name" == PROXY_SOCKS5_TOR_* ]] || [[ "$name" == DNSCRYPT_PROXY_* ]]; then
        echo "[ENTRYPOINT] Substituting ${name}=${value}" >&2

        # Safely construct the sed expression using double quotes for expansion
        # Replace: {VARIABLE_NAME} with actual VALUE
        # Use '|' as delimiter in sed to avoid conflicts with '/' in paths/values
        sed_expressions+=(-e "s|{${name}}|${value}|g")
    fi
done < <(printenv -0)

# Substitute all variables in one pass
if [ ${#sed_expressions[@]} -gt 0 ]; then
    # Use the array expansion "${sed_expressions[@]}" to pass arguments safely
    sed "${sed_expressions[@]}" "$TEMPLATE_FILE" > "$BASE_CONFIG_FILE"
else
    # Optional: Copy the file if no substitutions were made
    cp "$TEMPLATE_FILE" "$BASE_CONFIG_FILE"
fi

# Verify config file exists
if [ ! -r "$BASE_CONFIG_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Config file not found at $BASE_CONFIG_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Template file was: $TEMPLATE_FILE" >&2 || true
  echo "[ENTRYPOINT]INFO: Available files in /etc/dnscrypt-proxy/:" >&2 || true
  ls -la /etc/dnscrypt-proxy/ 2>/dev/null || echo "[ENTRYPOINT]ERROR: No files found!" >&2 || true
  exit 1
fi

echo "[ENTRYPOINT] Config ready, starting dnscrypt-proxy..." >&2

# Start dnscrypt-proxy with the modified config
exec /usr/local/bin/dnscrypt-proxy -config "$BASE_CONFIG_FILE"
