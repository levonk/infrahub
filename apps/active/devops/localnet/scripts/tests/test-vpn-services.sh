#!/usr/bin/env bash
# E2E Tests for VPN Services (WireGuard Direct & Transparent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
WG_DIRECT_PORT="${WIREGUARD_DIRECT_PORT:-51820}"
WG_TRANSPARENT_PORT="${WIREGUARD_TRANSPARENT_PORT:-51821}"

test_wireguard_direct_health() {
    test_start "WireGuard Direct Health"
    
    if docker exec homelab-wireguard-direct test -f /config/wg0.conf; then
        test_pass "WireGuard direct config exists"
    else
        test_fail "WireGuard direct config missing"
    fi
}

test_wireguard_direct_interface() {
    test_start "WireGuard Direct Interface"
    
    if docker exec homelab-wireguard-direct wg show 2>&1 | grep -q "interface: wg0"; then
        test_pass "WireGuard direct interface active"
    else
        test_fail "WireGuard direct interface not active"
    fi
}

test_wireguard_direct_port() {
    test_start "WireGuard Direct Port"
    
    if docker exec homelab-wireguard-direct ss -ulnp | grep -q ":$WG_DIRECT_PORT"; then
        test_pass "WireGuard direct listening on UDP port $WG_DIRECT_PORT"
    else
        test_fail "WireGuard direct not listening on port $WG_DIRECT_PORT"
    fi
}

test_wireguard_transparent_health() {
    test_start "WireGuard Transparent Health"
    
    if docker exec homelab-wireguard-transparent test -f /config/wg0.conf; then
        test_pass "WireGuard transparent config exists"
    else
        test_fail "WireGuard transparent config missing"
    fi
}

test_wireguard_transparent_interface() {
    test_start "WireGuard Transparent Interface"
    
    if docker exec homelab-wireguard-transparent wg show 2>&1 | grep -q "interface: wg0"; then
        test_pass "WireGuard transparent interface active"
    else
        test_fail "WireGuard transparent interface not active"
    fi
}

test_wireguard_transparent_port() {
    test_start "WireGuard Transparent Port"
    
    if docker exec homelab-wireguard-transparent ss -ulnp | grep -q ":$WG_TRANSPARENT_PORT"; then
        test_pass "WireGuard transparent listening on UDP port $WG_TRANSPARENT_PORT"
    else
        test_fail "WireGuard transparent not listening on port $WG_TRANSPARENT_PORT"
    fi
}

test_transparent_gateway() {
    test_start "Transparent Gateway"
    
    if docker ps --filter "name=homelab-transparent-gateway" --format "{{.Status}}" | grep -q "Up"; then
        test_pass "Transparent gateway container running"
    else
        test_fail "Transparent gateway container not running"
    fi
}

test_wireguard_peer_config() {
    test_start "WireGuard Peer Configuration"
    
    peer_count=$(docker exec homelab-wireguard-direct wg show wg0 peers 2>/dev/null | wc -l || echo "0")
    
    if [[ "$peer_count" -gt 0 ]]; then
        test_pass "WireGuard has $peer_count peer(s) configured"
    else
        test_warn "No WireGuard peers configured yet"
    fi
}

test_wireguard_qr_codes() {
    test_start "WireGuard QR Codes"
    
    if docker exec homelab-wireguard-direct ls /config/peer* 2>/dev/null | grep -q "peer"; then
        test_pass "WireGuard peer configs available"
    else
        test_warn "No WireGuard peer configs found"
    fi
}

# Run all tests
main() {
    test_suite_start "VPN Services E2E Tests"
    
    test_wireguard_direct_health
    test_wireguard_direct_interface
    test_wireguard_direct_port
    test_wireguard_transparent_health
    test_wireguard_transparent_interface
    test_wireguard_transparent_port
    test_transparent_gateway
    test_wireguard_peer_config
    test_wireguard_qr_codes
    
    test_suite_end
}

main "$@"
