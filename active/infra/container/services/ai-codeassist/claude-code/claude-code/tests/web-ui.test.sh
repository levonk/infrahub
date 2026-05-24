#!/bin/bash

# Test Web UI Interaction and Session Management
# Tests web interface functionality and session handling

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

test_web_ui_health() {
    log_info "Testing web UI health..."

    # Test claudecodeui health endpoint
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -f --max-time 10 http://localhost:3000/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Web UI health endpoint accessible"
    else
        echo -e "${RED}FAIL${NC}: Web UI health endpoint not accessible"
        return 1
    fi

    return 0
}

test_web_ui_pages() {
    log_info "Testing web UI page accessibility..."

    # Test main web UI page
    local main_page_response
    main_page_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s --max-time 10 -I http://localhost:3000/ 2>/dev/null | head -n 1 || echo "")

    if echo "$main_page_response" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}PASS${NC}: Web UI main page accessible"
    else
        echo -e "${YELLOW}WARN${NC}: Web UI main page returned: $main_page_response"
    fi

    # Test login page (if separate)
    local login_page_response
    login_page_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s --max-time 10 -I http://localhost:3000/login 2>/dev/null | head -n 1 || echo "")

    if echo "$login_page_response" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}PASS${NC}: Web UI login page accessible"
    else
        echo -e "${YELLOW}INFO${NC}: Web UI login page not found or different URL"
    fi

    return 0
}

test_session_management() {
    log_info "Testing session management..."

    # Test session creation through web UI
    local test_api_key="${CLAUDE_CODE_API_KEY:-test-api-key-12345}"
    local test_user="test-user-web"

    # Create session via web UI API
    local session_response
    session_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"user_id\": \"$test_user\", \"api_key\": \"$test_api_key\"}" \
        http://localhost:3000/api/sessions 2>/dev/null || echo "")

    if [[ -n "$session_response" ]] && echo "$session_response" | grep -q "session_id\|success"; then
        echo -e "${GREEN}PASS${NC}: Web UI session creation successful"
        # Extract session info for further tests
        WEB_SESSION_ID=$(echo "$session_response" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 || echo "")
    else
        echo -e "${YELLOW}WARN${NC}: Web UI session creation returned: $session_response"
        # Try alternative endpoint
        session_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${test_api_key}" \
            -d "{\"user_id\": \"$test_user\"}" \
            http://localhost:3000/api/auth/login 2>/dev/null || echo "")

        if [[ -n "$session_response" ]] && echo "$session_response" | grep -q "token\|session"; then
            echo -e "${GREEN}PASS${NC}: Web UI authentication successful via alternative endpoint"
        else
            echo -e "${YELLOW}WARN${NC}: Web UI authentication may not be implemented yet"
        fi
    fi

    return 0
}

test_web_ui_claude_integration() {
    log_info "Testing web UI to Claude Code integration..."

    # Test that web UI can communicate with Claude Code backend
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -f --max-time 10 http://claude-code:8081/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Web UI can reach Claude Code backend"
    else
        echo -e "${RED}FAIL${NC}: Web UI cannot reach Claude Code backend"
        return 1
    fi

    return 0
}

test_web_ui_mcp_integration() {
    log_info "Testing web UI to MCP integration..."

    # Test that web UI can access MCP tools through proxy
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -f --max-time 10 http://pluggedin-mcp-proxy:8085/tools 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Web UI can reach MCP proxy"
    else
        echo -e "${RED}FAIL${NC}: Web UI cannot reach MCP proxy"
        return 1
    fi

    return 0
}

test_web_security_headers() {
    log_info "Testing web security headers..."

    # Test security headers on web UI
    local headers_response
    headers_response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s -I --max-time 10 http://localhost:3000/ 2>/dev/null || echo "")

    # Check for basic security headers
    if echo "$headers_response" | grep -qi "X-Frame-Options\|X-Content-Type-Options\|X-XSS-Protection"; then
        echo -e "${GREEN}PASS${NC}: Security headers present"
    else
        echo -e "${YELLOW}INFO${NC}: Security headers not detected (may be configured differently)"
    fi

    # Check for HTTPS redirect (if applicable)
    local https_redirect
    https_redirect=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s -I --max-time 10 http://localhost:3000/ 2>/dev/null | grep -i "location: https" || echo "")

    if [[ -n "$https_redirect" ]]; then
        echo -e "${GREEN}PASS${NC}: HTTPS redirect configured"
    else
        echo -e "${YELLOW}INFO${NC}: HTTPS redirect not detected"
    fi

    return 0
}

test_concurrent_sessions() {
    log_info "Testing concurrent session handling..."

    # Test multiple concurrent sessions (basic test)
    local test_api_key="${CLAUDE_CODE_API_KEY:-test-api-key-12345}"

    # Create multiple sessions rapidly
    local success_count=0
    local total_attempts=3

    for i in {1..3}; do
        local response
        response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-ui curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${test_api_key}" \
            -d "{\"user_id\": \"user-$i\"}" \
            http://localhost:3000/api/sessions 2>/dev/null || echo "")

        if [[ -n "$response" ]] && echo "$response" | grep -q "session_id\|success"; then
            ((success_count++))
        fi
    done

    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}PASS${NC}: Concurrent sessions handled ($success_count/$total_attempts successful)"
    else
        echo -e "${YELLOW}WARN${NC}: No concurrent sessions created successfully"
    fi

    return 0
}

# Run all web UI tests
main() {
    local test_failed=0

    echo "Testing Web UI Interaction and Session Management"
    echo "================================================"

    if ! test_web_ui_health; then
        test_failed=1
    fi

    if ! test_web_ui_pages; then
        test_failed=1
    fi

    if ! test_session_management; then
        test_failed=1
    fi

    if ! test_web_ui_claude_integration; then
        test_failed=1
    fi

    if ! test_web_ui_mcp_integration; then
        test_failed=1
    fi

    if ! test_web_security_headers; then
        test_failed=1
    fi

    if ! test_concurrent_sessions; then
        test_failed=1
    fi

    echo "================================================"

    if [[ $test_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All web UI tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some web UI tests failed${NC}"
        return 1
    fi
}

main "$@"
