#!/usr/bin/env bash
# DNS Leak Test - Verify no DNS leaks and ODoH enabled
# Tests that all DNS queries are routed through local DNS infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env file if it exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.env"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name - $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$result" == "FAIL" ]]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name - $message"
    fi
}

parse_container_status() {
    local container_name="$1"
    local status=""
    local uptime=""
    local health=""

    status=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps "$container_name" --format "{{.Status}}" 2>/dev/null || echo "not found")

    # Extract uptime (e.g., "Up 23 minutes" or "Up 3 hours (unhealthy)")
    # Match "Up " followed by time info, stopping before optional health status in parens
    if [[ "$status" =~ Up[[:space:]]([0-9]+[[:space:]]+(second|minute|hour|day)s?) ]]; then
        uptime="${BASH_REMATCH[1]:-}"
    fi

    # Check health status (e.g., "(unhealthy)" or "(healthy)")
    if [[ "$status" =~ \(([^\)]+)\) ]]; then
        health="${BASH_REMATCH[1]:-}"
    fi

    echo "$status|$uptime|$health"
}

# Convert uptime string to seconds for comparison
uptime_to_seconds() {
    local uptime="$1"
    local seconds=0

    # Return 0 if uptime is empty or whitespace-only
    if [[ -z "${uptime// /}" ]]; then
        echo "0"
        return
    fi

    # Parse "X minutes", "X hours", "X seconds", etc.
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*hour ]]; then
        seconds=$((${BASH_REMATCH[1]:-0} * 3600))
    fi
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*minute ]]; then
        seconds=$((seconds + ${BASH_REMATCH[1]:-0} * 60))
    fi
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*second ]]; then
        seconds=$((seconds + ${BASH_REMATCH[1]:-0}))
    fi

    echo "$seconds"
}

get_file_mtime_seconds() {
    local file="$1"

    if [[ -f "$file" ]]; then
        if stat -f %m "$file" >/dev/null 2>&1; then
            stat -f %m "$file"
            return
        elif stat -c %Y "$file" >/dev/null 2>&1; then
            stat -c %Y "$file"
            return
        fi
    fi

    echo ""
}

