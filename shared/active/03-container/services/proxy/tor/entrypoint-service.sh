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
ORPort {PROXY_TOR_ORPORT}
DirPort {PROXY_TOR_DIRPORT}
Nickname {PROXY_TOR_NICKNAME}
ContactInfo {PROXY_TOR_CONTACT_INFO}
ExitPolicy {PROXY_TOR_EXIT_POLICY}
RelayBandwidthRate {PROXY_TOR_BANDWIDTH_RATE}
RelayBandwidthBurst {PROXY_TOR_BANDWIDTH_BURST}"
fi

# Expand environment variables in template
sed -e "s|{PROXY_TOR_SOCKS5_CONTAINER_PORT}|$PROXY_TOR_SOCKS5_CONTAINER_PORT|g" \
    -e "s|{PROXY_TOR_EXIT_NODE_CONFIG}|$EXIT_NODE_CONFIG|g" \
    -e "s|{PROXY_TOR_ORPORT}|${PROXY_TOR_ORPORT:-9001}|g" \
    -e "s|{PROXY_TOR_DIRPORT}|${PROXY_TOR_DIRPORT:-9030}|g" \
    -e "s|{PROXY_TOR_NICKNAME}|${PROXY_TOR_NICKNAME:-levonk-tor-exit}|g" \
    -e "s|{PROXY_TOR_CONTACT_INFO}|${PROXY_TOR_CONTACT_INFO:-admin@levonk.com}|g" \
    -e "s|{PROXY_TOR_EXIT_POLICY}|${PROXY_TOR_EXIT_POLICY:-reject *:*}|g" \
    -e "s|{PROXY_TOR_BANDWIDTH_RATE}|${PROXY_TOR_BANDWIDTH_RATE:-100 KB}|g" \
    -e "s|{PROXY_TOR_BANDWIDTH_BURST}|${PROXY_TOR_BANDWIDTH_BURST:-200 KB}|g" \
    "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Create necessary directories
mkdir -p /var/lib/tor /var/log/tor

# Start Tor
exec tor -f "$CONFIG_FILE"
