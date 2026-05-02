#!/usr/bin/env bash
# Run All E2E Tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running All Homelab E2E Tests"
echo "=================================="
echo ""

# Track overall results
TOTAL_SUITES=0
FAILED_SUITES=0

run_test_suite() {
    local test_script="$1"
    local test_name=$(basename "$test_script" .sh)
    
    ((TOTAL_SUITES++))
    
    if bash "$test_script"; then
        echo "✅ $test_name: PASSED"
    else
        echo "❌ $test_name: FAILED"
        ((FAILED_SUITES++))
    fi
    echo ""
}

# Run all test suites
run_test_suite "$SCRIPT_DIR/test-dns-services.sh"
run_test_suite "$SCRIPT_DIR/test-web-proxies.sh"
run_test_suite "$SCRIPT_DIR/test-vpn-services.sh"
run_test_suite "$SCRIPT_DIR/test-artifact-repos.sh"
run_test_suite "$SCRIPT_DIR/test-monitoring.sh"
run_test_suite "$SCRIPT_DIR/test-logging.sh"

# Final summary
echo "=================================="
echo "📊 Overall Test Summary"
echo "=================================="
echo "Total Suites: $TOTAL_SUITES"
echo "Passed: $((TOTAL_SUITES - FAILED_SUITES))"
echo "Failed: $FAILED_SUITES"
echo ""

if [[ $FAILED_SUITES -gt 0 ]]; then
    echo "❌ Some test suites failed"
    exit 1
else
    echo "✅ All test suites passed!"
    exit 0
fi
