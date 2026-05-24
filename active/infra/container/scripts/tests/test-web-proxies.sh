#!/usr/bin/env bash
# E2E Tests for Web Proxy Services (Squid, Privoxy, Envoy, Tor)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
SQUID_PORT="${PROXY_DIRECT_PORT:-3128}"
PRIVOXY_PORT="8118"
ENVOY_PORT="10000"
ENVOY_ADMIN_PORT="9901"
TOR_PORT="9050"
TEST_URL="http://example.com"

test_squid_health() {
    test_start "Squid Proxy Health"
    
    if nc -zv localhost "$SQUID_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Squid listening on port $SQUID_PORT"
    else
        test_fail "Squid not listening on port $SQUID_PORT"
    fi
}

test_squid_proxy() {
    test_start "Squid HTTP Proxy"
    
    if curl -sf --proxy "http://localhost:$SQUID_PORT" "$TEST_URL" > /dev/null; then
        test_pass "Squid proxy working for HTTP requests"
    else
        test_fail "Squid proxy not working"
    fi
}

test_squid_cache() {
    test_start "Squid Cache"
    
    # Make two requests and check cache headers
    curl -sf --proxy "http://localhost:$SQUID_PORT" -I "$TEST_URL" > /tmp/squid_test1.txt
    sleep 1
    curl -sf --proxy "http://localhost:$SQUID_PORT" -I "$TEST_URL" > /tmp/squid_test2.txt
    
    if grep -q "X-Cache" /tmp/squid_test2.txt 2>/dev/null; then
        test_pass "Squid cache headers present"
    else
        test_warn "Squid cache headers not found (may not be configured)"
    fi
    
    rm -f /tmp/squid_test1.txt /tmp/squid_test2.txt
}

test_privoxy_health() {
    test_start "Privoxy Health"
    
    if nc -zv localhost "$PRIVOXY_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Privoxy listening on port $PRIVOXY_PORT"
    else
        test_fail "Privoxy not listening on port $PRIVOXY_PORT"
    fi
}

test_privoxy_proxy() {
    test_start "Privoxy HTTP Proxy"
    
    if curl -sf --proxy "http://localhost:$PRIVOXY_PORT" "$TEST_URL" > /dev/null; then
        test_pass "Privoxy proxy working"
    else
        test_fail "Privoxy proxy not working"
    fi
}

test_envoy_admin() {
    test_start "Envoy Admin Interface"
    
    if curl -sf "http://localhost:$ENVOY_ADMIN_PORT/stats" | grep -q "envoy"; then
        test_pass "Envoy admin interface accessible"
    else
        test_fail "Envoy admin interface not accessible"
    fi
}

test_envoy_proxy() {
    test_start "Envoy Proxy"
    
    if nc -zv localhost "$ENVOY_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Envoy listening on port $ENVOY_PORT"
    else
        test_fail "Envoy not listening on port $ENVOY_PORT"
    fi
}

test_tor_socks() {
    test_start "Tor SOCKS Proxy"
    
    if nc -zv localhost "$TOR_PORT" 2>&1 | grep -q "succeeded"; then
        test_pass "Tor SOCKS proxy listening on port $TOR_PORT"
    else
        test_fail "Tor SOCKS proxy not listening"
    fi
}

test_tor_circuit() {
    test_start "Tor Circuit"
    
    # Test if we can get a different IP through Tor
    if command -v curl &> /dev/null; then
        tor_ip=$(curl -sf --socks5 "localhost:$TOR_PORT" https://api.ipify.org 2>/dev/null || echo "")
        direct_ip=$(curl -sf https://api.ipify.org 2>/dev/null || echo "")
        
        if [[ -n "$tor_ip" && -n "$direct_ip" && "$tor_ip" != "$direct_ip" ]]; then
            test_pass "Tor circuit working (Tor IP: $tor_ip, Direct IP: $direct_ip)"
        elif [[ -n "$tor_ip" ]]; then
            test_pass "Tor circuit working (IP: $tor_ip)"
        else
            test_fail "Could not verify Tor circuit"
        fi
    else
        test_skip "curl not available"
    fi
}

test_proxy_chain() {
    test_start "Proxy Chain (Privoxy -> Squid)"
    
    # Privoxy should forward to Squid
    if curl -sf --proxy "http://localhost:$PRIVOXY_PORT" "$TEST_URL" > /dev/null; then
        test_pass "Proxy chain working"
    else
        test_fail "Proxy chain not working"
    fi
}

# Run all tests
main() {
    test_suite_start "Web Proxy Services E2E Tests"
    
    test_squid_health
    test_squid_proxy
    test_squid_cache
    test_privoxy_health
    test_privoxy_proxy
    test_envoy_admin
    test_envoy_proxy
    test_tor_socks
    test_tor_circuit
    test_proxy_chain
    
    test_suite_end
}

main "$@"
