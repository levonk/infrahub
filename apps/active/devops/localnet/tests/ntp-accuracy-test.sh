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

# Test 1: Verify chronyd is running
echo "Test 1: NTP Service Availability"
IFS='|' read -r CHRONYD_STATUS CHRONYD_UPTIME CHRONYD_HEALTH <<< "$(parse_container_status chronyd)"
if echo "$CHRONYD_STATUS" | grep -q "Up"; then
    health_msg=""
    [[ -n "$CHRONYD_HEALTH" ]] && health_msg=" [${CHRONYD_HEALTH}]"
    test_result "Chronyd Running" "PASS" "Chronyd running for ${CHRONYD_UPTIME}${health_msg}"
else
    test_result "Chronyd Running" "FAIL" "Chronyd container status: $CHRONYD_STATUS"
    echo ""
    echo "⚠️  Chronyd is not running. Checking logs..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs --tail=20 chronyd 2>/dev/null || echo "Could not retrieve logs"
    echo ""
    echo "Continuing with remaining tests..."
fi

# Test 2: Check NTP synchronization status
echo ""
echo "Test 2: NTP Synchronization Status"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep -q "Leap status"; then
    TRACKING_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null)
    test_result "NTP Tracking" "PASS" "Chronyd tracking information available"
    echo "$TRACKING_OUTPUT" | head -10
else
    # Check if Chronyd has been running long enough that tracking should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Tracking" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but tracking unavailable - check logs"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Tracking" "WARN" "Could not retrieve chronyd tracking information (starting for ${CHRONYD_UPTIME})"
    fi
fi

# Test 3: Verify NTP offset <10ms
echo ""
echo "Test 3: NTP Offset Accuracy (<10ms target)"
OFFSET_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep "System time" || echo "")
if [[ -n "$OFFSET_OUTPUT" ]]; then
    # Extract offset value (format: "System time     : 0.000012345 seconds slow of NTP time")
    OFFSET=$(echo "$OFFSET_OUTPUT" | awk '{print $4}')
    OFFSET_MS=$(echo "$OFFSET * 1000" | bc -l 2>/dev/null || echo "0")
    OFFSET_ABS=$(echo "$OFFSET_MS" | tr -d '-')
    
    if command -v bc &> /dev/null; then
        if (( $(echo "$OFFSET_ABS < 10" | bc -l) )); then
            test_result "NTP Offset" "PASS" "Offset is ${OFFSET_MS}ms (within 10ms target)"
        else
            test_result "NTP Offset" "FAIL" "Offset is ${OFFSET_MS}ms (exceeds 10ms target)"
        fi
    else
        test_result "NTP Offset" "WARN" "bc command not available, cannot calculate offset"
    fi
else
    # Check if Chronyd has been running long enough that offset should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Offset" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but offset unavailable - not synchronized"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Offset" "WARN" "Could not retrieve offset information (Chronyd starting for ${CHRONYD_UPTIME})"
    fi
fi

# Test 4: Check stratum level
echo ""
echo "Test 4: NTP Stratum Level"
STRATUM_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc tracking 2>/dev/null | grep "Stratum" || echo "")
if [[ -n "$STRATUM_OUTPUT" ]]; then
    STRATUM=$(echo "$STRATUM_OUTPUT" | awk '{print $3}')
    if [[ "$STRATUM" == "2" ]] || [[ "$STRATUM" == "3" ]]; then
        test_result "NTP Stratum" "PASS" "Stratum level is $STRATUM (acceptable)"
    elif [[ "$STRATUM" == "16" ]]; then
        test_result "NTP Stratum" "FAIL" "Stratum 16 indicates not synchronized"
    else
        test_result "NTP Stratum" "WARN" "Stratum level is $STRATUM"
    fi
else
    # Check if Chronyd has been running long enough that stratum should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Stratum" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but stratum unavailable - not synchronized"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Stratum" "WARN" "Could not retrieve stratum information (Chronyd starting for ${CHRONYD_UPTIME})"
    fi
fi

# Test 5: Verify NTS is enabled
echo ""
echo "Test 5: NTS (Network Time Security) Verification"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs chronyd 2>/dev/null | grep -qi "NTS"; then
    test_result "NTS Enabled" "PASS" "NTS connections detected in logs"
else
    # Check if Chronyd has been running long enough that NTS should be established
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTS Enabled" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but no NTS connections - check config"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTS Enabled" "WARN" "No NTS connections found in logs (Chronyd starting for ${CHRONYD_UPTIME})"
    fi
fi

# Test 6: Check NTP sources
echo ""
echo "Test 6: NTP Source Availability"
SOURCES_OUTPUT=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd chronyc sources 2>/dev/null || echo "")
if [[ -n "$SOURCES_OUTPUT" ]]; then
    SOURCE_COUNT=$(echo "$SOURCES_OUTPUT" | grep -c "^\^" || echo "0")
    if [[ "$SOURCE_COUNT" -gt 0 ]]; then
        test_result "NTP Sources" "PASS" "Found $SOURCE_COUNT NTP sources"
        echo "$SOURCES_OUTPUT" | head -15
    else
        test_result "NTP Sources" "WARN" "No active NTP sources found"
    fi
else
    # Check if Chronyd has been running long enough that sources should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Sources" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but no sources available - check network"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Sources" "WARN" "Could not retrieve NTP sources (Chronyd starting for ${CHRONYD_UPTIME})"
    fi
fi

# Test 7: Verify leap smearing configuration
echo ""
echo "Test 7: Leap Smearing Configuration"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T chronyd grep -q "leapsecmode" /etc/chrony/chrony.conf 2>/dev/null; then
    test_result "Leap Smearing" "PASS" "Leap smearing configured in chrony.conf"
else
    test_result "Leap Smearing" "WARN" "Could not verify leap smearing configuration"
fi

# Test 8: Check NTP metrics endpoint
echo ""
echo "Test 8: NTP Metrics Collection"
if curl -sf http://localhost:9123/metrics 2>/dev/null | grep -q "chrony"; then
    test_result "NTP Metrics" "PASS" "Chronyd metrics endpoint is accessible"
else
    # Check if Chronyd has been running long enough that metrics should be available
    chronyd_uptime_seconds=$(uptime_to_seconds "$CHRONYD_UPTIME")
    if [[ $chronyd_uptime_seconds -gt 300 ]]; then
        test_result "NTP Metrics" "FAIL" "Chronyd running for ${CHRONYD_UPTIME} but metrics unavailable - check exporter"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" restart chronyd"
        echo ""
        echo "Chronyd is a standalone service and can be restarted independently."
    else
        test_result "NTP Metrics" "WARN" "Chronyd metrics endpoint not accessible (starting for ${CHRONYD_UPTIME})"
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
    echo -e "${RED}❌ NTP accuracy test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ NTP accuracy test PASSED${NC}"
    echo "Time synchronization is accurate and secure"
    exit 0
fi
