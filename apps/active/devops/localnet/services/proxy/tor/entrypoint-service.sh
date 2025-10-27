#!/bin/sh
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/proxy/tor/entrypoint-service.sh


set -e

TEMPLATE_FILE=/etc/tor/torrc.template
CONFIG_FILE=/etc/tor/torrc

# Expand environment variables in template
sed -e "s|{PROXY_SOCKS5_TOR_CONTAINER_PORT}|$PROXY_SOCKS5_TOR_CONTAINER_PORT|g" \
    "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Start Tor
exec tor -f "$CONFIG_FILE"
