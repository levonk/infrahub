#!/usr/bin/env bash
# Test Helper Functions for E2E Tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_WARNED=0

test_suite_start() {
    local suite_name="$1"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running: $suite_name${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

test_suite_end() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total:   $TESTS_RUN"
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Warned:  $TESTS_WARNED${NC}"
    echo -e "Skipped: $TESTS_SKIPPED"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

test_start() {
    local test_name="$1"
    echo -n "Testing: $test_name ... "
    ((TESTS_RUN++))
}

test_pass() {
    local message="$1"
    echo -e "${GREEN}✓ PASS${NC} - $message"
    ((TESTS_PASSED++))
}

test_fail() {
    local message="$1"
    echo -e "${RED}✗ FAIL${NC} - $message"
    ((TESTS_FAILED++))
}

test_warn() {
    local message="$1"
    echo -e "${YELLOW}⚠ WARN${NC} - $message"
    ((TESTS_WARNED++))
}

test_skip() {
    local message="$1"
    echo -e "○ SKIP - $message"
    ((TESTS_SKIPPED++))
}
