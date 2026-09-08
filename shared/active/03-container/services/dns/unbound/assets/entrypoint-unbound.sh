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

# Initialize or refresh root.key for DNSSEC validation.
# Pattern adopted from desec-stack unbound/entrypoint.sh:
# Run unbound-anchor on every start to keep the trust anchor current.
# Exit code 1 means the anchor was updated (not an error); if the network
# is unavailable, unbound-anchor writes the built-in anchor instead.
ROOT_KEY="/var/lib/unbound/root.key"
BUNDLED_KEY="/usr/share/dnssec-keys/root.key"
echo "[ENTRYPOINT] Refreshing root trust anchor..." >&2
if unbound-anchor -a "$ROOT_KEY" 2>&1; then
  echo "[ENTRYPOINT] root.key is current" >&2
elif [ -s "$BUNDLED_KEY" ]; then
  echo "[ENTRYPOINT] unbound-anchor could not fetch, using bundled KSK-2017 trust anchor" >&2
  cp "$BUNDLED_KEY" "$ROOT_KEY"
elif [ ! -s "$ROOT_KEY" ]; then
  echo "[ENTRYPOINT] ERROR: No root trust anchor available" >&2
  exit 1
else
  echo "[ENTRYPOINT] unbound-anchor failed, keeping existing root.key" >&2
fi
chown unbound:unbound "$ROOT_KEY" 2>/dev/null || true
chmod 644 "$ROOT_KEY"

exec unbound -d -c "$DEST_CONFIG_FILE"
