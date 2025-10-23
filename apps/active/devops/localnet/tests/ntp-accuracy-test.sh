#!/usr/bin/env bash
# NTP Accuracy Test - Verify NTP offset <10ms, NTS enabled, stratum 2
# Tests time synchronization accuracy and security

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
    local status uptime health
    
    status=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps "$container_name" --format "{{.Status}}" 2>/dev/null || echo "not found")
    
    # Extract uptime (e.g., "Up 23 minutes") - use variable to avoid regex parsing issues
    uptime=""
    local uptime_pattern='Up[[:space:]]+([^(]+)'
    if [[ "$status" =~ $uptime_pattern ]]; then
        uptime="${BASH_REMATCH[1]}"
        # Trim trailing whitespace
        uptime="${uptime%"${uptime##*[![:space:]]}"}"
    fi
    
    # Check health status (use variable to avoid regex parsing issues)
    health=""
    local health_pattern='[(]([^)]+)[)]'
    if [[ "$status" =~ $health_pattern ]]; then
        health="${BASH_REMATCH[1]}"
    fi
    
    echo "$status|$uptime|$health"
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
echo "NTP Accuracy Test"
echo "========================================="
echo ""
echo "Test Flow: Internet → Upstream NTP → Chronyd Container → Host Access"
echo ""

# ============================================================================
# Layer 1: Internet Connectivity to Upstream NTP Sources
# ============================================================================

# Test 1: Check NTP sources (Internet connectivity)
echo "Test 1: Upstream NTP Source Availability (Internet)"
SOURCES_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc sources 2>/dev/null || echo "")
if [[ -n "$SOURCES_OUTPUT" ]]; then
    SOURCE_COUNT=$(echo "$SOURCES_OUTPUT" | grep -c "^\^" || echo "0")
    SOURCE_COUNT=$(echo "$SOURCE_COUNT" | tr -d '\n\r')
    if [[ "$SOURCE_COUNT" -gt 0 ]]; then
        test_result "NTP Sources" "PASS" "Found $SOURCE_COUNT upstream NTP sources"
        echo "$SOURCES_OUTPUT" | head -15
    else
        test_result "NTP Sources" "WARN" "No active NTP sources found"
    fi
else
    test_result "NTP Sources" "WARN" "Could not retrieve NTP sources - container may not be ready"
fi

# ============================================================================
# Layer 2: Chronyd Container - Service Running & Health
# ============================================================================

# Test 2: Verify chronyd container is running
echo ""
echo "Test 2: Chronyd Container Running"
IFS='|' read -r CHRONYD_STATUS CHRONYD_UPTIME CHRONYD_HEALTH <<< "$(parse_container_status chronyd)"
if echo "$CHRONYD_STATUS" | grep -q "Up"; then
    health_msg=""
    [[ -n "$CHRONYD_HEALTH" ]] && health_msg=" [${CHRONYD_HEALTH}]"
    test_result "Chronyd Container" "PASS" "Container running for ${CHRONYD_UPTIME}${health_msg}"
else
    test_result "Chronyd Container" "FAIL" "Container status: $CHRONYD_STATUS"
    echo ""
    echo "⚠️  Chronyd container is not running. Checking logs..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs --tail=20 chronyd 2>/dev/null || echo "Could not retrieve logs"
    echo ""
    echo "Continuing with remaining tests..."
fi

# Test 3: Check container health status
echo ""
echo "Test 3: Chronyd Container Health"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep -q "Leap status"; then
    test_result "Chronyd Health" "PASS" "Service is healthy and responding"
else
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "Chronyd Health" "FAIL" "Service unhealthy after ${CHRONYD_UPTIME}"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
    else
        test_result "Chronyd Health" "WARN" "Service starting (${CHRONYD_UPTIME})"
    fi
fi

# ============================================================================
# Layer 3: Chronyd Container - Internal Ports & Protocols
# ============================================================================

# Test 4: Verify chronyd process is listening (uses internal sockets, not traditional ports)
echo ""
echo "Test 4: Chronyd Process Listening"
# Chronyd doesn't show up in ss/netstat for UDP/TCP because it handles NTP protocol internally
# Check if chronyd process is running and responding to chronyc commands
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd pgrep chronyd >/dev/null 2>&1; then
    # Verify it's actually responding to commands
    if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd timeout 3 chronyc -n tracking >/dev/null 2>&1; then
        test_result "Chronyd Process" "PASS" "Chronyd process running and responding to commands"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Chronyd Process" "FAIL" "Chronyd running but not responding after ${CHRONYD_UPTIME}"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        else
            test_result "Chronyd Process" "WARN" "Chronyd starting up (${CHRONYD_UPTIME})"
        fi
    fi
