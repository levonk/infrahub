#!/bin/sh
# Transparent Proxy Gateway - Container-based traffic interception
# Works in Docker Desktop/WSL2 without host modifications

set -e

echo "=== Transparent Proxy Gateway Starting ==="

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "✓ IP forwarding enabled"

# Get gateway IP (this container's IP)
GATEWAY_IP=$(hostname -i | awk '{print $1}')
echo "✓ Gateway IP: $GATEWAY_IP"

# DNS Services
DNS_SERVER="${DNS_SERVER:-dnsdist}"
DNS_PORT="${DNS_PORT:-5353}"

# NTP Service  
NTP_SERVER="${NTP_SERVER:-chronyd}"
NTP_PORT="${NTP_PORT:-123}"

# Web Proxy
WEB_PROXY="${WEB_PROXY:-squid}"
WEB_PROXY_PORT="${WEB_PROXY_PORT:-3128}"

echo "=== Configuring iptables rules ==="

# Flush existing rules
iptables -t nat -F
iptables -t nat -X
iptables -F
iptables -X

# Allow established connections
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS Transparent Interception (UDP 53 → dnsdist:5353)
echo "✓ DNS: Redirecting UDP 53 → ${DNS_SERVER}:${DNS_PORT}"
iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination ${DNS_SERVER}:${DNS_PORT}
iptables -t nat -A POSTROUTING -p udp --dport ${DNS_PORT} -j MASQUERADE

# NTP Transparent Interception (UDP 123 → chronyd:123)
echo "✓ NTP: Redirecting UDP 123 → ${NTP_SERVER}:${NTP_PORT}"
iptables -t nat -A PREROUTING -p udp --dport 123 -j DNAT --to-destination ${NTP_SERVER}:${NTP_PORT}
iptables -t nat -A POSTROUTING -p udp --dport ${NTP_PORT} -j MASQUERADE

# HTTP Transparent Interception (TCP 80 → squid:3128)
echo "✓ HTTP: Redirecting TCP 80 → ${WEB_PROXY}:${WEB_PROXY_PORT}"
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${WEB_PROXY}:${WEB_PROXY_PORT}
iptables -t nat -A POSTROUTING -p tcp --dport ${WEB_PROXY_PORT} -j MASQUERADE

# HTTPS Transparent Interception (TCP 443 → squid:3128)
# Note: HTTPS interception requires SSL bump configuration in Squid
echo "✓ HTTPS: Redirecting TCP 443 → ${WEB_PROXY}:${WEB_PROXY_PORT}"
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination ${WEB_PROXY}:${WEB_PROXY_PORT}
iptables -t nat -A POSTROUTING -p tcp --dport ${WEB_PROXY_PORT} -j MASQUERADE

# Allow all forwarding (containers can reach each other)
iptables -A FORWARD -j ACCEPT

echo "=== iptables rules configured ==="
echo ""
echo "Transparent Proxy Gateway is ready!"
echo "Configure containers to use this gateway:"
echo "  dns: [${GATEWAY_IP}]"
echo "  or add to homelab network with gateway: ${GATEWAY_IP}"
echo ""

# Keep container running and show logs
echo "=== Monitoring traffic (Ctrl+C to stop) ==="
tail -f /dev/null