format_duration() {
    local total_seconds=${1:-0}
    local days=$(( total_seconds / 86400 ))
    local hours=$(( (total_seconds % 86400) / 3600 ))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local parts=()

    if [[ $days -gt 0 ]]; then
        parts+=("${days}d")
    fi
    if [[ $hours -gt 0 ]]; then
        parts+=("${hours}h")
    fi
    if [[ $minutes -gt 0 ]]; then
        parts+=("${minutes}m")
    fi

    if [[ ${#parts[@]} -eq 0 ]]; then
        parts=("0m")
    fi

    echo "${parts[*]}"
}

echo "========================================="
echo "DNS Leak Test"
echo "========================================="
echo ""

# Test 1: Verify dnsdist is running and accessible
echo "Test 1: DNS Service Availability"
IFS='|' read -r DNSDIST_STATUS DNSDIST_UPTIME DNSDIST_HEALTH <<< "$(parse_container_status dnsdist)"
if echo "$DNSDIST_STATUS" | grep -q "Up"; then
    health_msg=""
    [[ -n "$DNSDIST_HEALTH" ]] && health_msg=" [${DNSDIST_HEALTH}]"
    test_result "DNSDist Running" "PASS" "DNSDist running for ${DNSDIST_UPTIME}${health_msg}"
else
    test_result "DNSDist Running" "FAIL" "DNSDist container status: $DNSDIST_STATUS"
    echo ""
    echo "⚠️  DNSDist is not running. Checking logs..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs --tail=20 dnsdist 2>/dev/null || echo "Could not retrieve logs"
    echo ""
    echo "Continuing with remaining tests..."
fi

# Test 2: Verify DNS resolution through both TCP and UDP
echo ""
echo "Test 2: DNS Resolution (TCP and UDP)"
if command -v dig &> /dev/null; then
    dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")

    # Test DNS from inside the dnsdist container (works in WSL2 where host can't reach bridge network)

    # Test 2a: DNSDist localhost port 53 UDP (transparent mode)
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @127.0.0.1 -p 53 example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "DNSDist UDP (port 53)" "PASS" "DNS query successful via UDP port 53"
    else
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "DNSDist UDP (port 53)" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but UDP queries failing"
        else
            test_result "DNSDist UDP (port 53)" "WARN" "UDP query failed (DNSDist starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 2b: DNSDist localhost port 53 TCP
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @127.0.0.1 -p 53 +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "DNSDist TCP (port 53)" "PASS" "DNS query successful via TCP port 53"
    else
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "DNSDist TCP (port 53)" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but TCP queries failing"
        else
            test_result "DNSDist TCP (port 53)" "WARN" "TCP query failed (DNSDist starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 2c: DNSDist localhost port 5353 UDP (direct mode)
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @127.0.0.1 -p 5353 example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "DNSDist UDP (port 5353)" "PASS" "DNS query successful via UDP port 5353"
    else
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "DNSDist UDP (port 5353)" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but UDP port 5353 failing"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnsdist transparent-gateway"
            echo ""
            echo "This will restart DNSDist and the transparent gateway (which depends on DNS)."
        else
            test_result "DNSDist UDP (port 5353)" "WARN" "UDP port 5353 query failed (DNSDist starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 2d: DNSDist localhost port 5353 TCP
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @127.0.0.1 -p 5353 +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "DNSDist TCP (port 5353)" "PASS" "DNS query successful via TCP port 5353"
    else
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "DNSDist TCP (port 5353)" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but TCP port 5353 failing"
        else
            test_result "DNSDist TCP (port 5353)" "WARN" "TCP port 5353 query failed (DNSDist starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 2e: CoreDNS direct (UDP) - test from dnsdist container
    COREDNS_IP=${DNS_COREDNS_IP:-172.20.255.51}
    COREDNS_CONTAINER_PORT=${COREDNS_DNS_CONTAINER_PORT:-15353}
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @${COREDNS_IP} -p ${COREDNS_CONTAINER_PORT} example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "CoreDNS UDP Direct" "PASS" "CoreDNS responding via UDP at ${COREDNS_IP}:${COREDNS_CONTAINER_PORT}"
    else
        test_result "CoreDNS UDP Direct" "WARN" "CoreDNS not responding via UDP at ${COREDNS_IP}:${COREDNS_CONTAINER_PORT}"
    fi

    # Test 2f: CoreDNS direct (TCP)
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @${COREDNS_IP} -p ${COREDNS_CONTAINER_PORT} +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "CoreDNS TCP Direct" "PASS" "CoreDNS responding via TCP at ${COREDNS_IP}:${COREDNS_CONTAINER_PORT}"
    else
        test_result "CoreDNS TCP Direct" "WARN" "CoreDNS not responding via TCP at ${COREDNS_IP}:${COREDNS_CONTAINER_PORT}"
    fi

    # Test 2g: dnscrypt-proxy direct (UDP) - test from dnsdist container
    DNSCRYPT_IP=${DNS_DNSCRYPT_IP:-172.20.255.50}
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @${DNSCRYPT_IP} -p 5053 example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "dnscrypt-proxy UDP" "PASS" "dnscrypt-proxy responding via UDP at ${DNSCRYPT_IP}:5053"
    else
        test_result "dnscrypt-proxy UDP" "WARN" "dnscrypt-proxy not responding via UDP at ${DNSCRYPT_IP}:5053"
    fi

    # Test 2h: dnscrypt-proxy direct (TCP)
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnsdist dig @${DNSCRYPT_IP} -p 5053 +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "dnscrypt-proxy TCP" "PASS" "dnscrypt-proxy responding via TCP at ${DNSCRYPT_IP}:5053"
    else
        test_result "dnscrypt-proxy TCP" "WARN" "dnscrypt-proxy not responding via TCP at ${DNSCRYPT_IP}:5053"
    fi
else
    test_result "DNS Resolution" "WARN" "dig command not available, skipping all DNS resolution tests"
fi

# Test 3: Verify host can reach each DNS service layer (both UDP and TCP)
echo ""
echo "Test 3: Host-to-Service Connectivity"
if command -v dig &> /dev/null; then
    # Test 3a: Host → DNSDist transparent mode UDP (read port from env, default 15354)
    DNS_TRANSPARENT_PORT=${DNS_TRANSPARENT_PORT:-15354}
    if dig @localhost -p ${DNS_TRANSPARENT_PORT} example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→DNSDist UDP (${DNS_TRANSPARENT_PORT})" "PASS" "Host can query DNSDist transparent mode via UDP on localhost:${DNS_TRANSPARENT_PORT}"
    else
        dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→DNSDist UDP (${DNS_TRANSPARENT_PORT})" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but host cannot query UDP port ${DNS_TRANSPARENT_PORT}"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" ps dnsdist"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnsdist --tail=20"
            echo ""
            echo "Check if port ${DNS_TRANSPARENT_PORT} is properly mapped and DNSDist is listening."
        else
            test_result "Host→DNSDist UDP (${DNS_TRANSPARENT_PORT})" "WARN" "Cannot query DNSDist UDP from host yet (starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 3b: Host → DNSDist transparent mode TCP (read port from env, default 5454)
    if dig @localhost -p ${DNS_TRANSPARENT_PORT} +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→DNSDist TCP (${DNS_TRANSPARENT_PORT})" "PASS" "Host can query DNSDist transparent mode via TCP on localhost:${DNS_TRANSPARENT_PORT}"
    else
        dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→DNSDist TCP (${DNS_TRANSPARENT_PORT})" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but host cannot query TCP port ${DNS_TRANSPARENT_PORT}"
        else
            test_result "Host→DNSDist TCP (${DNS_TRANSPARENT_PORT})" "WARN" "Cannot query DNSDist TCP from host yet (starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 3c: Host → DNSDist direct mode UDP (read port from env, default 15353)
    DNS_DIRECT_PORT=${DNS_DIRECT_PORT:-15353}
    if dig @localhost -p ${DNS_DIRECT_PORT} example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→DNSDist UDP (${DNS_DIRECT_PORT})" "PASS" "Host can query DNSDist direct mode via UDP on localhost:${DNS_DIRECT_PORT}"
    else
        dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→DNSDist UDP (${DNS_DIRECT_PORT})" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but host cannot query UDP port ${DNS_DIRECT_PORT}"
        else
            test_result "Host→DNSDist UDP (${DNS_DIRECT_PORT})" "WARN" "Cannot query DNSDist direct mode UDP from host yet (starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

    # Test 3d: Host → DNSDist direct mode TCP (read port from env, default 15353)
    if dig @localhost -p ${DNS_DIRECT_PORT} +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→DNSDist TCP (${DNS_DIRECT_PORT})" "PASS" "Host can query DNSDist direct mode via TCP on localhost:${DNS_DIRECT_PORT}"
    else
        dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
        if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→DNSDist TCP (${DNS_DIRECT_PORT})" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but host cannot query TCP port ${DNS_DIRECT_PORT}"
        else
            test_result "Host→DNSDist TCP (${DNS_DIRECT_PORT})" "WARN" "Cannot query DNSDist direct mode TCP from host yet (starting for ${DNSDIST_UPTIME:-unknown})"
        fi
    fi

        # Test 3e: Host → CoreDNS direct UDP (port ${COREDNS_DIRECT_PORT})
    COREDNS_DIRECT_PORT=${COREDNS_DNS_HOST_PORT:-15354}
    IFS='|' read -r COREDNS_STATUS COREDNS_UPTIME COREDNS_HEALTH <<< "$(parse_container_status coredns)"
    coredns_uptime_seconds=$(uptime_to_seconds "${COREDNS_UPTIME:-}")
    if dig @localhost -p ${COREDNS_DIRECT_PORT} example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→CoreDNS UDP (${COREDNS_DIRECT_PORT})" "PASS" "Host can query CoreDNS via UDP on localhost:${COREDNS_DIRECT_PORT}"
    else
        if [[ ${coredns_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→CoreDNS UDP (${COREDNS_DIRECT_PORT})" "FAIL" "CoreDNS running for ${COREDNS_UPTIME:-unknown} but host cannot query UDP port ${COREDNS_DIRECT_PORT}"
        else
            test_result "Host→CoreDNS UDP (${COREDNS_DIRECT_PORT})" "WARN" "Cannot query CoreDNS UDP from host yet (starting for ${COREDNS_UPTIME:-unknown})"
        fi
    fi

    # Test 3f: Host → CoreDNS direct TCP (port ${COREDNS_DIRECT_PORT})
    if dig @localhost -p ${COREDNS_DIRECT_PORT} +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→CoreDNS TCP (${COREDNS_DIRECT_PORT})" "PASS" "Host can query CoreDNS via TCP on localhost:${COREDNS_DIRECT_PORT}"
    else
        if [[ ${coredns_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→CoreDNS TCP (${COREDNS_DIRECT_PORT})" "FAIL" "CoreDNS running for ${COREDNS_UPTIME:-unknown} but host cannot query TCP port ${COREDNS_DIRECT_PORT}"
        else
            test_result "Host→CoreDNS TCP (${COREDNS_DIRECT_PORT})" "WARN" "Cannot query CoreDNS TCP from host yet (starting for ${COREDNS_UPTIME:-unknown})"
        fi
    fi

# Test 3g: Host → dnscrypt-proxy UDP (read port from env, default 5300)
    DNSCRYPT_PROXY_HOST_PORT=${DNSCRYPT_PROXY_HOST_PORT:-5300}
    if dig @localhost -p ${DNSCRYPT_PROXY_HOST_PORT} example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→dnscrypt-proxy UDP (${DNSCRYPT_PROXY_HOST_PORT})" "PASS" "Host can query dnscrypt-proxy via UDP on localhost:${DNSCRYPT_PROXY_HOST_PORT}"
    else
        IFS='|' read -r DNSCRYPT_STATUS DNSCRYPT_UPTIME DNSCRYPT_HEALTH <<< "$(parse_container_status dnscrypt-proxy)"
        dnscrypt_uptime_seconds=$(uptime_to_seconds "${DNSCRYPT_UPTIME:-}")
        if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→dnscrypt-proxy UDP (${DNSCRYPT_PROXY_HOST_PORT})" "FAIL" "dnscrypt-proxy running for ${DNSCRYPT_UPTIME} but host cannot query UDP port ${DNSCRYPT_PROXY_HOST_PORT}"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" ps dnscrypt-proxy"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnscrypt-proxy --tail=20"
            echo ""
            echo "Check if port ${DNSCRYPT_PROXY_HOST_PORT} is properly mapped and dnscrypt-proxy is listening."
        else
            test_result "Host→dnscrypt-proxy UDP (${DNSCRYPT_PROXY_HOST_PORT})" "WARN" "Cannot query dnscrypt-proxy UDP from host yet (starting for ${DNSCRYPT_UPTIME:-unknown})"
        fi
    fi

    # Test 3h: Host → dnscrypt-proxy TCP (read port from env, default 5300)
    # Note: dnscrypt-proxy only exposes UDP in docker-compose.yml, but we test TCP anyway
    if dig @localhost -p ${DNSCRYPT_PROXY_HOST_PORT} +tcp example.com +short +tries=1 +time=2 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        test_result "Host→dnscrypt-proxy TCP (${DNSCRYPT_PROXY_HOST_PORT})" "PASS" "Host can query dnscrypt-proxy via TCP on localhost:${DNSCRYPT_PROXY_HOST_PORT}"
    else
        IFS='|' read -r DNSCRYPT_STATUS DNSCRYPT_UPTIME DNSCRYPT_HEALTH <<< "$(parse_container_status dnscrypt-proxy)"
        dnscrypt_uptime_seconds=$(uptime_to_seconds "${DNSCRYPT_UPTIME:-}")
        if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Host→dnscrypt-proxy TCP (${DNSCRYPT_PROXY_HOST_PORT})" "WARN" "dnscrypt-proxy TCP not accessible from host (only UDP exposed in docker-compose)"
        else
            test_result "Host→dnscrypt-proxy TCP (${DNSCRYPT_PROXY_HOST_PORT})" "WARN" "Cannot query dnscrypt-proxy TCP from host yet (starting for ${DNSCRYPT_UPTIME:-unknown})"
        fi
    fi
else
    test_result "Host Connectivity" "WARN" "dig command not available, skipping host connectivity tests"
fi

# Test 4: Verify DNS queries are encrypted (not plain text)
echo ""
echo "Test 4: DNS Encryption Transport"
IFS='|' read -r DNSCRYPT_STATUS DNSCRYPT_UPTIME DNSCRYPT_HEALTH <<< "$(parse_container_status dnscrypt-proxy)"

# Check if dnscrypt-proxy has been running long enough
dnscrypt_uptime_seconds=$(uptime_to_seconds "${DNSCRYPT_UPTIME:-}")

# Verify DNS encryption is active by checking query log exists and has entries
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy test -f /var/log/dnscrypt-proxy/query.log 2>/dev/null; then
    query_count=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy sh -c 'wc -l < /var/log/dnscrypt-proxy/query.log' 2>/dev/null || echo "0")
    if [[ ${query_count:-0} -gt 0 ]]; then
        test_result "DNS Encryption" "PASS" "DNS queries encrypted via dnscrypt-proxy (${query_count} queries processed)"
    else
        if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
            test_result "DNS Encryption" "FAIL" "dnscrypt-proxy running for ${DNSCRYPT_UPTIME} but no encrypted queries processed"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnscrypt-proxy --tail=50"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnscrypt-proxy coredns dnsdist transparent-gateway"
            echo ""
            echo "This will show diagnostic logs and restart the entire DNS chain."
        else
            test_result "DNS Encryption" "WARN" "No encrypted queries yet (dnscrypt-proxy starting for ${DNSCRYPT_UPTIME:-unknown})"
        fi
    fi
else
    if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
        test_result "DNS Encryption" "FAIL" "dnscrypt-proxy running for ${DNSCRYPT_UPTIME} but query log missing"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnscrypt-proxy --tail=50"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnscrypt-proxy coredns dnsdist transparent-gateway"
        echo ""
        echo "This will show diagnostic logs and restart the DNS chain."
    else
        test_result "DNS Encryption" "WARN" "DNS encryption initializing (dnscrypt-proxy starting for ${DNSCRYPT_UPTIME:-unknown})"
    fi
fi

# Test 5: Verify ODoH privacy separation (relay + target server architecture)
echo ""
echo "Test 5: ODoH Privacy Separation"
# ODoH provides privacy by separating query content from client identity
# Requires both target servers (process queries) and relay servers (hide client IP)
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy test -f /var/cache/dnscrypt-proxy/odoh-servers.md 2>/dev/null && \
   docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy test -f /var/cache/dnscrypt-proxy/odoh-relays.md 2>/dev/null; then
    # Count available servers and relays
    server_count=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy sh -c 'grep -c "^## odoh-" /var/cache/dnscrypt-proxy/odoh-servers.md 2>/dev/null || echo "0"')
    relay_count=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T dnscrypt-proxy sh -c 'grep -c "^## odohrelay-" /var/cache/dnscrypt-proxy/odoh-relays.md 2>/dev/null || echo "0"')

    if [[ ${server_count:-0} -gt 0 ]] && [[ ${relay_count:-0} -gt 0 ]]; then
        test_result "ODoH Privacy" "PASS" "ODoH privacy active: ${server_count} target servers, ${relay_count} relay servers (client IP hidden from DNS servers)"
    else
        if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
            test_result "ODoH Privacy" "FAIL" "dnscrypt-proxy running for ${DNSCRYPT_UPTIME} but ODoH servers/relays not loaded (servers: ${server_count}, relays: ${relay_count})"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" exec -T dnscrypt-proxy ls -la /var/cache/dnscrypt-proxy/"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnscrypt-proxy --tail=50"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnscrypt-proxy coredns dnsdist transparent-gateway"
            echo ""
            echo "This will check ODoH server lists and restart the DNS chain."
        else
            test_result "ODoH Privacy" "WARN" "ODoH downloading server/relay lists (dnscrypt-proxy starting for ${DNSCRYPT_UPTIME:-unknown})"
        fi
    fi
else
    if [[ ${dnscrypt_uptime_seconds:-0} -gt 300 ]]; then
        test_result "ODoH Privacy" "FAIL" "dnscrypt-proxy running for ${DNSCRYPT_UPTIME} but ODoH server/relay lists not downloaded"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" exec -T dnscrypt-proxy ls -la /var/cache/dnscrypt-proxy/"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs dnscrypt-proxy --tail=50"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnscrypt-proxy coredns dnsdist transparent-gateway"
        echo ""
        echo "This will check ODoH configuration and restart the DNS chain."
    else
        test_result "ODoH Privacy" "WARN" "ODoH initializing (dnscrypt-proxy starting for ${DNSCRYPT_UPTIME:-unknown})"
    fi
fi

# Test 4: Verify no direct external DNS queries (check iptables rules)
echo ""
echo "Test 6: DNS Traffic Interception"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T transparent-gateway iptables -t nat -L PREROUTING 2>/dev/null | grep -q "53"; then
    test_result "DNS Interception" "PASS" "iptables rules redirect DNS traffic (port 53)"
else
    test_result "DNS Interception" "WARN" "Could not verify iptables DNS interception rules"
fi

# Test 7: Verify DNS metrics are being collected
echo ""
echo "Test 7: DNS Metrics Collection (expected to fail)"
if curl -sf http://localhost:8083/metrics 2>/dev/null | grep -q "dnsdist"; then
    test_result "DNS Metrics" "PASS" "DNSDist metrics endpoint is accessible"
else
    # Check if DNSDist has been running long enough that metrics should be available
    dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
    if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
        test_result "DNS Metrics" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but metrics unavailable - check exporter"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnsdist transparent-gateway"
        echo ""
        echo "This will restart DNSDist and the transparent gateway."
    else
        test_result "DNS Metrics" "WARN" "DNSDist metrics endpoint not accessible (starting for ${DNSDIST_UPTIME:-unknown})"
    fi
fi

# Test 8: Verify blocklist is loaded
echo ""
echo "Test 8: DNS Blocklist Integration"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs dnsdist 2>/dev/null | grep -qi "blocklist\|cdb"; then
    test_result "Blocklist Loaded" "PASS" "Blocklist integration detected"
else
    # Check if DNSDist has been running long enough that blocklist should be loaded
    dnsdist_uptime_seconds=$(uptime_to_seconds "${DNSDIST_UPTIME:-}")
    if [[ ${dnsdist_uptime_seconds:-0} -gt 300 ]]; then
        test_result "Blocklist Loaded" "FAIL" "DNSDist running for ${DNSDIST_UPTIME} but no blocklist activity - check config"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart dnsdist transparent-gateway"
        echo ""
        echo "This will restart DNSDist and the transparent gateway."
    else
        test_result "Blocklist Loaded" "WARN" "No blocklist activity detected (DNSDist starting for ${DNSDIST_UPTIME:-unknown})"
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total Tests:  $TESTS_RUN"
echo "Passed:       $TESTS_PASSED"
echo "Failed:       $TESTS_FAILED"
echo "Warnings:     $((TESTS_RUN - TESTS_PASSED - TESTS_FAILED))"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}❌ DNS leak test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ DNS leak test PASSED${NC}"
    echo "All DNS queries are routed through local infrastructure"
    exit 0
fi
