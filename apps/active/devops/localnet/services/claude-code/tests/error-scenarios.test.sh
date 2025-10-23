#!/bin/bash

# Error Scenarios Testing
# Test error handling for edge cases and failure scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/services/claude-code/docker-compose.claude-code.yml"
ENV_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[ERROR_TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test invalid API credentials handling
test_invalid_credentials() {
    log_info "Testing invalid API credentials handling..."

    local test_cases=(
        "invalid-api-key"
        "wrong-format-123"
        "expired-key-456"
        ""
        "super-long-api-key-that-exceeds-normal-lengths-abcdefghijklmnopqrstuvwxyz123456789"
    )

    local passed_tests=0
    local total_tests=${#test_cases[@]}

    for invalid_key in "${test_cases[@]}"; do
        # Test auth service rejection
        local response
        response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${invalid_key}" \
            -d '{"user_id": "test-user"}' \
            http://localhost:8080/sessions 2>/dev/null || echo "error")

        if echo "$response" | grep -q -i "invalid\|unauthorized\|forbidden\|401\|403"; then
            ((passed_tests++))
            log_success "Invalid credential '${invalid_key}' properly rejected"
        else
            log_failure "Invalid credential '${invalid_key}' not properly rejected (response: $response)"
        fi
    done

    echo "Invalid credentials test: $passed_tests/$total_tests passed"
    return $((total_tests - passed_tests))
}

# Test network connectivity failure recovery
test_network_failures() {
    log_info "Testing network connectivity failure recovery..."

    # Test temporary network isolation (simulate network failure)
    log_info "Simulating network failure by stopping a service temporarily..."

    # Stop MCP proxy to simulate network failure
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop pluggedin-mcp-proxy >/dev/null 2>&1

    # Wait a moment for the failure to be detected
    sleep 2

    # Test that other services handle the failure gracefully
    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s --max-time 5 \
        http://pluggedin-mcp-proxy:8085/health 2>/dev/null || echo "connection_failed")

    if [[ "$response" == "connection_failed" ]]; then
        log_success "Network failure properly detected (MCP proxy unreachable)"
    else
        log_failure "Network failure not properly detected"
    fi

    # Test recovery when service comes back
    log_info "Testing service recovery..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" start pluggedin-mcp-proxy >/dev/null 2>&1

    # Wait for service to start
    sleep 5

    # Test that connectivity is restored
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s --max-time 10 \
        http://pluggedin-mcp-proxy:8085/health 2>/dev/null || echo "still_failed")

    if [[ "$response" != "still_failed" ]]; then
        log_success "Network connectivity successfully restored"
    else
        log_failure "Network connectivity not restored after service restart"
    fi
}

# Test resource constraint detection
test_resource_constraints() {
    log_info "Testing resource constraint detection..."

    # Test memory usage monitoring
    local mem_stats
    mem_stats=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stats --no-stream --format "table {{.Container}}\t{{.MemPerc}}" 2>/dev/null | tail -n +2 || echo "")

    if [[ -n "$mem_stats" ]]; then
        log_success "Memory usage monitoring available"

        # Check for any containers near memory limits (this is informational)
        while IFS= read -r line; do
            if [[ $line =~ ([0-9\.]+)% ]]; then
                local mem_perc=${BASH_REMATCH[1]}
                if (( $(echo "$mem_perc > 80" | bc -l 2>/dev/null || echo "0") )); then
                    log_warning "Container memory usage high: ${mem_perc}%"
                fi
            fi
        done <<< "$mem_stats"
    else
        log_warning "Memory usage statistics not available"
    fi

    # Test CPU usage monitoring
    local cpu_stats
    cpu_stats=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" 2>/dev/null | tail -n +2 || echo "")

    if [[ -n "$cpu_stats" ]]; then
        log_success "CPU usage monitoring available"

        # Check for any containers with high CPU usage
        while IFS= read -r line; do
            if [[ $line =~ ([0-9\.]+)% ]]; then
                local cpu_perc=${BASH_REMATCH[1]}
                if (( $(echo "$cpu_perc > 150" | bc -l 2>/dev/null || echo "0") )); then
                    log_warning "Container CPU usage very high: ${cpu_perc}%"
                fi
            fi
        done <<< "$cpu_stats"
    else
        log_warning "CPU usage statistics not available"
    fi

    # Test disk space monitoring (check container logs for any disk space warnings)
    log_info "Checking for disk space constraint indicators..."
    local disk_warnings
    disk_warnings=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs --tail=50 2>&1 | grep -i "disk\|space\|full" || echo "")

    if [[ -z "$disk_warnings" ]]; then
        log_success "No disk space constraint warnings detected"
    else
        log_warning "Disk space warnings detected in logs: $disk_warnings"
    fi
}

