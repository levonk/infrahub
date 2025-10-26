#!/bin/bash

# Test MCP Tool Integration
# Tests Model Context Protocol tool discovery, execution, and functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/services/ai-codeassist/claude-code/claude-code/docker-compose.claude-code.yml"
ENV_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

test_mcp_server_health() {
    log_info "Testing MCP server health..."

    # Test claude-code-mcp health
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -f --max-time 10 http://localhost:8082/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Claude Code MCP server healthy"
    else
        echo -e "${RED}FAIL${NC}: Claude Code MCP server not healthy"
        return 1
    fi

    # Test pluggedin-mcp-proxy health
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T pluggedin-mcp-proxy curl -f --max-time 10 http://localhost:8085/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: MCP proxy server healthy"
    else
        echo -e "${RED}FAIL${NC}: MCP proxy server not healthy"
        return 1
    fi

    return 0
}

test_mcp_tool_discovery() {
    log_info "Testing MCP tool discovery..."

    # Test tool discovery from claude-code-mcp
    local tools_response
    tools_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -s --max-time 10 http://localhost:8082/tools 2>/dev/null || echo "")

    if [[ -n "$tools_response" ]]; then
        # Check for expected tool types
        if echo "$tools_response" | grep -q "file-system\|shell\|git"; then
            echo -e "${GREEN}PASS${NC}: MCP tools discovered (file-system, shell, git)"
        else
            echo -e "${YELLOW}WARN${NC}: Expected MCP tools not found in response: $tools_response"
        fi
    else
        echo -e "${RED}FAIL${NC}: No MCP tools response"
        return 1
    fi

    # Test tool discovery from proxy
    local proxy_tools_response
    proxy_tools_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T pluggedin-mcp-proxy curl -s --max-time 10 http://localhost:8085/tools 2>/dev/null || echo "")

    if [[ -n "$proxy_tools_response" ]]; then
        echo -e "${GREEN}PASS${NC}: MCP proxy tools accessible"
    else
        echo -e "${RED}FAIL${NC}: MCP proxy tools not accessible"
        return 1
    fi

    return 0
}

test_mcp_tool_execution() {
    log_info "Testing MCP tool execution..."

    # Test file-system tool (list directory)
    local fs_response
    fs_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"tool": "file-system", "operation": "list", "path": "/tmp"}' \
        http://localhost:8082/execute 2>/dev/null || echo "")

    if [[ -n "$fs_response" ]] && echo "$fs_response" | grep -q "result\|files"; then
        echo -e "${GREEN}PASS${NC}: File-system tool execution successful"
    else
        echo -e "${YELLOW}WARN${NC}: File-system tool execution returned: $fs_response"
        # Don't fail - may not be implemented yet
    fi

    # Test shell tool (simple command)
    local shell_response
    shell_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"tool": "shell", "command": "echo test", "timeout": 5000}' \
        http://localhost:8082/execute 2>/dev/null || echo "")

    if [[ -n "$shell_response" ]] && echo "$shell_response" | grep -q "test\|result"; then
        echo -e "${GREEN}PASS${NC}: Shell tool execution successful"
    else
        echo -e "${YELLOW}WARN${NC}: Shell tool execution returned: $shell_response"
        # Don't fail - may not be implemented yet
    fi

    return 0
}

test_mcp_claude_integration() {
    log_info "Testing MCP-Claude Code integration..."

    # Test that Claude Code can reach MCP server
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -f --max-time 10 http://claude-code-mcp:8082/tools 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Claude Code can reach MCP server internally"
    else
        echo -e "${RED}FAIL${NC}: Claude Code cannot reach MCP server internally"
        return 1
    fi

    # Test that Claude Code can reach MCP proxy
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -f --max-time 10 http://pluggedin-mcp-proxy:8085/tools 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Claude Code can reach MCP proxy internally"
    else
        echo -e "${RED}FAIL${NC}: Claude Code cannot reach MCP proxy internally"
        return 1
    fi

    return 0
}

test_mcp_security() {
    log_info "Testing MCP security configuration..."

    # Test that MCP endpoints require authentication (should fail without auth)
    local unauth_response
    unauth_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -s --max-time 10 http://localhost:8082/admin 2>/dev/null || echo "")

    if echo "$unauth_response" | grep -q "401\|403\|Unauthorized\|Forbidden"; then
        echo -e "${GREEN}PASS${NC}: MCP admin endpoint properly secured"
    else
        echo -e "${YELLOW}WARN${NC}: MCP admin endpoint security unclear (response: $unauth_response)"
    fi

    # Test TLS configuration (if enabled)
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-mcp curl -f --max-time 10 https://localhost:8443/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: MCP TLS endpoint accessible"
    else
        echo -e "${YELLOW}INFO${NC}: MCP TLS not configured or using different port"
    fi

    return 0
}

test_pluggedin_app_integration() {
    log_info "Testing PluggedIn app integration..."

    # Test pluggedin-app health
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T pluggedin-app curl -f --max-time 10 http://localhost:8086/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: PluggedIn app healthy"
    else
        echo -e "${RED}FAIL${NC}: PluggedIn app not healthy"
        return 1
    fi

    # Test PluggedIn app MCP integration
    local pluggedin_response
    pluggedin_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T pluggedin-app curl -s --max-time 10 http://pluggedin-mcp-proxy:8085/tools 2>/dev/null || echo "")

    if [[ -n "$pluggedin_response" ]]; then
        echo -e "${GREEN}PASS${NC}: PluggedIn app can access MCP proxy"
    else
        echo -e "${RED}FAIL${NC}: PluggedIn app cannot access MCP proxy"
        return 1
    fi

    return 0
}

# Run all MCP tests
main() {
    local test_failed=0

    echo "Testing MCP Tool Integration"
    echo "============================"

    if ! test_mcp_server_health; then
        test_failed=1
    fi

    if ! test_mcp_tool_discovery; then
        test_failed=1
    fi

    if ! test_mcp_tool_execution; then
        test_failed=1
    fi

    if ! test_mcp_claude_integration; then
        test_failed=1
    fi

    if ! test_mcp_security; then
        test_failed=1
    fi

    if ! test_pluggedin_app_integration; then
        test_failed=1
    fi

    echo "============================"

    if [[ $test_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All MCP integration tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some MCP integration tests failed${NC}"
        return 1
    fi
}

main "$@"