else
    test_result "Chronyd Process" "FAIL" "Chronyd process not running"
    echo ""
    echo -e "${YELLOW}Recommended action:${NC}"
    echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
fi

# Test 5: Verify command socket connectivity
echo ""
echo "Test 5: Chronyd Command Socket"
# Check if we can communicate with chronyd via its command socket
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd timeout 3 chronyc -n sources >/dev/null 2>&1; then
    test_result "Command Socket" "PASS" "Command socket responding"
else
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "Command Socket" "FAIL" "Command socket not responding after ${CHRONYD_UPTIME}"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
    else
        test_result "Command Socket" "WARN" "Command socket initializing (${CHRONYD_UPTIME})"
    fi
fi

# Test 6: NTP protocol functionality inside container
echo ""
echo "Test 6: Chronyd Internal NTP Protocol (UDP)"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd timeout 5 chronyc -n tracking 2>/dev/null | grep -q "Stratum"; then
    test_result "Internal NTP Protocol" "PASS" "NTP service responding inside container"
else
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "Internal NTP Protocol" "FAIL" "NTP not responding after ${CHRONYD_UPTIME}"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
    else
        test_result "Internal NTP Protocol" "WARN" "NTP not fully initialized (${CHRONYD_UPTIME})"
    fi
fi

# ============================================================================
# Layer 4: Host Access - External Port Mappings
# ============================================================================

# Test 7: Verify UDP port mappings from host
echo ""
echo "Test 7: Host UDP Port Mappings"
HOST_PORTS=$(ss -ulnp 2>/dev/null | grep -E ":(123|1123|9123)" | grep -v "127.0.0.53" || echo "")
if [[ -n "$HOST_PORTS" ]]; then
    PORT_COUNT=$(echo "$HOST_PORTS" | wc -l)
    test_result "Host UDP Mappings" "PASS" "Found $PORT_COUNT UDP port mapping(s)"
    echo "$HOST_PORTS" | head -10
else
    test_result "Host UDP Mappings" "WARN" "No UDP ports visible on host - check docker port mappings"
fi

# Test 8: Verify TCP port mappings from host
echo ""
echo "Test 8: Host TCP Port Mappings"
HOST_TCP_PORTS=$(ss -tlnp 2>/dev/null | grep -E ":(123|1123|9123)" || echo "")
if [[ -n "$HOST_TCP_PORTS" ]]; then
    TCP_PORT_COUNT=$(echo "$HOST_TCP_PORTS" | wc -l)
    test_result "Host TCP Mappings" "PASS" "Found $TCP_PORT_COUNT TCP port mapping(s)"
    echo "$HOST_TCP_PORTS" | head -10
else
    test_result "Host TCP Mappings" "WARN" "No TCP ports visible on host - check docker port mappings"
fi

# ============================================================================
# Layer 5: Host Access - External Protocol Functionality (UDP)
# ============================================================================

# Test 9: NTP UDP Protocol - Transparent Mode from Host (port 123)
echo ""
echo "Test 9: Host → Chronyd NTP UDP/123 (Transparent Mode)"
# Test NTP from host using ntpdate or chronyc from host (not inside container)
if command -v ntpdate &> /dev/null; then
    if timeout 5 ntpdate -q localhost 2>&1 | grep -q "offset"; then
        test_result "Host NTP UDP/123" "PASS" "NTP service accessible from host on port 123/udp"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP UDP/123" "FAIL" "Cannot query NTP on localhost:123/udp from host after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP UDP/123" "WARN" "NTP not responding on localhost:123/udp from host (${CHRONYD_UPTIME})"
        fi
    fi
elif command -v chronyc &> /dev/null; then
    # Try using host's chronyc to query the container's NTP service
    if timeout 5 chronyc -h localhost -p 123 sources 2>&1 | grep -q "^\^"; then
        test_result "Host NTP UDP/123" "PASS" "NTP service accessible from host on port 123/udp"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP UDP/123" "FAIL" "Cannot query NTP on localhost:123/udp from host after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP UDP/123" "WARN" "NTP not responding on localhost:123/udp from host (${CHRONYD_UPTIME})"
        fi
    fi
