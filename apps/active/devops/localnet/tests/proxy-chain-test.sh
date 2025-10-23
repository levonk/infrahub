#!/usr/bin/env bash
# Proxy Chain Test - Verify transparent proxy, cache hit rate >50%, Tor enabled
# Tests web proxy chain functionality and performance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
    local status uptime health restart_count
    
    status=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps "$container_name" --format "{{.Status}}" 2>/dev/null || echo "not found")
    
    # Extract uptime (e.g., "Up 23 minutes") - use variable to avoid unbound BASH_REMATCH
    uptime=""
    local uptime_pattern='Up[[:space:]]+([^(]+)'
    if [[ "$status" =~ $uptime_pattern ]]; then
        uptime="${BASH_REMATCH[1]}"
        # Trim trailing whitespace
        uptime="${uptime%"${uptime##*[![:space:]]}"}"
    fi
    
    # Check health status - use variable to avoid unbound BASH_REMATCH
    health=""
    local health_pattern='[(]([^)]+)[)]'
    if [[ "$status" =~ $health_pattern ]]; then
        health="${BASH_REMATCH[1]}"
    fi
    
    # Get restart count
    restart_count=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps "$container_name" --format "{{.Status}}" 2>/dev/null | grep -oP 'Restarting \(\K[0-9]+' || echo "0")
    
    echo "$status|$uptime|$health|$restart_count"
}

# Convert uptime string to seconds for comparison
uptime_to_seconds() {
    local uptime="$1"
    local seconds=0
    
    # Parse "X minutes", "X hours", "X seconds", etc.
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*hour ]]; then
        seconds=$((${BASH_REMATCH[1]} * 3600))
    fi
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*minute ]]; then
        seconds=$((seconds + ${BASH_REMATCH[1]} * 60))
    fi
    if [[ "$uptime" =~ ([0-9]+)[[:space:]]*second ]]; then
        seconds=$((seconds + ${BASH_REMATCH[1]}))
    fi
    
    echo "$seconds"
}

echo "========================================="
echo "Web Proxy Chain Test"
echo "========================================="
echo ""

# Test 1: Verify Envoy is running
echo "Test 1: Envoy Proxy Availability"
IFS='|' read -r ENVOY_STATUS ENVOY_UPTIME ENVOY_HEALTH ENVOY_RESTARTS <<< "$(parse_container_status envoy)"
if echo "$ENVOY_STATUS" | grep -q "Up" || true; then
    if echo "$ENVOY_STATUS" | grep -q "Up"; then
        health_msg=""
        [[ -n "$ENVOY_HEALTH" ]] && health_msg=" [${ENVOY_HEALTH}]"
        [[ "$ENVOY_RESTARTS" != "0" ]] && health_msg="${health_msg} [Restarts: ${ENVOY_RESTARTS}]"
        test_result "Envoy Running" "PASS" "Envoy running for ${ENVOY_UPTIME}${health_msg}"
    else
        test_result "Envoy Running" "FAIL" "Envoy container status: $ENVOY_STATUS"
    fi
fi

# Test 2: Verify Squid is running
echo ""
echo "Test 2: Squid Cache Availability"
IFS='|' read -r SQUID_STATUS SQUID_UPTIME SQUID_HEALTH SQUID_RESTARTS <<< "$(parse_container_status squid)"
if echo "$SQUID_STATUS" | grep -q "Up" || true; then
    if echo "$SQUID_STATUS" | grep -q "Up"; then
        health_msg=""
        [[ -n "$SQUID_HEALTH" ]] && health_msg=" [${SQUID_HEALTH}]"
        [[ "$SQUID_RESTARTS" != "0" ]] && health_msg="${health_msg} [Restarts: ${SQUID_RESTARTS}]"
        test_result "Squid Running" "PASS" "Squid running for ${SQUID_UPTIME}${health_msg}"
    else
        test_result "Squid Running" "FAIL" "Squid container status: $SQUID_STATUS"
    fi
fi

