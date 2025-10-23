#!/bin/bash

# Claude Code Integration Tests
# Comprehensive integration test suite for Claude Code services

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../../../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/services/claude-code/docker-compose.claude-code.yml"
ENV_FILE="${PROJECT_ROOT}/apps/active/devops/localnet/.env"
TEST_TIMEOUT=300  # 5 minutes timeout for tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
    ((TOTAL++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
    ((TOTAL++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Setup function
setup() {
    log_info "Setting up integration test environment..."

    # Check if .env file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_failure "Environment file not found: $ENV_FILE"
        log_info "Please create .env file with required variables (see env.example)"
        exit 1
    fi

    # Check if docker-compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_failure "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    # Stop any existing services
    log_info "Stopping any existing Claude Code services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans 2>/dev/null || true

    # Build services
    log_info "Building Claude Code services..."
    if ! timeout "$TEST_TIMEOUT" docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build; then
        log_failure "Failed to build services within timeout"
        exit 1
    fi

    # Start services
    log_info "Starting Claude Code services..."
    if ! timeout "$TEST_TIMEOUT" docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d; then
        log_failure "Failed to start services within timeout"
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs
        exit 1
    fi

    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps | grep -q "Up"; then
            log_info "Services are up, checking health endpoints..."
            break
        fi
        log_info "Waiting for services to start (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done

    if [[ $attempt -gt $max_attempts ]]; then
        log_failure "Services failed to start within timeout"
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs
        exit 1
    fi

    log_success "Integration test environment setup complete"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up integration test environment..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans 2>/dev/null || true
    log_info "Cleanup complete"
}

# Run individual test files
run_test_file() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .sh)"

    log_info "Running test: $test_name"

    if [[ -x "$test_file" ]]; then
        if bash "$test_file"; then
            log_success "Test $test_name passed"
            return 0
        else
            log_failure "Test $test_name failed"
            return 1
        fi
    else
        log_failure "Test file $test_file is not executable"
        return 1
    fi
}

# Main test execution
main() {
    local exit_code=0

    log_info "Starting Claude Code Integration Tests"
    log_info "========================================="

    # Setup
    if ! setup; then
        log_failure "Setup failed, aborting tests"
        exit 1
    fi

    # Trap to ensure cleanup on exit
    trap cleanup EXIT

    # Run all test files
    for test_file in "${SCRIPT_DIR}"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || exit_code=1
        fi
    done

    # Summary
    log_info "========================================="
    log_info "Test Summary: $PASSED passed, $FAILED failed, $TOTAL total"

    if [[ $FAILED -eq 0 ]]; then
        log_success "All integration tests passed!"
        return 0
    else
        log_failure "Some integration tests failed"
        return 1
    fi
}

# Run main function
main "$@"
