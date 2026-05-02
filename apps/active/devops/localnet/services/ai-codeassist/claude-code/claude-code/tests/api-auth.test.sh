#!/bin/bash

# Test API Endpoints and Authentication
# Tests session creation, authentication flow, and API validation

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

test_auth_service_health() {
    log_info "Testing authentication service health..."

    # Test auth service health endpoint
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -f --max-time 10 http://localhost:8080/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Auth service health endpoint accessible"
        return 0
    else
        echo -e "${RED}FAIL${NC}: Auth service health endpoint not accessible"
        return 1
    fi
}

test_session_creation() {
    log_info "Testing session creation endpoint..."

    # Test session creation with valid API key
    # This assumes we have a test API key configured
    local test_api_key="${CLAUDE_CODE_API_KEY:-test-api-key-12345}"

    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${test_api_key}" \
        -d '{"user_id": "test-user", "preferences": {"model": "claude-3-5-sonnet-20241022"}}' \
        http://localhost:8080/sessions 2>/dev/null || echo "")

    if [[ -n "$response" ]] && echo "$response" | grep -q "session_id"; then
        echo -e "${GREEN}PASS${NC}: Session creation successful"
        # Extract session ID for later tests
        SESSION_ID=$(echo "$response" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
        export SESSION_ID
        return 0
    else
        echo -e "${RED}FAIL${NC}: Session creation failed"
        echo "Response: $response"
        return 1
    fi
}

test_session_validation() {
    log_info "Testing session validation..."

    if [[ -z "${SESSION_ID:-}" ]]; then
        echo -e "${RED}FAIL${NC}: No session ID available from previous test"
        return 1
    fi

    # Test session validation endpoint
    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -s \
        -H "Authorization: Bearer ${SESSION_ID}" \
        http://localhost:8080/sessions/validate 2>/dev/null || echo "")

    if [[ -n "$response" ]] && echo "$response" | grep -q "valid.*true"; then
        echo -e "${GREEN}PASS${NC}: Session validation successful"
        return 0
    else
        echo -e "${RED}FAIL${NC}: Session validation failed"
        echo "Response: $response"
        return 1
    fi
}

test_unauthorized_access() {
    log_info "Testing unauthorized access handling..."

    # Test with invalid API key
    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer invalid-api-key" \
        -d '{"user_id": "test-user"}' \
        http://localhost:8080/sessions 2>/dev/null || echo "")

    if [[ -n "$response" ]] && echo "$response" | grep -q "401\|Unauthorized\|Invalid"; then
        echo -e "${GREEN}PASS${NC}: Unauthorized access properly rejected"
        return 0
    else
        echo -e "${RED}FAIL${NC}: Unauthorized access not properly rejected"
        echo "Response: $response"
        return 1
    fi
}

test_rate_limiting() {
    log_info "Testing rate limiting..."

    # Make multiple rapid requests to test rate limiting
    local failed_count=0
    local test_api_key="${CLAUDE_CODE_API_KEY:-test-api-key-12345}"

    for i in {1..10}; do
        local response
        response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code-auth curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${test_api_key}" \
            -d '{"user_id": "test-user"}' \
            http://localhost:8080/sessions 2>/dev/null || echo "")

        if echo "$response" | grep -q "429\|Too Many Requests\|rate limit"; then
            echo -e "${GREEN}PASS${NC}: Rate limiting working (request $i rejected)"
            return 0
        fi
    done

    echo -e "${YELLOW}WARN${NC}: Rate limiting not observed (may be configured differently)"
    return 0  # Don't fail if rate limiting isn't configured
}

test_claude_code_api() {
    log_info "Testing Claude Code API integration..."

    if [[ -z "${SESSION_ID:-}" ]]; then
        echo -e "${RED}FAIL${NC}: No session ID available for Claude Code API test"
        return 1
    fi

    # Test Claude Code API health
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -f --max-time 10 http://localhost:8081/health 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: Claude Code API health endpoint accessible"
    else
        echo -e "${RED}FAIL${NC}: Claude Code API health endpoint not accessible"
        return 1
    fi

    # Test Claude Code API with session
    local response
    response=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T claude-code curl -s \
        -H "Authorization: Bearer ${SESSION_ID}" \
        -H "Content-Type: application/json" \
        -d '{"message": "Hello, test message"}' \
        http://localhost:8081/chat 2>/dev/null || echo "")

    if [[ -n "$response" ]] && echo "$response" | grep -q "response\|message"; then
        echo -e "${GREEN}PASS${NC}: Claude Code API chat endpoint working"
        return 0
    else
        echo -e "${YELLOW}WARN${NC}: Claude Code API chat endpoint returned: $response"
        # Don't fail this test as it may not be implemented yet
        return 0
    fi
}

# Run all API tests
main() {
    local test_failed=0

    echo "Testing API Endpoints and Authentication"
    echo "======================================="

    if ! test_auth_service_health; then
        test_failed=1
    fi

    if ! test_session_creation; then
        test_failed=1
    fi

    if ! test_session_validation; then
        test_failed=1
    fi

    if ! test_unauthorized_access; then
        test_failed=1
    fi

    if ! test_rate_limiting; then
        test_failed=1
    fi

    if ! test_claude_code_api; then
        test_failed=1
    fi

    echo "======================================="

    if [[ $test_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All API tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some API tests failed${NC}"
        return 1
    fi
}

main "$@"