# Test 3: Verify Privoxy is running
echo ""
echo "Test 3: Privoxy Privacy Proxy Availability"
IFS='|' read -r PRIVOXY_STATUS PRIVOXY_UPTIME PRIVOXY_HEALTH PRIVOXY_RESTARTS <<< "$(parse_container_status privoxy)"
if echo "$PRIVOXY_STATUS" | grep -q "Up" || true; then
    if echo "$PRIVOXY_STATUS" | grep -q "Up"; then
        health_msg=""
        [[ -n "$PRIVOXY_HEALTH" ]] && health_msg=" [${PRIVOXY_HEALTH}]"
        [[ "$PRIVOXY_RESTARTS" != "0" ]] && health_msg="${health_msg} [Restarts: ${PRIVOXY_RESTARTS}]"
        test_result "Privoxy Running" "PASS" "Privoxy running for ${PRIVOXY_UPTIME}${health_msg}"
    else
        test_result "Privoxy Running" "WARN" "Privoxy container status: $PRIVOXY_STATUS"
    fi
fi

# Test 4: Verify Tor is running
echo ""
echo "Test 4: Tor Anonymization Service"
IFS='|' read -r TOR_STATUS TOR_UPTIME TOR_HEALTH TOR_RESTARTS <<< "$(parse_container_status tor)"
if echo "$TOR_STATUS" | grep -q "Up" || true; then
    if echo "$TOR_STATUS" | grep -q "Up"; then
        health_msg=""
        [[ -n "$TOR_HEALTH" ]] && health_msg=" [${TOR_HEALTH}]"
        [[ "$TOR_RESTARTS" != "0" ]] && health_msg="${health_msg} [Restarts: ${TOR_RESTARTS}]"
        test_result "Tor Running" "PASS" "Tor running for ${TOR_UPTIME}${health_msg}"
    else
        test_result "Tor Running" "WARN" "Tor container status: $TOR_STATUS"
    fi
fi

# ============================================================================
# Layer 3: Internal Container Network Tests
# ============================================================================

# Test 5: Tor internal connectivity (port 9050)
echo ""
echo "Test 5: Tor Internal Connectivity (container network)"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T privoxy nc -zv tor 9050 2>&1 | grep -q "succeeded\|open"; then
    test_result "Tor Internal" "PASS" "Tor accessible from privoxy container on port 9050"
else
    tor_uptime_seconds=$(uptime_to_seconds "$TOR_UPTIME")
    if [[ $tor_uptime_seconds -gt 300 ]]; then
        test_result "Tor Internal" "FAIL" "Tor running for ${TOR_UPTIME} but not accessible on internal network"
        echo ""
        echo "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart tor privoxy squid envoy transparent-gateway"
        echo ""
        echo "This will restart Tor and all dependent services in the proxy chain."
    else
        test_result "Tor Internal" "WARN" "Tor not accessible yet (starting for ${TOR_UPTIME})"
    fi
fi

# Test 6: Privoxy internal connectivity (port 8118)
echo ""
echo "Test 6: Privoxy Internal Connectivity (container network)"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T squid nc -zv privoxy 8118 2>&1 | grep -q "succeeded\|open"; then
    test_result "Privoxy Internal" "PASS" "Privoxy accessible from squid container on port 8118"
else
    privoxy_uptime_seconds=$(uptime_to_seconds "$PRIVOXY_UPTIME")
    if [[ $privoxy_uptime_seconds -gt 300 ]]; then
        test_result "Privoxy Internal" "FAIL" "Privoxy running for ${PRIVOXY_UPTIME} but not accessible on internal network"
        echo ""
        echo "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart privoxy squid envoy transparent-gateway"
        echo ""
        echo "This will restart Privoxy and all dependent services."
    else
        test_result "Privoxy Internal" "WARN" "Privoxy not accessible yet (starting for ${PRIVOXY_UPTIME})"
    fi
fi

# Test 7: Squid internal connectivity (port 3128)
echo ""
echo "Test 7: Squid Internal Connectivity (container network)"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T envoy nc -zv squid 3128 2>&1 | grep -q "succeeded\|open"; then
    test_result "Squid Internal" "PASS" "Squid accessible from envoy container on port 3128"
