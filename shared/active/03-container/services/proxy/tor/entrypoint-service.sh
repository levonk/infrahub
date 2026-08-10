#!/bin/sh
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/proxy/tor/entrypoint-service.sh

set -e

TEMPLATE_FILE=/etc/tor/torrc.template
CONFIG_FILE=/etc/tor/torrc

# Generate exit node configuration if enabled
EXIT_NODE_CONFIG=""
if [ "$PROXY_TOR_EXIT_NODE_ENABLED" = "true" ]; then
    echo "Enabling Tor exit node mode..."
    EXIT_NODE_CONFIG="# Exit Node Configuration
ORPort ${PROXY_TOR_ORPORT:-9001}
DirPort ${PROXY_TOR_DIRPORT:-9030}
Nickname ${PROXY_TOR_NICKNAME:-levonk-tor-exit}
ContactInfo ${PROXY_TOR_CONTACT_INFO:-admin@example.com}
ExitPolicy ${PROXY_TOR_EXIT_POLICY:-reject *:*}
RelayBandwidthRate ${PROXY_TOR_BANDWIDTH_RATE:-100 KB}
RelayBandwidthBurst ${PROXY_TOR_BANDWIDTH_BURST:-200 KB}"
fi

# Expand environment variables in template (single-line substitutions only)
# Use a temp file approach to avoid sed issues with multi-line EXIT_NODE_CONFIG
TMP_FILE=$(mktemp)
sed -e "s|{PROXY_TOR_SOCKS5_CONTAINER_PORT}|${PROXY_TOR_SOCKS5_CONTAINER_PORT:-9050}|g" \
    -e "s|{PROXY_TOR_ORPORT}|${PROXY_TOR_ORPORT:-9001}|g" \
    -e "s|{PROXY_TOR_DIRPORT}|${PROXY_TOR_DIRPORT:-9030}|g" \
    -e "s|{PROXY_TOR_NICKNAME}|${PROXY_TOR_NICKNAME:-levonk-tor-exit}|g" \
    -e "s|{PROXY_TOR_CONTACT_INFO}|${PROXY_TOR_CONTACT_INFO:-admin@example.com}|g" \
    -e "s|{PROXY_TOR_EXIT_POLICY}|${PROXY_TOR_EXIT_POLICY:-reject *:*}|g" \
    -e "s|{PROXY_TOR_BANDWIDTH_RATE}|${PROXY_TOR_BANDWIDTH_RATE:-100 KB}|g" \
    -e "s|{PROXY_TOR_BANDWIDTH_BURST}|${PROXY_TOR_BANDWIDTH_BURST:-200 KB}|g" \
    "$TEMPLATE_FILE" > "$TMP_FILE"

# Insert the exit node config block (multi-line safe)
if [ -n "$EXIT_NODE_CONFIG" ]; then
    # Replace the placeholder line with the multi-line config block
    # Using awk for multi-line replacement (sed can't handle newlines in replacement)
    awk -v block="$EXIT_NODE_CONFIG" '
        { gsub(/\{PROXY_TOR_EXIT_NODE_CONFIG\}/, block); print }
    ' "$TMP_FILE" > "$CONFIG_FILE"
else
    # Remove the placeholder line if exit node is disabled
    sed -e "/{PROXY_TOR_EXIT_NODE_CONFIG}/d" "$TMP_FILE" > "$CONFIG_FILE"
fi
rm -f "$TMP_FILE"

# Create necessary directories
mkdir -p /var/lib/tor /var/log/tor
# Tor refuses to run as root with a data directory owned by another user.
# The Alpine tor package creates /var/lib/tor owned by the 'tor' user (uid 100).
# Since this container runs as root, chown to root to avoid the conflict.
chown -R root:root /var/lib/tor /var/log/tor

# Start Tor
exec tor -f "$CONFIG_FILE"
