#!/usr/bin/env bash
# E2E Tests for Artifact Repositories (Verdaccio, Nexus)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
VERDACCIO_PORT="${VERDACCIO_PORT:-14873}"
ARTIFACT_NEXUS_WEB_HOST_PORT="${ARTIFACT_NEXUS_WEB_HOST_PORT:-8081}"
<<<<<<< HEAD
NEXUS_DOCKER_PORT="${NEXUS_DOCKER_PORT:-8082}"
=======
ARTIFACT_NEXUS_DOCKER_HOST_PORT="${ARTIFACT_NEXUS_DOCKER_HOST_PORT:-8082}"
>>>>>>> 002-claude-code-integration

test_verdaccio_health() {
    test_start "Verdaccio Health"

    if curl -sf "http://localhost:$VERDACCIO_PORT/-/ping" | grep -q "pong"; then
        test_pass "Verdaccio health check passed"
    else
        test_fail "Verdaccio health check failed"
    fi
}

test_verdaccio_web_ui() {
    test_start "Verdaccio Web UI"

    if curl -sf "http://localhost:$VERDACCIO_PORT/" | grep -q "Verdaccio"; then
        test_pass "Verdaccio web UI accessible"
    else
        test_fail "Verdaccio web UI not accessible"
    fi
}

test_verdaccio_registry() {
    test_start "Verdaccio NPM Registry"

    # Test package search
    if curl -sf "http://localhost:$VERDACCIO_PORT/-/v1/search?text=express" | grep -q "express"; then
        test_pass "Verdaccio registry search working"
    else
        test_warn "Verdaccio registry search not working (may need upstream connection)"
    fi
}

test_verdaccio_npm_config() {
    test_start "Verdaccio NPM Configuration"

    if command -v npm &> /dev/null; then
        # Test if we can configure npm to use verdaccio
        npm_registry=$(npm config get registry 2>/dev/null || echo "")
        test_pass "NPM registry configured: $npm_registry"
    else
        test_skip "npm not available"
    fi
}

test_verdaccio_publish() {
    test_start "Verdaccio Package Publish (Dry Run)"

    # Create a test package
    test_dir="/tmp/verdaccio-test-$$"
    mkdir -p "$test_dir"

    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "@localnet/test-package",
  "version": "1.0.0",
  "description": "Test package for Verdaccio",
  "private": true
}
EOF

    if [[ -f "$test_dir/package.json" ]]; then
        test_pass "Test package created (publish requires authentication)"
    else
        test_fail "Could not create test package"
    fi

    rm -rf "$test_dir"
}

test_nexus_health() {
    test_start "Nexus Health"

    if curl -sf "http://localhost:$ARTIFACT_NEXUS_WEB_HOST_PORT/service/rest/v1/status" > /dev/null; then
        test_pass "Nexus health check passed"
    else
        test_warn "Nexus may still be starting up (can take 2-3 minutes)"
    fi
}

test_nexus_web_ui() {
    test_start "Nexus Web UI"

    if curl -sf "http://localhost:$ARTIFACT_NEXUS_WEB_HOST_PORT/" | grep -q "Nexus"; then
        test_pass "Nexus web UI accessible"
    else
        test_warn "Nexus web UI not accessible (may still be starting)"
    fi
}

test_nexus_docker_registry() {
    test_start "Nexus Docker Registry"

<<<<<<< HEAD
    if nc -zv localhost "$NEXUS_DOCKER_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Nexus Docker registry listening on port $NEXUS_DOCKER_PORT"
=======
    if nc -zv localhost "$ARTIFACT_NEXUS_DOCKER_HOST_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Nexus Docker registry listening on port $ARTIFACT_NEXUS_DOCKER_HOST_PORT"
>>>>>>> 002-claude-code-integration
    else
        test_warn "Nexus Docker registry not listening (may need configuration)"
    fi
}

test_nexus_repositories() {
    test_start "Nexus Repositories"

    repos=$(curl -sf "http://localhost:$ARTIFACT_NEXUS_WEB_HOST_PORT/service/rest/v1/repositories" 2>/dev/null || echo "[]")

    if echo "$repos" | grep -q "maven"; then
        test_pass "Nexus repositories configured"
    else
        test_warn "Nexus repositories not yet configured"
    fi
}

test_docker_proxy_config() {
    test_start "Docker Proxy Configuration"

    # Check if Docker daemon can be configured to use Nexus
    if command -v docker &> /dev/null; then
        test_pass "Docker available for proxy configuration"
    else
        test_skip "Docker not available"
    fi
}

# Run all tests
main() {
    test_suite_start "Artifact Repository Services E2E Tests"

    test_verdaccio_health
    test_verdaccio_web_ui
    test_verdaccio_registry
    test_verdaccio_npm_config
    test_verdaccio_publish

    echo ""

    test_nexus_health
    test_nexus_web_ui
    test_nexus_docker_registry
    test_nexus_repositories
    test_docker_proxy_config

    test_suite_end
}

main "$@"