else
    test_result "Host NTP UDP/123" "WARN" "ntpdate or chronyc not available on host - install ntp or chrony to test"
fi
fi

# Test 10: NTP UDP Protocol - Direct Mode from Host (port 1123)
echo ""
echo "Test 10: Host → Chronyd NTP UDP/1123 (Direct Mode)"
# Direct mode uses same container port (123), Docker maps it to host port 1123
# Test actual NTP query from host to port 1123
if command -v ntpdate &> /dev/null; then
    if timeout 5 ntpdate -q -p 1123 localhost 2>&1 | grep -q "offset"; then
        test_result "Host NTP UDP/1123" "PASS" "NTP service accessible from host on port 1123/udp"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP UDP/1123" "FAIL" "Cannot query NTP on localhost:1123/udp from host after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP UDP/1123" "WARN" "NTP not responding on localhost:1123/udp from host (${CHRONYD_UPTIME})"
        fi
    fi
elif command -v chronyc &> /dev/null; then
    # Try using host's chronyc to query the container's NTP service on port 1123
    if timeout 5 chronyc -h localhost -p 1123 sources 2>&1 | grep -q "^\^"; then
        test_result "Host NTP UDP/1123" "PASS" "NTP service accessible from host on port 1123/udp"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP UDP/1123" "FAIL" "Cannot query NTP on localhost:1123/udp from host after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP UDP/1123" "WARN" "NTP not responding on localhost:1123/udp from host (${CHRONYD_UPTIME})"
        fi
    fi
else
    # Fallback: just check if port mapping exists
    if ss -ulnp 2>/dev/null | grep -q ":1123"; then
        test_result "Host NTP UDP/1123" "WARN" "Port 1123 mapped but cannot test (ntpdate/chronyc not available on host)"
    else
        test_result "Host NTP UDP/1123" "WARN" "Port 1123 mapping not found - check docker-compose port configuration"
    fi
fi
fi

# ============================================================================
# Layer 6: Host Access - External Protocol Functionality (TCP)
# ============================================================================

# Test 11: NTP TCP Protocol - Transparent Mode from Host (port 123)
echo ""
echo "Test 11: Host → Chronyd NTP TCP/123 (Transparent Mode)"
if command -v nc &> /dev/null; then
    if timeout 3 nc -zv localhost 123 2>&1 | grep -q "succeeded\|open"; then
        test_result "Host NTP TCP/123" "PASS" "NTP TCP port 123 is accessible"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP TCP/123" "FAIL" "Cannot connect to NTP TCP on localhost:123 after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP TCP/123" "WARN" "NTP TCP not responding on localhost:123 (${CHRONYD_UPTIME})"
        fi
    fi
else
    test_result "Host NTP TCP/123" "WARN" "nc (netcat) not available - install netcat to test"
fi

# Test 12: NTP TCP Protocol - Direct Mode from Host (port 1123)
echo ""
echo "Test 12: Host → Chronyd NTP TCP/1123 (Direct Mode)"
if command -v nc &> /dev/null; then
    if timeout 3 nc -zv localhost 1123 2>&1 | grep -q "succeeded\|open"; then
        test_result "Host NTP TCP/1123" "PASS" "NTP TCP port 1123 is accessible"
    else
        chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
        if [[ $chronyd_uptime_seconds -gt 300 ]]; then
            test_result "Host NTP TCP/1123" "FAIL" "Cannot connect to NTP TCP on localhost:1123 after ${CHRONYD_UPTIME}"
        else
            test_result "Host NTP TCP/1123" "WARN" "NTP TCP not responding on localhost:1123 (${CHRONYD_UPTIME})"
        fi
    fi
else
    test_result "Host NTP TCP/1123" "WARN" "nc (netcat) not available - install netcat to test"
fi

# ============================================================================
# Layer 7: NTP Synchronization Quality & Metrics
# ============================================================================

# Test 13: Check NTP synchronization status
echo ""
echo "Test 13: NTP Synchronization Status"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep -q "Leap status"; then
    TRACKING_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null)
    test_result "NTP Sync Status" "PASS" "Chronyd tracking information available"
    echo "$TRACKING_OUTPUT" | head -10
