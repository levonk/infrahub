#!/bin/bash
set -e

# Gluetun entrypoint wrapper
# Gluetun handles VPN connection, firewall, and routing automatically
# This script is a no-op since gluetun has its own entrypoint

echo "Starting gluetun-based NordVPN container..."
echo "Configuration:"
echo "  Provider: ${VPN_SERVICE_PROVIDER:-nordvpn}"
echo "  Technology: ${OPENVPN_VERSION:-nordlynx}"
echo "  Country: ${SERVER_COUNTRIES:-United States}"
echo "  Firewall: ${FIREWALL:-on}"

# Execute gluetun's default entrypoint
exec /gluetun-entrypoint
