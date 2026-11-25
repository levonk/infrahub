#!/usr/bin/env bash
# WAN-less outbound bridge for the levonk OpenWrt Velop nodes.
#
# The nodes have no WAN uplink yet — this script gives them outbound via:
#   1. a CONNECT proxy on this Mac at 127.0.0.1:8899 (connect_proxy.py)
#   2. per-node SSH keepalive reverse forwards:
#        -R 8899  -> this Mac's CONNECT proxy   (tailscaled HTTPS_PROXY;
#                                                openwrt_tailscale_proxy
#                                                in group_vars/openwrt_aps.yml)
#        -R 8443  -> downloads.openwrt.org:443  (apk feeds; nodes have
#                                                distfeeds patched to :8443
#                                                + /etc/hosts pin to 127.0.0.1)
#
# Both loops auto-reconnect, so node reboots re-establish the forwards.
#
# RETIRE when velop01's WAN (eth2) is cabled:
#   - openwrt_tailscale_proxy: "" in group_vars/openwrt_aps.yml + redeploy
#   - on each node: sed -i 's|downloads.openwrt.org:8443|downloads.openwrt.org|g' \
#       /etc/apk/repositories.d/distfeeds.list && sed -i '/downloads.openwrt.org/d' /etc/hosts
#   - stop this script
#
# Usage: scripts/openwrt-outbound-bridge.sh   (Ctrl-C to stop)

set -u
KEY="${VELOP_SSH_KEY:-$HOME/.ssh/lzkmbp2016-micro-oracle-orig}"
NODES="${VELOP_NODES:-192.168.50.1 192.168.50.12}"
PROXY_PORT="${VELOP_PROXY_PORT:-8899}"
FEED_PORT="${VELOP_FEED_PORT:-8443}"
PROXY_SCRIPT="$(cd "$(dirname "$0")" && pwd)/connect_proxy.py"

PIDS=""

# 1. CONNECT proxy on this Mac (keepalive). Skip if one's already bound.
if pgrep -f connect_proxy.py >/dev/null 2>&1; then
  echo "connect proxy already running"
else
  ( while :; do python3 "$PROXY_SCRIPT" 2>/dev/null; sleep 2; done ) &
  PIDS="$PIDS $!"
fi

# 2. Per-node reverse-forward keepalive
for node in $NODES; do
  ( while :; do
      ssh -N -o ExitOnForwardFailure=yes \
          -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -i "$KEY" \
          -R "$PROXY_PORT:127.0.0.1:$PROXY_PORT" \
          -R "$FEED_PORT:downloads.openwrt.org:443" \
          "root@$node" 2>/dev/null
      sleep 3
    done ) &
  PIDS="$PIDS $!"
  echo "forward loop started for $node"
done

trap 'kill $PIDS 2>/dev/null; exit' INT TERM
echo "bridge up: proxy :$PROXY_PORT, feeds :$FEED_PORT -> $NODES (Ctrl-C to stop)"
wait
