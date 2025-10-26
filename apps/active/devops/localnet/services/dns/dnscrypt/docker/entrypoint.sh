#!/bin/sh
# Entrypoint script for dnscrypt-proxy container
# Substitutes environment variables into the config file and starts dnscrypt-proxy

set -e

LISTEN_PORT="${DNSCRYPT_PROXY_CONTAINER_PORT:-5053}"
CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
WORKING_DIR="/var/cache/dnscrypt-proxy"
WORKING_CONFIG="${WORKING_DIR}/dnscrypt-proxy.toml"

echo "[ENTRYPOINT] Starting dnscrypt-proxy entrypoint script" >&2
echo "[ENTRYPOINT] DNSCRYPT_PROXY_CONTAINER_PORT=${DNSCRYPT_PROXY_CONTAINER_PORT}" >&2
echo "[ENTRYPOINT] LISTEN_PORT=${LISTEN_PORT}" >&2

# Verify config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[ERROR] Config file not found at $CONFIG_FILE" >&2
  exit 1
fi

# Ensure working directory exists with secure permissions
if [ ! -d "$WORKING_DIR" ]; then
  mkdir -p "$WORKING_DIR"
fi
chmod 700 "$WORKING_DIR"

# Copy to writable location and substitute port placeholders
echo "[ENTRYPOINT] Preparing config with port substitution..." >&2
cp "$CONFIG_FILE" "$WORKING_CONFIG"
chmod 600 "$WORKING_CONFIG"

if ! sed -i "s|{DNSCRYPT_PROXY_CONTAINER_PORT}|${LISTEN_PORT}|g" "$WORKING_CONFIG"; then
  echo "[ERROR] Failed to substitute port in config file" >&2
  exit 1
fi

# Verify substitution was successful
if grep -q "{DNSCRYPT_PROXY_CONTAINER_PORT}" "$WORKING_CONFIG"; then
  echo "[ERROR] Port placeholder still present in config after substitution" >&2
  exit 1
fi

echo "[ENTRYPOINT] Config ready, starting dnscrypt-proxy..." >&2

# Start dnscrypt-proxy with the modified config
exec /usr/local/bin/dnscrypt-proxy -config "$WORKING_CONFIG"
