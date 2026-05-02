#!/usr/bin/env bash
# Artifact Repository Test - Verify artifact storage and retrieval
# Tests that artifact services (Nexus, etc.) are running and accessible
# Tests the project in {REPO_ROOT}/job-aide/apps/active/devops/localnet/services/artifacts


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
echo "Artifact Repository Test"
echo "========================================="
echo ""

# Test 1: Verify Nexus is running and accessible
echo "Test 1: Artifact Service Availability"
IFS='|' read -r NEXUS_STATUS NEXUS_UPTIME NEXUS_HEALTH <<< "$(parse_container_status nexus)"
if echo "$NEXUS_STATUS" | grep -q "Up"; then
    health_msg=""
    [[ -n "$NEXUS_HEALTH" ]] && health_msg=" [${NEXUS_HEALTH}]"
    test_result "Nexus Running" "PASS" "Nexus running for ${NEXUS_UPTIME}${health_msg}"
else
    test_result "Nexus Running" "FAIL" "Nexus container status: $NEXUS_STATUS"
    echo ""
    echo "⚠️  Nexus is not running. Checking logs..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs --tail=20 nexus 2>/dev/null || echo "Could not retrieve logs"
    echo ""
    echo "Continuing with remaining tests..."
fi

# Test 2: Verify Nexus HTTP API is accessible
echo ""
echo "Test 2: Nexus HTTP API Accessibility"
NEXUS_HOST=${ARTIFACT_NEXUS_HOST:-localhost}
NEXUS_PORT=${ARTIFACT_NEXUS_WEB_CONTAINER_PORT:-8081}
nexus_uptime_seconds=$(uptime_to_seconds "${NEXUS_UPTIME:-}")

if curl -sf "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/status" >/dev/null 2>&1; then
    test_result "Nexus API" "PASS" "Nexus API accessible at http://${NEXUS_HOST}:${NEXUS_PORT}"
else
    if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
        test_result "Nexus API" "FAIL" "Nexus running for ${NEXUS_UPTIME} but API not accessible at http://${NEXUS_HOST}:${NEXUS_PORT}"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" ps nexus"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs nexus --tail=50"
        echo ""
        echo "Check if port ${NEXUS_PORT} is properly mapped and Nexus is fully initialized."
    else
        test_result "Nexus API" "WARN" "Nexus API not accessible yet (Nexus starting for ${NEXUS_UPTIME:-unknown})"
    fi
fi

# Test 3: Verify Nexus health status
echo ""
echo "Test 3: Nexus Health Status"
if command -v curl &> /dev/null; then
    health_response=$(curl -sf "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/status" 2>/dev/null || echo "{}")

    if echo "$health_response" | grep -q "\"state\":\"STARTED\""; then
        test_result "Nexus Health" "PASS" "Nexus is in STARTED state"
    else
        if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Nexus Health" "FAIL" "Nexus running for ${NEXUS_UPTIME} but not in STARTED state"
            echo ""
            echo "Health response: $health_response"
        else
            test_result "Nexus Health" "WARN" "Nexus still initializing (running for ${NEXUS_UPTIME:-unknown})"
        fi
    fi
else
    test_result "Nexus Health" "WARN" "curl command not available, skipping health check"
fi

# Test 4: Verify Nexus repositories are configured
echo ""
echo "Test 4: Nexus Repositories Configuration"
if command -v curl &> /dev/null; then
    # Try to list repositories
    repos=$(curl -sf "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/repositories" 2>/dev/null || echo "[]")

    if echo "$repos" | grep -q "\"name\""; then
        repo_count=$(echo "$repos" | grep -c "\"name\"" || echo "0")
        test_result "Repositories Configured" "PASS" "Found ${repo_count} repositories"
    else
        if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
            test_result "Repositories Configured" "FAIL" "Nexus running for ${NEXUS_UPTIME} but cannot list repositories"
            echo ""
            echo -e "${YELLOW}Recommended action:${NC}"
            echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" exec -T nexus curl -s http://localhost:${NEXUS_PORT}/service/rest/v1/repositories"
            echo ""
            echo "Check if repositories are properly configured."
        else
            test_result "Repositories Configured" "WARN" "Repositories not yet available (Nexus starting for ${NEXUS_UPTIME:-unknown})"
        fi
    fi