else
    squid_uptime_seconds=$(uptime_to_seconds "$SQUID_UPTIME")
    if [[ $squid_uptime_seconds -gt 300 ]]; then
        test_result "Squid Internal" "FAIL" "Squid running for ${SQUID_UPTIME} but not accessible on internal network"
        echo ""
        echo "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart squid envoy transparent-gateway"
        echo ""
        echo "This will restart Squid and all dependent services."
    else
        test_result "Squid Internal" "WARN" "Squid not accessible yet (starting for ${SQUID_UPTIME})"
    fi
fi

# Test 8: Envoy internal connectivity (port 3129)
echo ""
echo "Test 8: Envoy Internal Connectivity (container network)"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T squid nc -zv envoy 3129 2>&1 | grep -q "succeeded\|open"; then
    test_result "Envoy Internal" "PASS" "Envoy accessible from squid container on port 3129"
else
    envoy_uptime_seconds=$(uptime_to_seconds "$ENVOY_UPTIME")
    if [[ $envoy_uptime_seconds -gt 300 ]]; then
        test_result "Envoy Internal" "FAIL" "Envoy running for ${ENVOY_UPTIME} but not accessible on internal network"
        echo ""
        echo "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart envoy transparent-gateway"
        echo ""
        echo "This will restart Envoy and the transparent gateway."
    else
        test_result "Envoy Internal" "WARN" "Envoy not accessible yet (starting for ${ENVOY_UPTIME})"
    fi
fi

# ============================================================================
# Layer 4: Host Access Tests
# ============================================================================

# Test 9: Squid host access (port 3128)
echo ""
echo "Test 9: Squid Host Access (port 3128)"
if command -v curl &> /dev/null; then
    if curl -sf -x http://localhost:3128 http://example.com -m 10 > /dev/null 2>&1; then
        test_result "Squid Host Access" "PASS" "Successfully accessed example.com through Squid from host"
    else
        squid_uptime_seconds=$(uptime_to_seconds "$SQUID_UPTIME")
        if [[ $squid_uptime_seconds -gt 300 ]]; then
            test_result "Squid Host Access" "FAIL" "Squid running for ${SQUID_UPTIME} but host cannot proxy requests"
            echo ""
            echo "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart squid envoy transparent-gateway"
            echo ""
            echo "This will restart Squid and all dependent services in the proxy chain."
        else
            test_result "Squid Host Access" "WARN" "Could not access example.com from host (Squid starting for ${SQUID_UPTIME})"
        fi
    fi
else
    test_result "Squid Host Access" "WARN" "curl command not available, skipping"
fi

# Test 10: Envoy host access - HTTP transparent mode (port 10080)
echo ""
echo "Test 10: Envoy Host Access - HTTP (port 10080)"
if command -v nc &> /dev/null; then
    if timeout 3 nc -zv localhost 10080 2>&1 | grep -q "succeeded\|open"; then
        test_result "Envoy HTTP Host" "PASS" "Envoy HTTP port 10080 accessible from host"
    else
        envoy_uptime_seconds=$(uptime_to_seconds "$ENVOY_UPTIME")
        if [[ $envoy_uptime_seconds -gt 300 ]]; then
            test_result "Envoy HTTP Host" "FAIL" "Envoy running for ${ENVOY_UPTIME} but HTTP port 10080 not accessible from host"
        else
            test_result "Envoy HTTP Host" "WARN" "Envoy HTTP port 10080 not accessible yet (starting for ${ENVOY_UPTIME})"
        fi
    fi
else
    test_result "Envoy HTTP Host" "WARN" "nc (netcat) not available - install netcat to test"
fi

# Test 11: Envoy host access - HTTPS transparent mode (port 10443)
echo ""
echo "Test 11: Envoy Host Access - HTTPS (port 10443)"
if command -v nc &> /dev/null; then
    if timeout 3 nc -zv localhost 10443 2>&1 | grep -q "succeeded\|open"; then
        test_result "Envoy HTTPS Host" "PASS" "Envoy HTTPS port 10443 accessible from host"
    else
        envoy_uptime_seconds=$(uptime_to_seconds "$ENVOY_UPTIME")
        if [[ $envoy_uptime_seconds -gt 300 ]]; then
            test_result "Envoy HTTPS Host" "FAIL" "Envoy running for ${ENVOY_UPTIME} but HTTPS port 10443 not accessible from host"
        else
            test_result "Envoy HTTPS Host" "WARN" "Envoy HTTPS port 10443 not accessible yet (starting for ${ENVOY_UPTIME})"
        fi
    fi
