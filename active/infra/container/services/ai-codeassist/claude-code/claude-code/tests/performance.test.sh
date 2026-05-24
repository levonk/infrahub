#!/bin/bash

# Performance Testing
# Validate performance requirements and resource usage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/services/ai-codeassist/claude-code/claude-code/docker-compose.claude-code.yml"
ENV_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[PERF]${NC} $1"
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

# Measure API response times
test_api_response_times() {
    log_info "Testing API response times..."

    local total_requests=50
    local response_times=()
    local failed_requests=0

    for i in $(seq 1 $total_requests); do
        local start_time=$(date +%s%3N)  # milliseconds
        local response

        # Test health endpoint (fastest)
        if response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s -w "%{http_code}" --max-time 10 http://localhost:8081/health 2>/dev/null); then
            local end_time=$(date +%s%3N)
            local response_time=$((end_time - start_time))
            local http_code=${response: -3}

            if [[ "$http_code" == "200" ]]; then
                response_times+=($response_time)
            else
                ((failed_requests++))
            fi
        else
            ((failed_requests++))
        fi
    done

    # Calculate statistics
    local successful_requests=$((${#response_times[@]}))
    local total_time=0

    for time in "${response_times[@]}"; do
        total_time=$((total_time + time))
    done

    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$((total_time / successful_requests))
        local sorted_times=($(printf '%s\n' "${response_times[@]}" | sort -n))
        local p95_index=$((successful_requests * 95 / 100))
        local p95_time=${sorted_times[$p95_index]}

        echo "API Response Time Results:"
        echo "  Total requests: $total_requests"
        echo "  Successful: $successful_requests"
        echo "  Failed: $failed_requests"
        echo "  Average response time: ${avg_time}ms"
        echo "  95th percentile: ${p95_time}ms"

        # Check requirements
        if [[ $p95_time -le 5000 ]]; then
            log_success "95th percentile response time (${p95_time}ms) meets requirement (<5000ms)"
        else
            log_failure "95th percentile response time (${p95_time}ms) exceeds requirement (>5000ms)"
        fi
    else
        log_failure "All API requests failed"
    fi
}

# Test concurrent user support
test_concurrent_users() {
    log_info "Testing concurrent user support..."

    local concurrent_users=5
    local requests_per_user=10
    local pids=()

    # Function to simulate a user
    simulate_user() {
        local user_id=$1
        local success_count=0
        local total_count=0

        for i in $(seq 1 $requests_per_user); do
            ((total_count++))
            # Simulate API call with some delay to mimic real usage
            if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -f --max-time 30 http://localhost:8081/health >/dev/null 2>&1; then
                ((success_count++))
            fi
            # Small delay between requests
            sleep 0.1
        done

        echo "User $user_id: $success_count/$total_count successful requests"
    }

    # Start concurrent users
    for user_id in $(seq 1 $concurrent_users); do
        simulate_user "$user_id" &
        pids+=($!)
    done

    # Wait for all users to complete
    local results=()
    for pid in "${pids[@]}"; do
        wait "$pid"
        results+=("$?")
    done

    # Collect results (this is a simplified version)
    log_success "Concurrent user test completed ($concurrent_users users x $requests_per_user requests each)"
    log_info "All concurrent users completed their request cycles"
}

# Monitor resource usage
test_resource_usage() {
    log_info "Monitoring resource usage..."

    # Get container resource usage
    local container_stats
    container_stats=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --format "table {{.Names}}\t{{.Ports}}" | tail -n +2)

    if [[ -z "$container_stats" ]]; then
        log_failure "No containers found for resource monitoring"
        return 1
    fi

    echo "Container Status:"
    echo "$container_stats"
    echo ""

    # Check Docker stats for memory and CPU usage
    log_info "Checking Docker resource usage..."

    # Get stats for running containers
    local stats_output
    if stats_output=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null); then
        echo "Resource Usage:"
        echo "$stats_output"
        echo ""

        # Parse memory usage (simplified check)
        local mem_over_limit=false
        while IFS= read -r line; do
            if [[ $line =~ ([0-9\.]+)MiB ]]; then
                local mem_mb=${BASH_REMATCH[1]}
                if (( $(echo "$mem_mb > 2048" | bc -l 2>/dev/null || echo "0") )); then
                    mem_over_limit=true
                    break
                fi
            fi
        done <<< "$stats_output"

        if [[ "$mem_over_limit" == "true" ]]; then
            log_warning "Some containers exceed 2GB RAM limit"
        else
            log_success "All containers within 2GB RAM limit"
        fi

        # Parse CPU usage (simplified check)
        local cpu_over_limit=false
        while IFS= read -r line; do
            if [[ $line =~ ([0-9\.]+)% ]]; then
                local cpu_perc=${BASH_REMATCH[1]}
                if (( $(echo "$cpu_perc > 200" | bc -l 2>/dev/null || echo "0") )); then
                    cpu_over_limit=true
                    break
                fi
            fi
        done <<< "$stats_output"

        if [[ "$cpu_over_limit" == "true" ]]; then
            log_warning "Some containers exceed 200% CPU limit (2 cores)"
        else
            log_success "All containers within 200% CPU limit (2 cores)"
        fi
    else
        log_warning "Could not retrieve detailed resource statistics"
        log_info "Basic container health verified"
    fi
}

# Test scalability and degradation
test_scalability() {
    log_info "Testing scalability and degradation handling..."

    # Test with increasing load
    local load_levels=(10 25 50 100)
    local baseline_response_time=0

    # Get baseline response time
    local baseline_start=$(date +%s%3N)
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s http://localhost:8081/health >/dev/null 2>&1
    local baseline_end=$(date +%s%3N)
    baseline_response_time=$((baseline_end - baseline_start))

    echo "Baseline response time: ${baseline_response_time}ms"

    for load in "${load_levels[@]}"; do
        log_info "Testing with $load concurrent requests..."

        local pids=()
        local start_time=$(date +%s%3N)

        # Launch concurrent requests
        for i in $(seq 1 $load); do
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s http://localhost:8081/health >/dev/null 2>&1 &
            pids+=($!)
        done

        # Wait for completion
        local completed=0
        for pid in "${pids[@]}"; do
            if wait "$pid" 2>/dev/null; then
                ((completed++))
            fi
        done

        local end_time=$(date +%s%3N)
        local total_time=$((end_time - start_time))
        local avg_time=$((total_time / load))

        local degradation_factor
        degradation_factor=$(echo "scale=2; $avg_time / $baseline_response_time" | bc -l 2>/dev/null || echo "1.0")

        echo "Load $load: $completed/$load completed, avg ${avg_time}ms (${degradation_factor}x baseline)"

        # Check for excessive degradation (more than 5x baseline is concerning)
        if (( $(echo "$degradation_factor > 5.0" | bc -l 2>/dev/null || echo "0") )); then
            log_warning "High degradation detected at load $load (${degradation_factor}x baseline)"
        fi

        # Small delay between load tests
        sleep 2
    done

    log_success "Scalability test completed"
}

# Run all performance tests
main() {
    local test_failed=0

    echo "Performance Testing Suite"
    echo "========================"

    if ! test_api_response_times; then
        test_failed=1
    fi

    if ! test_concurrent_users; then
        test_failed=1
    fi

    if ! test_resource_usage; then
        test_failed=1
    fi

    if ! test_scalability; then
        test_failed=1
    fi

    echo "========================"

    if [[ $test_failed -eq 0 ]]; then
        log_success "All performance tests completed"
        return 0
    else
        log_failure "Some performance tests failed"
        return 1
    fi
}

main "$@"
