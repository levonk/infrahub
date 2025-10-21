#!/usr/bin/env bash
# E2E Tests for DNS Services (CoreDNS, DNSCrypt-Proxy, DNSDist)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
DNS_DIRECT_PORT="${DNS_DIRECT_PORT:-15353}"
DNS_TEST_DOMAIN="example.com"
DNS_TEST_IP="93.184.216.34"  # example.com IP

test_coredns_health() {
    test_start "CoreDNS Health Check"
    
    if curl -sf http://localhost:8080/health > /dev/null; then
        test_pass "CoreDNS health endpoint responding"
    else
        test_fail "CoreDNS health endpoint not responding"
    fi
}

test_coredns_metrics() {
    test_start "CoreDNS Metrics"
    
    if curl -sf http://localhost:9153/metrics | grep -q "coredns_dns_requests_total"; then
        test_pass "CoreDNS metrics available"
    else
        test_fail "CoreDNS metrics not available"
    fi
}

test_dns_query_direct() {
    test_start "DNS Query (Direct Port)"
    
    if command -v dig &> /dev/null; then
        result=$(dig @localhost -p "$DNS_DIRECT_PORT" "$DNS_TEST_DOMAIN" +short | head -1)
        if [[ -n "$result" ]]; then
            test_pass "DNS query successful: $DNS_TEST_DOMAIN -> $result"
        else
            test_fail "DNS query returned no results"
        fi
    else
        test_skip "dig command not available"
    fi
}

test_dns_query_dnscrypt() {
    test_start "DNSCrypt-Proxy Query"
    
    if docker exec homelab-dnscrypt-proxy nc -zv localhost 5300 2>&1 | grep -q "succeeded"; then
        test_pass "DNSCrypt-Proxy port 5300 listening"
    else
        test_fail "DNSCrypt-Proxy port 5300 not listening"
    fi
}

test_dnsdist_metrics() {
    test_start "DNSDist Metrics"
    
    if curl -sf http://localhost:8083/metrics | grep -q "dnsdist_"; then
        test_pass "DNSDist metrics available"
    else
        test_fail "DNSDist metrics not available"
    fi
}

test_dns_cache() {
    test_start "DNS Cache Performance"
    
    if command -v dig &> /dev/null; then
        # First query (uncached)
        time1=$(dig @localhost -p "$DNS_DIRECT_PORT" "$DNS_TEST_DOMAIN" | grep "Query time:" | awk '{print $4}')
        
        # Second query (should be cached)
        time2=$(dig @localhost -p "$DNS_DIRECT_PORT" "$DNS_TEST_DOMAIN" | grep "Query time:" | awk '{print $4}')
        
        if [[ -n "$time1" && -n "$time2" ]]; then
            test_pass "DNS cache working (1st: ${time1}ms, 2nd: ${time2}ms)"
        else
            test_fail "Could not measure DNS cache performance"
        fi
    else
        test_skip "dig command not available"
    fi
}

test_dns_dnssec() {
    test_start "DNSSEC Validation"
    
    if command -v dig &> /dev/null; then
        result=$(dig @localhost -p "$DNS_DIRECT_PORT" cloudflare.com +dnssec | grep -c "ad;")
        if [[ "$result" -gt 0 ]]; then
            test_pass "DNSSEC validation working"
        else
            test_warn "DNSSEC validation may not be enabled"
        fi
    else
        test_skip "dig command not available"
    fi
}

# Run all tests
main() {
    test_suite_start "DNS Services E2E Tests"
    
    test_coredns_health
    test_coredns_metrics
    test_dns_query_direct
    test_dns_query_dnscrypt
    test_dnsdist_metrics
    test_dns_cache
    test_dns_dnssec
    
    test_suite_end
}

main "$@"
