#!/usr/bin/env bash
# E2E Tests for Logging Services (Loki, Promtail, Vector, Elasticsearch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

LOKI_PORT="3100"
ELASTICSEARCH_PORT="9200"

test_loki_health() {
    test_start "Loki Health"
    if curl -sf "http://localhost:$LOKI_PORT/ready" > /dev/null; then
        test_pass "Loki ready"
    else
        test_fail "Loki not ready"
    fi
}

test_elasticsearch_health() {
    test_start "Elasticsearch Health"
    if curl -sf "http://localhost:$ELASTICSEARCH_PORT/_cluster/health" | grep -q "status"; then
        test_pass "Elasticsearch responding"
    else
        test_fail "Elasticsearch not responding"
    fi
}

main() {
    test_suite_start "Logging Services E2E Tests"
    test_loki_health
    test_elasticsearch_health
    test_suite_end
}

main "$@"
