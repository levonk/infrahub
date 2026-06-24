#!/usr/bin/env bash
# AI Dashboard Pipeline Integration Test
# Tests the full AI analytics pipeline with Privacy Orchestrator integration
# Pipeline: AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → AI Dashboard Proxy 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AI_DASHBOARD_DIR="$PROJECT_ROOT/services/ai-dashboard"

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

check_container_health() {
    local container_name="$1"
    local status health

    status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null || echo "not found")
    
    if [[ "$status" == "not found" ]]; then
        echo "not_found"
        return
    fi

    if echo "$status" | grep -q "healthy"; then
        echo "healthy"
    elif echo "$status" | grep -q "Up"; then
        echo "running"
    else
        echo "unhealthy"
    fi
}

test_network_connectivity() {
    local source_container="$1"
    local target_host="$2"
    local target_port="$3"

    docker exec "$source_container" nc -zv "$target_host" "$target_port" 2>&1 | grep -q "succeeded\|open"
}

echo "========================================="
echo "AI Dashboard Pipeline Integration Test"
echo "========================================="
echo ""

# Test 1: Verify AI Dashboard network exists
echo "Test 1: AI Dashboard Network"
if docker network ls | grep -q "ai-dashboard-network"; then
    test_result "AI Dashboard Network" "PASS" "Network exists"
else
    test_result "AI Dashboard Network" "FAIL" "Network does not exist"
fi

# Test 2: Verify proxy-chain-network exists
echo ""
echo "Test 2: Proxy Chain Network"
if docker network ls | grep -q "proxy-chain-network"; then
    test_result "Proxy Chain Network" "PASS" "Network exists"
else
    test_result "Proxy Chain Network" "FAIL" "Network does not exist"
fi

# Test 3: Verify AI Dashboard Proxy 1 is running
echo ""
echo "Test 3: AI Dashboard Proxy 1"
PROXY1_HEALTH=$(check_container_health "ai-dashboard-proxy-1")
if [[ "$PROXY1_HEALTH" == "healthy" || "$PROXY1_HEALTH" == "running" ]]; then
    test_result "AI Dashboard Proxy 1" "PASS" "Container is $PROXY1_HEALTH"
else
    test_result "AI Dashboard Proxy 1" "FAIL" "Container status: $PROXY1_HEALTH"
fi

# Test 4: Verify Privacy Orchestrator is running
echo ""
echo "Test 4: Privacy Orchestrator"
PRIVACY_HEALTH=$(check_container_health "privacy-orchestrator")
if [[ "$PRIVACY_HEALTH" == "healthy" || "$PRIVACY_HEALTH" == "running" ]]; then
    test_result "Privacy Orchestrator" "PASS" "Container is $PRIVACY_HEALTH"
else
    test_result "Privacy Orchestrator" "FAIL" "Container status: $PRIVACY_HEALTH"
fi

# Test 5: Verify Headroom is running
echo ""
echo "Test 5: Headroom"
HEADROOM_HEALTH=$(check_container_health "headroom")
if [[ "$HEADROOM_HEALTH" == "healthy" || "$HEADROOM_HEALTH" == "running" ]]; then
    test_result "Headroom" "PASS" "Container is $HEADROOM_HEALTH"
else
    test_result "Headroom" "FAIL" "Container status: $HEADROOM_HEALTH"
fi

# Test 6: Verify OmniRoute is running
echo ""
echo "Test 6: OmniRoute"
OMNIROUTE_HEALTH=$(check_container_health "omniroute")
if [[ "$OMNIROUTE_HEALTH" == "healthy" || "$OMNIROUTE_HEALTH" == "running" ]]; then
    test_result "OmniRoute" "PASS" "Container is $OMNIROUTE_HEALTH"
else
    test_result "OmniRoute" "FAIL" "Container status: $OMNIROUTE_HEALTH"
fi

# Test 7: Verify AI Dashboard Proxy 2 is running
echo ""
echo "Test 7: AI Dashboard Proxy 2"
PROXY2_HEALTH=$(check_container_health "ai-dashboard-proxy-2")
if [[ "$PROXY2_HEALTH" == "healthy" || "$PROXY2_HEALTH" == "running" ]]; then
    test_result "AI Dashboard Proxy 2" "PASS" "Container is $PROXY2_HEALTH"
else
    test_result "AI Dashboard Proxy 2" "FAIL" "Container status: $PROXY2_HEALTH"
fi

# Test 8: Verify AI Dashboard Database is running
echo ""
echo "Test 8: AI Dashboard Database"
DB_HEALTH=$(check_container_health "ai-dashboard-db")
if [[ "$DB_HEALTH" == "healthy" || "$DB_HEALTH" == "running" ]]; then
    test_result "AI Dashboard Database" "PASS" "Container is $DB_HEALTH"
