#!/bin/bash
set -e

# egress-firewall entrypoint
# Configures iptables for Sidecar (OUTPUT) or Gateway (FORWARD/PREROUTING) modes

ALLOW_DESTINATIONS="${ALLOW_DESTINATIONS:-}" # format: host:port,host:port
ENABLE_DNS="${ENABLE_DNS:-true}"
DNS_SERVER="${DNS_SERVER:-}" # Optional: IP of upstream DNS to force routing to
ENABLE_MITM="${ENABLE_MITM:-false}"
MITM_OPTS="${MITM_OPTS:-}" # Extra args for mitmdump
GATEWAY_MODE="${GATEWAY_MODE:-false}" # If true, enables routing, NAT, and interception for downstream clients
DEBUG="${DEBUG:-false}"
WAN_IFACE="${WAN_IFACE:-eth0}" # Default WAN interface for Masquerade

log() { echo "[egress-firewall] $1"; }

if [[ "$DEBUG" == "true" ]]; then
    set -x
fi

log "Starting firewall setup (Gateway Mode: $GATEWAY_MODE)..."

# 1. Clean slate
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z

# 2. Setup MITM User (if needed)
if [[ "$ENABLE_MITM" == "true" ]]; then
    if ! id -u mitmproxy >/dev/null 2>&1; then
        log "Creating mitmproxy user..."
        useradd -r -s /bin/false mitmproxy
    fi
fi

# 3. Allow Loopback
iptables -A OUTPUT -o lo -j ACCEPT
# (No FORWARD rules for lo needed usually)

# 4. Allow Established/Related
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
if [[ "$GATEWAY_MODE" == "true" ]]; then
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Enable Masquerade on WAN interface
    log "Enabling MASQUERADE on $WAN_IFACE..."
    iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
    
    # Verify IP Forwarding
    if [[ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]]; then
        log "WARNING: /proc/sys/net/ipv4/ip_forward is NOT 1. Gateway mode requires sysctl net.ipv4.ip_forward=1 in docker-compose."
    fi
fi

# 5. DNS Configuration
configure_dns_rules() {
    local chain=$1 # OUTPUT or PREROUTING (NAT) / FILTER
    local is_nat=$2
    
    if [[ -n "$DNS_SERVER" ]]; then
        if [[ "$is_nat" == "true" ]]; then
            # DNAT to specific server
            iptables -t nat -A "$chain" -p udp --dport 53 -j DNAT --to-destination "$DNS_SERVER"
            iptables -t nat -A "$chain" -p tcp --dport 53 -j DNAT --to-destination "$DNS_SERVER"
        else
            # Allow traffic to that server
            iptables -A "$chain" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT
            iptables -A "$chain" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT
        fi
    elif [[ "$ENABLE_DNS" == "true" ]]; then
        # Only relevant for OUTPUT filter rules (allow resolv.conf nameservers)
        # For Gateway mode without DNS_SERVER, we assume clients bring their own DNS or use the Gateway's IP
        # If they use Gateway IP, we need to know where to send it.
        # Fallback: If no DNS_SERVER set in Gateway Mode, we can't easily DNAT.
        # So we just allow standard DNS ports out.
        if [[ "$is_nat" == "false" ]]; then
             if [ -f /etc/resolv.conf ]; then
                NAMESERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
                for ns in $NAMESERVERS; do
                    if [[ -n "$ns" ]]; then
                        iptables -A "$chain" -d "$ns" -p udp --dport 53 -j ACCEPT
                        iptables -A "$chain" -d "$ns" -p tcp --dport 53 -j ACCEPT
                    fi
                done
            fi
            # Also generic allow if strictly needed? No, stick to explicit.
        fi
    fi
}

log "Configuring DNS rules..."
# Local/Sidecar traffic
configure_dns_rules "OUTPUT" "true"
configure_dns_rules "OUTPUT" "false"

