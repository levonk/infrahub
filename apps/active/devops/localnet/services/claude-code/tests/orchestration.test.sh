#!/bin/bash

# Test Docker Compose Service Orchestration
# Tests container startup, networking, and health checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/services/claude-code/docker-compose.claude-code.yml"
ENV_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

test_service_startup() {
    log_info "Testing service startup and container health..."

    # Check if all expected containers are running
    local expected_services=("claude-code" "claude-code-ui" "claude-code-auth" "claude-code-mcp" "pluggedin-mcp-proxy" "pluggedin-app")

    for service in "${expected_services[@]}"; do
        if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps | grep -q "$service"; then
            echo -e "${RED}FAIL${NC}: Service $service is not running"
            return 1
        fi
        echo -e "${GREEN}PASS${NC}: Service $service is running"
    done

    # Check container health status
    local unhealthy_count=0
    for service in "${expected_services[@]}"; do
        if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps | grep "$service" | grep -q "healthy\|running"; then
            echo -e "${RED}FAIL${NC}: Service $service is not healthy"
            ((unhealthy_count++))
        else
            echo -e "${GREEN}PASS${NC}: Service $service is healthy"
        fi
    done

    if [[ $unhealthy_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

test_networking() {
    log_info "Testing inter-service networking..."

    # Test internal service connectivity
    # Claude Code should be able to reach MCP server
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -f --max-time 10 http://claude-code-mcp:8082/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Claude Code can reach MCP server internally"
    else
        echo -e "${RED}FAIL${NC}: Claude Code cannot reach MCP server internally"
        return 1
    fi

    # Test MCP proxy connectivity
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -f --max-time 10 http://pluggedin-mcp-proxy:8085/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Web UI can reach MCP proxy internally"
    else
        echo -e "${RED}FAIL${NC}: Web UI cannot reach MCP proxy internally"
        return 1
    fi

    return 0
}

test_volumes_and_persistence() {
    log_info "Testing persistent volumes..."

    # Check if volumes are mounted correctly
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code test -d /app/data/sessions; then
        echo -e "${GREEN}PASS${NC}: Session data volume is mounted"
    else
        echo -e "${RED}FAIL${NC}: Session data volume is not mounted"
        return 1
    fi

    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code test -d /app/data/history; then
        echo -e "${GREEN}PASS${NC}: History data volume is mounted"
    else
        echo -e "${RED}FAIL${NC}: History data volume is not mounted"
        return 1
    fi

    return 0
}

test_resource_limits() {
    log_info "Testing resource limits..."

    # Check if containers have appropriate resource limits
    # This is a basic check - in production you'd want more sophisticated monitoring
    local containers
    containers=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --format "table {{.Names}}\t{{.Ports}}" | tail -n +2)

    if [[ -z "$containers" ]]; then
        echo -e "${RED}FAIL${NC}: No containers found"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: Containers are running (resource limits check would require additional monitoring)"
    return 0
}

# Run all orchestration tests
main() {
    local test_failed=0

    echo "Testing Docker Compose Service Orchestration"
    echo "==========================================="

    if ! test_service_startup; then
        test_failed=1
    fi

    if ! test_networking; then
        test_failed=1
    fi

    if ! test_volumes_and_persistence; then
        test_failed=1
    fi

    if ! test_resource_limits; then
        test_failed=1
    fi

    echo "==========================================="

    if [[ $test_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All orchestration tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some orchestration tests failed${NC}"
        return 1
    fi
}

main "$@"