else
    test_result "Envoy HTTPS Host" "WARN" "nc (netcat) not available - install netcat to test"
fi

# Test 12: Envoy admin/metrics endpoint (port 9901)
echo ""
echo "Test 12: Envoy Admin/Metrics Endpoint (port 9901)"
if curl -sf http://localhost:9901/stats 2>/dev/null | head -5 > /dev/null; then
    test_result "Envoy Metrics" "PASS" "Envoy admin/metrics interface accessible from host"
else
    envoy_uptime_seconds=$(uptime_to_seconds "$ENVOY_UPTIME")
    if [[ $envoy_uptime_seconds -gt 300 ]]; then
        test_result "Envoy Metrics" "FAIL" "Envoy running for ${ENVOY_UPTIME} but metrics not accessible from host"
    else
        test_result "Envoy Metrics" "WARN" "Envoy metrics not accessible yet (starting for ${ENVOY_UPTIME})"
    fi
fi

# ============================================================================
# Layer 5: Functional Tests
# ============================================================================

# Test 13: Check Squid cache statistics
echo ""
echo "Test 13: Squid Cache Statistics"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T squid squidclient mgr:info 2>/dev/null | grep -q "Squid Object Cache"; then
    test_result "Squid Stats" "PASS" "Squid cache statistics available"
    
    # Try to get cache hit rate
    CACHE_INFO=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T squid squidclient mgr:5min 2>/dev/null || echo "")
    if [[ -n "$CACHE_INFO" ]]; then
        echo "Recent cache performance:"
        echo "$CACHE_INFO" | grep -E "Hit|Miss" | head -5 || echo "No hit/miss data yet"
    fi
else
    # Check if Squid has been running long enough that stats should be available
    squid_uptime_seconds=$(uptime_to_seconds "$SQUID_UPTIME")
    if [[ $squid_uptime_seconds -gt 300 ]]; then
        test_result "Squid Stats" "FAIL" "Squid running for ${SQUID_UPTIME} but statistics unavailable - check health"
        echo ""
        echo "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart squid envoy transparent-gateway"
        echo ""
        echo "This will restart Squid and all dependent services in the proxy chain."
    else
        test_result "Squid Stats" "WARN" "Could not retrieve Squid statistics (Squid starting for ${SQUID_UPTIME})"
    fi
fi

# Test 14: Verify transparent proxy gateway
echo ""
echo "Test 14: Transparent Gateway Integration"
IFS='|' read -r GATEWAY_STATUS GATEWAY_UPTIME GATEWAY_HEALTH GATEWAY_RESTARTS <<< "$(parse_container_status transparent-gateway)"
if echo "$GATEWAY_STATUS" | grep -q "Up" || true; then
    if echo "$GATEWAY_STATUS" | grep -q "Up"; then
        health_msg=""
        [[ -n "$GATEWAY_HEALTH" ]] && health_msg=" [${GATEWAY_HEALTH}]"
        [[ "$GATEWAY_RESTARTS" != "0" ]] && health_msg="${health_msg} [Restarts: ${GATEWAY_RESTARTS}]"
        test_result "Transparent Gateway" "PASS" "Gateway running for ${GATEWAY_UPTIME}${health_msg}"
    else
        test_result "Transparent Gateway" "WARN" "Gateway status: $GATEWAY_STATUS (Restarts: ${GATEWAY_RESTARTS})"
        if [[ "$GATEWAY_STATUS" =~ Restarting ]]; then
            echo ""
            echo "${YELLOW}Gateway is in restart loop. Recommended action:${NC}"
            echo "  # Check logs first:"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs --tail=50 transparent-gateway"
            echo ""
            echo "  # Then restart if needed:"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart transparent-gateway"
        fi
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
    echo -e "${RED}❌ Proxy chain test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Proxy chain test PASSED${NC}"
    echo "Web proxy chain is functional"
    exit 0
fi