else
    test_result "AI Dashboard Database" "FAIL" "Container status: $DB_HEALTH"
fi

# Network connectivity tests (only if containers are running)
if [[ "$PROXY1_HEALTH" == "healthy" || "$PROXY1_HEALTH" == "running" ]]; then
    # Test 9: AI Dashboard Proxy 1 to Privacy Orchestrator
    echo ""
    echo "Test 9: Proxy 1 → Privacy Orchestrator"
    if test_network_connectivity "ai-dashboard-proxy-1" "privacy-orchestrator" "9090"; then
        test_result "Proxy 1 → Privacy Orchestrator" "PASS" "Network connectivity OK"
    else
        test_result "Proxy 1 → Privacy Orchestrator" "FAIL" "Cannot connect to Privacy Orchestrator"
    fi
fi

if [[ "$PRIVACY_HEALTH" == "healthy" || "$PRIVACY_HEALTH" == "running" ]]; then
    # Test 10: Privacy Orchestrator to Headroom
    echo ""
    echo "Test 10: Privacy Orchestrator → Headroom"
    if test_network_connectivity "privacy-orchestrator" "headroom" "8787"; then
        test_result "Privacy Orchestrator → Headroom" "PASS" "Network connectivity OK"
    else
        test_result "Privacy Orchestrator → Headroom" "FAIL" "Cannot connect to Headroom"
    fi
fi

if [[ "$HEADROOM_HEALTH" == "healthy" || "$HEADROOM_HEALTH" == "running" ]]; then
    # Test 11: Headroom to OmniRoute
    echo ""
    echo "Test 11: Headroom → OmniRoute"
    if test_network_connectivity "headroom" "omniroute" "20128"; then
        test_result "Headroom → OmniRoute" "PASS" "Network connectivity OK"
    else
        test_result "Headroom → OmniRoute" "FAIL" "Cannot connect to OmniRoute"
    fi
fi

if [[ "$OMNIROUTE_HEALTH" == "healthy" || "$OMNIROUTE_HEALTH" == "running" ]]; then
    # Test 12: OmniRoute to Proxy 2
    echo ""
    echo "Test 12: OmniRoute → Proxy 2"
    if test_network_connectivity "omniroute" "ai-dashboard-proxy-2" "8082"; then
        test_result "OmniRoute → Proxy 2" "PASS" "Network connectivity OK"
    else
        test_result "OmniRoute → Proxy 2" "FAIL" "Cannot connect to Proxy 2"
    fi
fi

# Health endpoint tests
if [[ "$PRIVACY_HEALTH" == "healthy" || "$PRIVACY_HEALTH" == "running" ]]; then
    # Test 13: Privacy Orchestrator health endpoint
    echo ""
    echo "Test 13: Privacy Orchestrator Health Endpoint"
    if docker exec privacy-orchestrator wget -q -O- http://localhost:9090/health > /dev/null 2>&1; then
        test_result "Privacy Orchestrator Health" "PASS" "Health endpoint responds"
    else
        test_result "Privacy Orchestrator Health" "FAIL" "Health endpoint not responding"
    fi
fi

if [[ "$HEADROOM_HEALTH" == "healthy" || "$HEADROOM_HEALTH" == "running" ]]; then
    # Test 14: Headroom health endpoint
    echo ""
    echo "Test 14: Headroom Health Endpoint"
    if docker exec headroom wget -q -O- http://localhost:8787/health > /dev/null 2>&1; then
        test_result "Headroom Health" "PASS" "Health endpoint responds"
    else
        test_result "Headroom Health" "FAIL" "Health endpoint not responding"
    fi
fi

if [[ "$OMNIROUTE_HEALTH" == "healthy" || "$OMNIROUTE_HEALTH" == "running" ]]; then
    # Test 15: OmniRoute health endpoint
    echo ""
    echo "Test 15: OmniRoute Health Endpoint"
    if docker exec omniroute wget -q -O- http://localhost:20128/v1/models > /dev/null 2>&1; then
        test_result "OmniRoute Health" "PASS" "Health endpoint responds"
    else
        test_result "OmniRoute Health" "FAIL" "Health endpoint not responding"
    fi
fi

# Database connectivity test
if [[ "$DB_HEALTH" == "healthy" || "$DB_HEALTH" == "running" ]]; then
    # Test 16: Database connectivity
    echo ""
    echo "Test 16: Database Connectivity"
    if docker exec ai-dashboard-db pg_isready -U postgres > /dev/null 2>&1; then
        test_result "Database Connectivity" "PASS" "Database is ready"
    else
        test_result "Database Connectivity" "FAIL" "Database is not ready"
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests Run: $TESTS_RUN"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
