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
TEMPLATE_CONFIG_NAME="${2:-dnscrypt-proxy-std}"
echo "[ENTRYPOINT] 0 index input: $0"
echo "[ENTRYPOINT] 1 index input: $1"
echo "[ENTRYPOINT] 2 index input: $2"
echo "[ENTRYPOINT] Using config mode: $TEMPLATE_CONFIG_NAME"
BASE_CONFIG_PATH="/etc/dnscrypt-proxy"
# Construct template filename by appending .template
# e.g., dnscrypt-proxy-odoh → /etc/dnscrypt-proxy/dnscrypt-proxy-odoh.toml.template
TEMPLATE_FILE="/templates${BASE_CONFIG_PATH}/${TEMPLATE_CONFIG_NAME}.toml.template"
DEST_CONFIG_FILE="${BASE_CONFIG_PATH}/dnscrypt-proxy.toml"

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
  echo "[ENTRYPOINT]INFO: Available templates in /templates/etc/dnscrypt-proxy/:" >&2 || true
  ls -la "/templates/$BASE_CONFIG_PATH" 2>/dev/null || echo "[ENTRYPOINT]ERROR: No template files found!" >&2
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

# Enumerate env vars in a POSIX-compatible way and build sed expressions
# Use 'env' (no -0) and read only on the first '=' to keep the full value
while IFS='=' read -r name value; do
  if [[ "$name" == DNS_* ]] || [[ "$name" == PROXY_SOCKS5_TOR_* ]] || [[ "$name" == DNSCRYPT_PROXY_* ]]; then
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
    sed "${sed_expressions[@]}" "$TEMPLATE_FILE" > "$DEST_CONFIG_FILE"
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

echo "[ENTRYPOINT] Config ready, starting dnscrypt-proxy..." >&2

# Start dnscrypt-proxy with the modified config
exec /usr/local/bin/dnscrypt-proxy -config "$DEST_CONFIG_FILE"
