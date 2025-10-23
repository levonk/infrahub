#!/bin/sh
# Transparent Proxy Gateway - Container-based traffic interception
# Works in Docker Desktop/WSL2 without host modifications

set -e

echo "=== Transparent Proxy Gateway Starting ==="

# IP forwarding is enabled via docker-compose sysctls configuration
echo "✓ IP forwarding enabled via sysctls"

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

# Resolve hostnames to IP addresses (iptables requires IPs, not hostnames)
echo "=== Resolving service IPs ==="
DNS_IP=$(getent hosts "$DNS_SERVER" | awk '{print $1}')
NTP_IP=$(getent hosts "$NTP_SERVER" | awk '{print $1}')
WEB_PROXY_IP=$(getent hosts "$WEB_PROXY" | awk '{print $1}')

if [ -z "$DNS_IP" ] || [ -z "$NTP_IP" ] || [ -z "$WEB_PROXY_IP" ]; then
  echo "✗ ERROR: Failed to resolve one or more service IPs"
  echo "  DNS_SERVER=$DNS_SERVER -> $DNS_IP"
  echo "  NTP_SERVER=$NTP_SERVER -> $NTP_IP"
  echo "  WEB_PROXY=$WEB_PROXY -> $WEB_PROXY_IP"
  exit 1
fi

echo "✓ DNS: $DNS_SERVER -> $DNS_IP"
echo "✓ NTP: $NTP_SERVER -> $NTP_IP"
echo "✓ Web Proxy: $WEB_PROXY -> $WEB_PROXY_IP"

# Gateway Failure Mode Configuration
GATEWAY_FAILURE_MODE="${GATEWAY_FAILURE_MODE:-fallback-direct}"
GATEWAY_TIMEOUT="${GATEWAY_TIMEOUT:-30}"
METRICS_PORT="${METRICS_PORT:-9099}"

echo "=== Gateway Configuration ==="
echo "✓ Failure Mode: ${GATEWAY_FAILURE_MODE}"
echo "✓ Queue Timeout: ${GATEWAY_TIMEOUT}s"
echo "✓ Metrics Port: ${METRICS_PORT}"

# Initialize failure tracking
FAILURE_COUNT=0
FAILURE_START_TIME=""
RECOVERY_TIME=""
AFFECTED_CONTAINERS=""

echo "=== Configuring iptables rules ==="

# Flush existing rules
iptables -t nat -F
iptables -t nat -X
iptables -F
iptables -X

# Allow established connections
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS Transparent Interception (UDP 53 → dnsdist:5353)
echo "✓ DNS: Redirecting UDP 53 → ${DNS_IP}:${DNS_PORT}"
iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination ${DNS_IP}:${DNS_PORT}
iptables -t nat -A POSTROUTING -p udp --dport ${DNS_PORT} -j MASQUERADE

# NTP Transparent Interception (UDP 123 → chronyd:123)
echo "✓ NTP: Redirecting UDP 123 → ${NTP_IP}:${NTP_PORT}"
iptables -t nat -A PREROUTING -p udp --dport 123 -j DNAT --to-destination ${NTP_IP}:${NTP_PORT}
iptables -t nat -A POSTROUTING -p udp --dport ${NTP_PORT} -j MASQUERADE

# HTTP Transparent Interception (TCP 80 → squid:3128)
echo "✓ HTTP: Redirecting TCP 80 → ${WEB_PROXY_IP}:${WEB_PROXY_PORT}"
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${WEB_PROXY_IP}:${WEB_PROXY_PORT}
iptables -t nat -A POSTROUTING -p tcp --dport ${WEB_PROXY_PORT} -j MASQUERADE

# HTTPS Transparent Interception (TCP 443 → squid:3128)
# Note: HTTPS interception requires SSL bump configuration in Squid
echo "✓ HTTPS: Redirecting TCP 443 → ${WEB_PROXY_IP}:${WEB_PROXY_PORT}"
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination ${WEB_PROXY_IP}:${WEB_PROXY_PORT}
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

# Start metrics exporter in background
cat > /tmp/metrics-exporter.sh <<'METRICS_EOF'
#!/bin/sh
# Simple metrics exporter for gateway health
while true; do
  # Check if services are reachable
  DNS_UP=$(nc -zv -w2 ${DNS_SERVER} ${DNS_PORT} 2>&1 | grep -q succeeded && echo 1 || echo 0)
  NTP_UP=$(nc -zv -w2 ${NTP_SERVER} ${NTP_PORT} 2>&1 | grep -q succeeded && echo 1 || echo 0)
  WEB_UP=$(nc -zv -w2 ${WEB_PROXY} ${WEB_PROXY_PORT} 2>&1 | grep -q succeeded && echo 1 || echo 0)
  
  # Calculate gateway health (all services must be up)
  if [ "$DNS_UP" = "1" ] && [ "$NTP_UP" = "1" ] && [ "$WEB_UP" = "1" ]; then
    GATEWAY_UP=1
    if [ -n "$FAILURE_START_TIME" ]; then
      # Recovery detected
      RECOVERY_TIME=$(date +%s)
      DOWNTIME=$((RECOVERY_TIME - FAILURE_START_TIME))
      echo "$(date -Iseconds) RECOVERY: Gateway restored after ${DOWNTIME}s downtime, mode=${GATEWAY_FAILURE_MODE}" | tee -a /var/log/gateway-events.log
      FAILURE_START_TIME=""
    fi
  else
    GATEWAY_UP=0
    if [ -z "$FAILURE_START_TIME" ]; then
      # Failure detected
      FAILURE_START_TIME=$(date +%s)
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
      echo "$(date -Iseconds) FAILURE: Gateway services down (DNS=$DNS_UP NTP=$NTP_UP WEB=$WEB_UP), mode=${GATEWAY_FAILURE_MODE}, timeout=${GATEWAY_TIMEOUT}s" | tee -a /var/log/gateway-events.log
    fi
  fi
  
  # Export Prometheus metrics
  cat > /tmp/metrics.prom <<PROM
# HELP gateway_up Gateway health status (1=up, 0=down)
# TYPE gateway_up gauge
gateway_up ${GATEWAY_UP}

# HELP gateway_service_up Individual service health (1=up, 0=down)
# TYPE gateway_service_up gauge
gateway_service_up{service="dns"} ${DNS_UP}
gateway_service_up{service="ntp"} ${NTP_UP}
gateway_service_up{service="web"} ${WEB_UP}

# HELP gateway_failure_count Total number of gateway failures
# TYPE gateway_failure_count counter
gateway_failure_count ${FAILURE_COUNT}

# HELP gateway_failure_mode_info Gateway failure mode configuration
# TYPE gateway_failure_mode_info gauge
gateway_failure_mode_info{mode="${GATEWAY_FAILURE_MODE}",timeout="${GATEWAY_TIMEOUT}"} 1
PROM
  
  sleep 10
done
METRICS_EOF

chmod +x /tmp/metrics-exporter.sh
/tmp/metrics-exporter.sh &

# Start simple HTTP server for metrics
echo "Starting metrics server on port ${METRICS_PORT}..."
while true; do
  { echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(cat /tmp/metrics.prom 2>/dev/null || echo '# Metrics not ready')"; } | nc -l -p ${METRICS_PORT} -q 1
done &

# Keep container running and show logs
echo "=== Monitoring traffic (Ctrl+C to stop) ==="
echo "Metrics available at http://localhost:${METRICS_PORT}/metrics"
tail -f /var/log/gateway-events.log 2>/dev/null &
tail -f /dev/null
