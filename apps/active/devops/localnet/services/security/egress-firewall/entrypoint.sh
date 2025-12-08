#!/bin/bash
set -e

# egress-firewall entrypoint
# Configures iptables based on env vars

ALLOW_DESTINATIONS="${ALLOW_DESTINATIONS:-}" # format: host:port,host:port
ENABLE_DNS="${ENABLE_DNS:-true}"
DEBUG="${DEBUG:-false}"

log() { echo "[egress-firewall] $1"; }

if [[ "$DEBUG" == "true" ]]; then
    set -x
fi

log "Starting firewall setup..."

# 1. Clean slate
iptables -F
iptables -X
iptables -Z

# 2. Allow Loopback (critical for local processes)
iptables -A OUTPUT -o lo -j ACCEPT

# 3. Allow Established/Related (responses to allowed requests)
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 4. Allow DNS
# We need to ensure we can resolve domains if we use them in rules.
# Even if the user doesn't want general DNS, we might need it for the script setup.
# But if ENABLE_DNS is false, we assume user provides IPs or doesn't want resolution.
if [[ "$ENABLE_DNS" == "true" ]]; then
    log "Allowing DNS (UDP/TCP port 53) to nameservers in /etc/resolv.conf..."
    if [ -f /etc/resolv.conf ]; then
        NAMESERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
        for ns in $NAMESERVERS; do
            if [[ -n "$ns" ]]; then
                iptables -A OUTPUT -d "$ns" -p udp --dport 53 -j ACCEPT
                iptables -A OUTPUT -d "$ns" -p tcp --dport 53 -j ACCEPT
            fi
        done
    else
        log "WARNING: /etc/resolv.conf not found. DNS rules not added from file."
        # Fallback: allow all DNS? No, that's insecure.
        # Maybe allow 1.1.1.1 and 8.8.8.8 just in case? No, stick to config.
    fi
fi

# 5. Process Allowed Destinations
if [[ -n "$ALLOW_DESTINATIONS" ]]; then
    IFS=',' read -ra DESTS <<< "$ALLOW_DESTINATIONS"
    for dest in "${DESTS[@]}"; do
        # Trim whitespace
        dest=$(echo "$dest" | xargs)
        if [[ -z "$dest" ]]; then continue; fi

        # Split host and port
        if [[ "$dest" == *":"* ]]; then
            HOST="${dest%:*}"
            PORT="${dest#*:}"
        else
            HOST="$dest"
            PORT=""
        fi

        log "Processing rule for $HOST (port: ${PORT:-all})..."

        # Add iptables rules
        # iptables can resolve hostnames at command execution time.
        # This is strictly 'at startup' resolution.
        if [[ -n "$PORT" ]]; then
            iptables -A OUTPUT -d "$HOST" -p tcp --dport "$PORT" -j ACCEPT
            iptables -A OUTPUT -d "$HOST" -p udp --dport "$PORT" -j ACCEPT
        else
            iptables -A OUTPUT -d "$HOST" -j ACCEPT
        fi
    done
fi

# 6. Custom Rules Script
if [[ -f "/etc/firewall/custom-rules.sh" ]]; then
    log "Executing custom rules from /etc/firewall/custom-rules.sh..."
    bash "/etc/firewall/custom-rules.sh"
fi

# 7. Default Policy: DROP
log "Applying DROP policy to OUTPUT chain..."
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
# We usually leave INPUT ACCEPT for sidecars as ingress filtering is done by
# not publishing ports or by the main container's logic, but this is an *egress* firewall.

# 8. List Rules (for verification in logs)
log "Applied Rules:"
iptables -L OUTPUT -v -n

log "Firewall initialized. Blocking indefinitely."

# Signal handling to exit gracefully
trap "echo 'Stopping...'; exit 0" SIGTERM SIGINT

# Wait loop
while true; do
    sleep 60 &
    wait $!
done