else
    test_result "Repositories Configured" "WARN" "curl command not available, skipping repository check"
fi

# Test 5: Verify Nexus storage is writable
echo ""
echo "Test 5: Nexus Storage Writability"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T nexus test -w /nexus-data 2>/dev/null; then
    test_result "Storage Writable" "PASS" "Nexus storage directory is writable"
else
    if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
        test_result "Storage Writable" "FAIL" "Nexus running for ${NEXUS_UPTIME} but storage directory not writable"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" exec -T nexus ls -la /nexus-data"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs nexus --tail=50"
        echo ""
        echo "Check storage permissions and volume mounts."
    else
        test_result "Storage Writable" "WARN" "Storage check skipped (Nexus starting for ${NEXUS_UPTIME:-unknown})"
    fi
fi

# Test 6: Verify Java preferences directory exists (from JAVA_PREFS_FIX)
echo ""
echo "Test 6: Java Preferences Directory"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T nexus test -d /opt/sonatype/nexus/.java/.userPrefs 2>/dev/null; then
    test_result "Java Prefs Dir" "PASS" "Java preferences directory exists and is accessible"
else
    if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
        test_result "Java Prefs Dir" "FAIL" "Nexus running for ${NEXUS_UPTIME} but Java preferences directory missing"
        echo ""
        echo -e "${YELLOW}Recommended action:${NC}"
        echo "  docker compose -f \"$PROJECT_ROOT/docker-compose.yml\" logs nexus --tail=50 | grep -i 'preferences\\|java'"
        echo ""
        echo "Check if Java preferences warnings are appearing in logs."
    else
        test_result "Java Prefs Dir" "WARN" "Java preferences check skipped (Nexus starting for ${NEXUS_UPTIME:-unknown})"
    fi
fi

# Test 7: Verify Nexus logs for errors
echo ""
echo "Test 7: Nexus Log Analysis"
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs nexus --tail=100 2>/dev/null | grep -qi "error\|exception\|failed"; then
    error_count=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs nexus --tail=100 2>/dev/null | grep -ic "error\|exception\|failed" || echo "0")
    if [[ ${nexus_uptime_seconds:-0} -gt 300 ]]; then
        test_result "Log Analysis" "FAIL" "Found ${error_count} error/exception entries in recent logs"
        echo ""
        echo -e "${YELLOW}Recent errors:${NC}"
        docker compose -f "$PROJECT_ROOT/docker-compose.yml" logs nexus --tail=20 2>/dev/null | grep -i "error\|exception\|failed" || true
    else
        test_result "Log Analysis" "WARN" "Found ${error_count} error entries but Nexus is still starting"
    fi
else
    test_result "Log Analysis" "PASS" "No errors detected in recent logs"
fi

# Test 8: Verify artifact service network connectivity
echo ""
echo "Test 8: Network Connectivity"
ARTIFACT_NETWORK=${ARTIFACT_NETWORK:-artifact-network}
if docker network inspect "$ARTIFACT_NETWORK" >/dev/null 2>&1; then
    connected_containers=$(docker network inspect "$ARTIFACT_NETWORK" --format '{{len .Containers}}' 2>/dev/null || echo "0")
    if [[ ${connected_containers:-0} -gt 0 ]]; then
        test_result "Network Connectivity" "PASS" "Artifact network active with ${connected_containers} connected containers"
    else
        test_result "Network Connectivity" "WARN" "Artifact network exists but no containers connected"
    fi
else
    test_result "Network Connectivity" "WARN" "Artifact network not found (may not be required)"
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
    echo -e "${RED}❌ Artifact test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Artifact test PASSED${NC}"
    echo "Artifact repository services are operational"
    exit 0
fi
