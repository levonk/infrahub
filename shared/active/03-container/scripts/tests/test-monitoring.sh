#!/usr/bin/env bash
# E2E Tests for Monitoring Services (Prometheus, Grafana, Jaeger, Blackbox Exporter)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
PROMETHEUS_PORT="${PROMETHEUS_PORT:-19090}"
GRAFANA_PORT="3000"
JAEGER_UI_PORT="16686"
BLACKBOX_PORT="9115"

test_prometheus_health() {
    test_start "Prometheus Health"
    
    if curl -sf "http://localhost:$PROMETHEUS_PORT/-/healthy" > /dev/null; then
        test_pass "Prometheus health check passed"
    else
        test_fail "Prometheus health check failed"
    fi
}

test_prometheus_targets() {
    test_start "Prometheus Targets"
    
    targets=$(curl -sf "http://localhost:$PROMETHEUS_PORT/api/v1/targets" | grep -o '"health":"up"' | wc -l)
    
    if [[ "$targets" -gt 0 ]]; then
        test_pass "Prometheus has $targets healthy target(s)"
    else
        test_warn "No healthy Prometheus targets found"
    fi
}

test_prometheus_metrics() {
    test_start "Prometheus Metrics"
    
    if curl -sf "http://localhost:$PROMETHEUS_PORT/metrics" | grep -q "prometheus_"; then
        test_pass "Prometheus metrics endpoint working"
    else
        test_fail "Prometheus metrics endpoint not working"
    fi
}

test_prometheus_query() {
    test_start "Prometheus Query API"
    
    result=$(curl -sf "http://localhost:$PROMETHEUS_PORT/api/v1/query?query=up" | grep -o '"status":"success"')
    
    if [[ -n "$result" ]]; then
        test_pass "Prometheus query API working"
    else
        test_fail "Prometheus query API not working"
    fi
}

test_grafana_health() {
    test_start "Grafana Health"
    
    if curl -sf "http://localhost:$GRAFANA_PORT/api/health" | grep -q "ok"; then
        test_pass "Grafana health check passed"
    else
        test_fail "Grafana health check failed"
    fi
}

test_grafana_web_ui() {
    test_start "Grafana Web UI"
    
    if curl -sf "http://localhost:$GRAFANA_PORT/login" | grep -q "Grafana"; then
        test_pass "Grafana web UI accessible"
    else
        test_fail "Grafana web UI not accessible"
    fi
}

test_grafana_datasources() {
    test_start "Grafana Datasources"
    
    # Note: This requires authentication, so we just check if the endpoint exists
    if curl -sf "http://localhost:$GRAFANA_PORT/api/datasources" > /dev/null 2>&1; then
        test_pass "Grafana datasources API accessible"
    else
        test_warn "Grafana datasources API requires authentication"
    fi
}

test_jaeger_health() {
    test_start "Jaeger Health"
    
    if nc -zv localhost "$JAEGER_UI_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Jaeger UI listening on port $JAEGER_UI_PORT"
    else
        test_fail "Jaeger UI not listening"
    fi
}

test_jaeger_ui() {
    test_start "Jaeger Web UI"
    
    if curl -sf "http://localhost:$JAEGER_UI_PORT/" | grep -q "Jaeger"; then
        test_pass "Jaeger web UI accessible"
    else
        test_fail "Jaeger web UI not accessible"
    fi
}

test_blackbox_exporter_health() {
    test_start "Blackbox Exporter Health"
    
    if curl -sf "http://localhost:$BLACKBOX_PORT/health" > /dev/null; then
        test_pass "Blackbox Exporter health check passed"
    else
        test_fail "Blackbox Exporter health check failed"
    fi
}

test_blackbox_exporter_probe() {
    test_start "Blackbox Exporter HTTP Probe"
    
    if curl -sf "http://localhost:$BLACKBOX_PORT/probe?target=http://example.com&module=http_2xx" | grep -q "probe_success 1"; then
        test_pass "Blackbox Exporter HTTP probe working"
    else
        test_fail "Blackbox Exporter HTTP probe not working"
    fi
}

test_blackbox_exporter_modules() {
    test_start "Blackbox Exporter Modules"
    
    if curl -sf "http://localhost:$BLACKBOX_PORT/config" | grep -q "modules:"; then
        test_pass "Blackbox Exporter modules configured"
    else
        test_fail "Blackbox Exporter modules not configured"
    fi
}

# Run all tests
main() {
    test_suite_start "Monitoring Services E2E Tests"
    
    test_prometheus_health
    test_prometheus_targets
    test_prometheus_metrics
    test_prometheus_query
    
    echo ""
    
    test_grafana_health
    test_grafana_web_ui
    test_grafana_datasources
    
    echo ""
    
    test_jaeger_health
    test_jaeger_ui
    
    echo ""
    
    test_blackbox_exporter_health
    test_blackbox_exporter_probe
    test_blackbox_exporter_modules
    
    test_suite_end
}

main "$@"