# Gateway traffic
if [[ "$GATEWAY_MODE" == "true" ]]; then
    configure_dns_rules "PREROUTING" "true"
    configure_dns_rules "FORWARD" "false"
fi


# 6. MITM Configuration
if [[ "$ENABLE_MITM" == "true" ]]; then
    log "Starting mitmproxy (transparent mode)..."
    
    su -s /bin/bash mitmproxy -c "mitmdump --mode transparent --showhost --set block_global=false $MITM_OPTS" &
    MITM_PID=$!
    sleep 2
    
    log "Applying MITM redirection rules..."
    
    # 6a. Local/Sidecar Traffic (OUTPUT)
    iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner ! --uid-owner mitmproxy -j REDIRECT --to-port 8080
    iptables -t nat -A OUTPUT -p tcp --dport 443 -m owner ! --uid-owner mitmproxy -j REDIRECT --to-port 8080
    iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport 8080 -j ACCEPT
    
    # 6b. Gateway Traffic (PREROUTING)
    if [[ "$GATEWAY_MODE" == "true" ]]; then
        # Redirect incoming traffic destined for 80/443 to local 8080
        # No 'owner' check needed for PREROUTING (traffic comes from outside)
        iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
        iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
        
        # We must also allow the traffic to flow into the INPUT chain for the proxy
        # (REDIRECT sends it to localhost, so it hits INPUT, not FORWARD)
        # Usually INPUT is ACCEPT, but let's be explicit if needed.
        # But wait, this is an EGRESS firewall. INPUT usually isn't restricted.
        # We'll assume INPUT policy is ACCEPT (default in Docker).
    fi
    
    log "MITM enabled. Proxy traffic is subject to ALLOW_DESTINATIONS."
fi

# 7. Process Allowed Destinations
# Helper to add rules
add_allow_rule() {
    local host=$1
    local port=$2
    local chain=$3
    
    if [[ -n "$port" ]]; then
        iptables -A "$chain" -d "$host" -p tcp --dport "$port" -j ACCEPT
        iptables -A "$chain" -d "$host" -p udp --dport "$port" -j ACCEPT
    else
        iptables -A "$chain" -d "$host" -j ACCEPT
    fi
}

if [[ -n "$ALLOW_DESTINATIONS" ]]; then
    IFS=',' read -ra DESTS <<< "$ALLOW_DESTINATIONS"
    for dest in "${DESTS[@]}"; do
        dest=$(echo "$dest" | xargs)
        if [[ -z "$dest" ]]; then continue; fi

        if [[ "$dest" == *":"* ]]; then
            HOST="${dest%:*}"
            PORT="${dest#*:}"
        else
            HOST="$dest"
            PORT=""
        fi

        log "Processing rule for $HOST (port: ${PORT:-all})..."
        
        add_allow_rule "$HOST" "$PORT" "OUTPUT"
        if [[ "$GATEWAY_MODE" == "true" ]]; then
            add_allow_rule "$HOST" "$PORT" "FORWARD"
        fi
    done
fi

# 8. Custom Rules Script
if [[ -f "/etc/firewall/custom-rules.sh" ]]; then
    log "Executing custom rules..."
    bash "/etc/firewall/custom-rules.sh"
fi

# 9. Default Policy: DROP
log "Applying DROP policy..."
iptables -P OUTPUT DROP
if [[ "$GATEWAY_MODE" == "true" ]]; then
    iptables -P FORWARD DROP
else
    # If not gateway, we don't care about FORWARD, but secure default is DROP
    iptables -P FORWARD DROP
fi

# 10. List Rules
log "Applied Filter Rules:"
iptables -L -v -n
log "Applied NAT Rules:"
iptables -t nat -L -v -n

log "Firewall initialized."

cleanup() {
    echo "Stopping..."
    if [[ -n "$MITM_PID" ]]; then kill "$MITM_PID" 2>/dev/null || true; fi
    exit 0
}
trap cleanup SIGTERM SIGINT

while true; do sleep 60 & wait $!; done
