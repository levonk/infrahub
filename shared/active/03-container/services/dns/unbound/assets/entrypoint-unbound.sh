#!/usr/bin/env bash
# Entrypoint script for Unbound container.
# Substitutes environment variables into the config file and starts Unbound.
# Supports three modes via UNBOUND_MODE env var:
#   validator — validating cache between CoreDNS and fallback tiers
#   tor       — Unbound over Tor (Tier 3)
#   root      — Unbound recursive to root (Tier 10)

set -uo pipefail

UNBOUND_MODE="${UNBOUND_MODE:-validator}"
BASE_CONFIG_PATH="/etc/unbound"
TEMPLATE_FILE="/templates${BASE_CONFIG_PATH}/unbound-${UNBOUND_MODE}.conf.template"
DEST_CONFIG_FILE="${BASE_CONFIG_PATH}/unbound.conf"

echo "[ENTRYPOINT] Starting Unbound entrypoint script" >&2
echo "[ENTRYPOINT] UNBOUND_MODE=${UNBOUND_MODE}" >&2

if [ ! -r "$TEMPLATE_FILE" ]; then
  echo "[ENTRYPOINT] ERROR: Template file not found at $TEMPLATE_FILE" >&2
  echo "[ENTRYPOINT] Available templates:" >&2
  ls -la "/templates${BASE_CONFIG_PATH}/" 2>/dev/null || echo "[ENTRYPOINT] No template directory found" >&2
  exit 1
fi

echo "[ENTRYPOINT] Rendering config from ${TEMPLATE_FILE}" >&2
cp "$TEMPLATE_FILE" "$DEST_CONFIG_FILE"
chmod 644 "$DEST_CONFIG_FILE"

# Substitute all DNS_ and PROXY_ environment variables
for env_var in $(env | grep -E '^(DNS_|PROXY_)' | cut -d= -f1); do
  env_value="${!env_var}"
  sed -i "s|{${env_var}}|${env_value}|g" "$DEST_CONFIG_FILE"
done

echo "[ENTRYPOINT] Config rendered, starting Unbound..." >&2

# Initialize root.key for DNSSEC validation if missing
ROOT_KEY="/var/lib/unbound/root.key"
BUNDLED_KEY="/usr/share/dnssec-keys/root.key"
if [ ! -s "$ROOT_KEY" ]; then
  echo "[ENTRYPOINT] root.key not found, initializing..." >&2
  # Try unbound-anchor first (fetches current root trust anchor via DNS)
  if unbound-anchor -a "$ROOT_KEY" 2>&1; then
    echo "[ENTRYPOINT] root.key initialized via unbound-anchor" >&2
  elif [ -s "$BUNDLED_KEY" ]; then
    echo "[ENTRYPOINT] unbound-anchor failed, using bundled KSK-2017 trust anchor" >&2
    cp "$BUNDLED_KEY" "$ROOT_KEY"
  else
    echo "[ENTRYPOINT] ERROR: No root trust anchor available" >&2
    exit 1
  fi
  chown unbound:unbound "$ROOT_KEY" 2>/dev/null || true
  chmod 644 "$ROOT_KEY"
fi

exec unbound -d -c "$DEST_CONFIG_FILE"