# Test MCP server configuration validation
test_mcp_config_validation() {
    log_info "Testing MCP server configuration validation..."

    # Test invalid MCP tool requests
    local invalid_requests=(
        '{"tool": "nonexistent-tool", "operation": "invalid"}'
        '{"tool": "", "operation": "list"}'
        '{"tool": "file-system", "operation": ""}'
        '{"malformed": json}'
        '{"tool": "file-system", "operation": "list", "path": "../../../../etc/passwd"}'
    )

    local passed_tests=0
    local total_tests=${#invalid_requests[@]}

    for invalid_request in "${invalid_requests[@]}"; do
        local response
        response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$invalid_request" \
            http://localhost:8082/execute 2>/dev/null || echo "request_failed")

        # Should either reject the request or handle it safely
        if [[ "$response" == "request_failed" ]] || echo "$response" | grep -q -i "error\|invalid\|not.*found\|forbidden"; then
            ((passed_tests++))
            log_success "Invalid MCP request properly handled: $invalid_request"
        else
            log_failure "Invalid MCP request not properly handled: $invalid_request (response: $response)"
        fi
    done

    echo "MCP config validation: $passed_tests/$total_tests invalid requests properly handled"
    return $((total_tests - passed_tests))
}

# Test timeout handling
test_timeout_handling() {
    log_info "Testing timeout handling..."

    # Test request timeouts
    local start_time=$(date +%s)
    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s --max-time 1 \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"message": "test", "delay": 5000}' \
        http://localhost:8081/chat 2>/dev/null || echo "timeout_occurred")

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ "$response" == "timeout_occurred" ]] || [[ $duration -le 2 ]]; then
        log_success "Timeout handling working properly"
    else
        log_failure "Timeout handling not working (duration: ${duration}s, response: $response)"
    fi
}

# Test error recovery and resilience
test_error_recovery() {
    log_info "Testing error recovery and resilience..."

    # Test multiple rapid failures and recovery
    local success_count=0
    local total_tests=10

    for i in $(seq 1 $total_tests); do
        # Make a request that might fail
        local response
        response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s --max-time 5 \
            http://localhost:8081/health 2>/dev/null || echo "failed")

        if [[ "$response" != "failed" ]]; then
            ((success_count++))
        fi

        # Small delay between requests
        sleep 0.5
    done

    local success_rate=$((success_count * 100 / total_tests))

    if [[ $success_rate -ge 80 ]]; then
        log_success "Error recovery working well (${success_rate}% success rate)"
    else
        log_warning "Error recovery concerning (${success_rate}% success rate)"
    fi
}

# Run all error scenario tests
main() {
    local test_failed=0

    echo "Error Scenarios Testing"
    echo "======================"

    if ! test_invalid_credentials; then
        test_failed=1
    fi

    if ! test_network_failures; then
        test_failed=1
    fi

    if ! test_resource_constraints; then
        test_failed=1
    fi

    if ! test_mcp_config_validation; then
        test_failed=1
    fi

    if ! test_timeout_handling; then
        test_failed=1
    fi

    if ! test_error_recovery; then
        test_failed=1
    fi

    echo "======================"

    if [[ $test_failed -eq 0 ]]; then
        log_success "All error scenario tests completed"
        return 0
    else
        log_failure "Some error scenario tests failed"
        return 1
    fi
}

main "$@"