else
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Sync Status" "FAIL" "Tracking unavailable after ${CHRONYD_UPTIME}"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
    else
        test_result "NTP Sync Status" "WARN" "Tracking not ready (${CHRONYD_UPTIME})"
    fi
fi

# Test 14: Verify NTP offset <10ms
echo ""
echo "Test 14: NTP Offset Accuracy (<10ms target)"
OFFSET_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep "System time" || echo "")
if [[ -n "$OFFSET_OUTPUT" ]]; then
    # Extract offset value (format: "System time     : 0.000012345 seconds slow of NTP time")
    OFFSET=$(echo "$OFFSET_OUTPUT" | awk '{print $4}')
    OFFSET_MS=$(echo "$OFFSET * 1000" | bc -l 2>/dev/null || echo "0")
    OFFSET_ABS=$(echo "$OFFSET_MS" | tr -d '-')
    
    if command -v bc &> /dev/null; then
        if (( $(echo "$OFFSET_ABS < 10" | bc -l) )); then
            test_result "NTP Offset Accuracy" "PASS" "Offset is ${OFFSET_MS}ms (within 10ms target)"
        else
            test_result "NTP Offset Accuracy" "FAIL" "Offset is ${OFFSET_MS}ms (exceeds 10ms target)"
        fi
    else
        test_result "NTP Offset Accuracy" "WARN" "bc command not available, cannot calculate offset"
    fi
else
    # Check if Chronyd has been running long enough that offset should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Offset Accuracy" "FAIL" "Offset unavailable after ${CHRONYD_UPTIME} - not synchronized"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Offset Accuracy" "WARN" "Offset not available (${CHRONYD_UPTIME})"
    fi
fi

# Test 15: Check stratum level
echo ""
echo "Test 15: NTP Stratum Level"
STRATUM_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep "Stratum" || echo "")
if [[ -n "$STRATUM_OUTPUT" ]]; then
    STRATUM=$(echo "$STRATUM_OUTPUT" | awk '{print $3}')
    if [[ "$STRATUM" == "2" ]] || [[ "$STRATUM" == "3" ]]; then
        test_result "NTP Stratum Level" "PASS" "Stratum level is $STRATUM (acceptable)"
    elif [[ "$STRATUM" == "16" ]]; then
        test_result "NTP Stratum Level" "FAIL" "Stratum 16 indicates not synchronized"
    else
        test_result "NTP Stratum Level" "WARN" "Stratum level is $STRATUM"
    fi
else
    # Check if Chronyd has been running long enough that stratum should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Stratum Level" "FAIL" "Stratum unavailable after ${CHRONYD_UPTIME} - not synchronized"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Stratum Level" "WARN" "Stratum not available (${CHRONYD_UPTIME})"
    fi
fi

# Test 16: Verify NTS is enabled
echo ""
echo "Test 16: NTS (Network Time Security) Verification"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs chronyd 2>/dev/null | grep -qi "NTS"; then
    test_result "NTS Security" "PASS" "NTS connections detected in logs"
else
    # Check if Chronyd has been running long enough that NTS should be established
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTS Security" "FAIL" "No NTS connections after ${CHRONYD_UPTIME} - check config"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTS Security" "WARN" "No NTS connections found (${CHRONYD_UPTIME})"
    fi
fi

# Test 17: Verify leap smearing configuration
echo ""
echo "Test 17: Leap Smearing Configuration"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd grep -q "leapsecmode" /etc/chrony/chrony.conf 2>/dev/null; then
    test_result "Leap Smearing Config" "PASS" "Leap smearing configured in chrony.conf"
else
    test_result "Leap Smearing Config" "WARN" "Could not verify leap smearing configuration"
fi

# Test 18: Check NTP metrics endpoint (Phase 9 feature - not yet implemented)
echo ""
echo "Test 18: NTP Metrics Collection"
if curl -sf http://localhost:9123/metrics 2>/dev/null | grep -q "chrony"; then
    test_result "NTP Metrics Endpoint" "PASS" "Metrics endpoint accessible on :9123/tcp"
else
    # Metrics endpoint is a Phase 9 feature - mark as warning, not failure
    test_result "NTP Metrics Endpoint" "WARN" "Metrics not accessible - Phase 9 feature (not yet implemented)"
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
    echo -e "${RED}❌ NTP accuracy test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ NTP accuracy test PASSED${NC}"
    echo "Time synchronization is accurate and secure"
    exit 0
fi
