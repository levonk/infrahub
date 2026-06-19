#!/bin/bash
# Health check for NordVPN service
# Checks if NordVPN is connected and VPN interface is up

set -e

# Check if NordVPN daemon is running
if ! pgrep -x "nordvpnd" > /dev/null; then
  echo "ERROR: NordVPN daemon not running"
  exit 1
fi

# Check if connected to VPN
if ! nordvpn status | grep -q "Connected"; then
  echo "ERROR: NordVPN not connected"
  exit 1
fi

# Check if nordlynx interface exists
if ! ip link show nordlynx > /dev/null 2>&1; then
  echo "ERROR: nordlynx interface not found"
  exit 1
fi

# Check if IP forwarding is enabled
if [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]; then
  echo "ERROR: IP forwarding not enabled"
  exit 1
fi

echo "OK: NordVPN service healthy"
exit 0
