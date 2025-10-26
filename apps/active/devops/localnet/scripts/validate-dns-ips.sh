#!/bin/bash
set -euo pipefail

# Validate DNS container IP addresses match configuration
# Run this after 'docker compose up' to verify IP assignments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Expected IPs from docker-compose.yml (high range, reserved for DNS)
EXPECTED_COREDNS_IP="172.20.255.51"
EXPECTED_DNSCRYPT_IP="172.20.255.50"

# Expected IPs from dnsdist.conf
DNSDIST_COREDNS_IP=$(grep -oP 'address="\K[0-9.]+(?=:53".*name="coredns")' "$PROJECT_DIR/configs/dns/dnsdist.conf" || echo "")
DNSDIST_DNSCRYPT_IP=$(grep -oP 'address="\K[0-9.]+(?=:5300".*name="dnscrypt-proxy")' "$PROJECT_DIR/configs/dns/dnsdist.conf" || echo "")

echo "========================================="
echo "DNS IP Address Validation"
echo "========================================="
echo ""

# Get actual IPs from running containers
<<<<<<< HEAD
ACTUAL_COREDNS_IP=$(docker inspect homelab-coredns --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "NOT_RUNNING")
ACTUAL_DNSCRYPT_IP=$(docker inspect homelab-dnscrypt-proxy --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "NOT_RUNNING")
=======
ACTUAL_COREDNS_IP=$(docker inspect homelab-dns-coredns --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "NOT_RUNNING")
ACTUAL_DNSCRYPT_IP=$(docker inspect homelab-dns-dnscrypt-proxy --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "NOT_RUNNING")
>>>>>>> 002-claude-code-integration

# Validation flags
ALL_VALID=true

# Check coredns
echo "CoreDNS:"
echo "  Expected (docker-compose.yml): $EXPECTED_COREDNS_IP"
echo "  Expected (dnsdist.conf):       $DNSDIST_COREDNS_IP"
echo "  Actual (running container):    $ACTUAL_COREDNS_IP"

if [ "$ACTUAL_COREDNS_IP" = "NOT_RUNNING" ]; then
    echo "  ❌ FAIL: Container not running"
    ALL_VALID=false
elif [ "$ACTUAL_COREDNS_IP" != "$EXPECTED_COREDNS_IP" ]; then
    echo "  ❌ FAIL: IP mismatch with docker-compose.yml"
    ALL_VALID=false
elif [ "$ACTUAL_COREDNS_IP" != "$DNSDIST_COREDNS_IP" ]; then
    echo "  ❌ FAIL: IP mismatch with dnsdist.conf"
    ALL_VALID=false
else
    echo "  ✅ PASS: All IPs match"
fi
echo ""

# Check dnscrypt-proxy
echo "dnscrypt-proxy:"
echo "  Expected (docker-compose.yml): $EXPECTED_DNSCRYPT_IP"
echo "  Expected (dnsdist.conf):       $DNSDIST_DNSCRYPT_IP"
echo "  Actual (running container):    $ACTUAL_DNSCRYPT_IP"

if [ "$ACTUAL_DNSCRYPT_IP" = "NOT_RUNNING" ]; then
    echo "  ❌ FAIL: Container not running"
    ALL_VALID=false
elif [ "$ACTUAL_DNSCRYPT_IP" != "$EXPECTED_DNSCRYPT_IP" ]; then
    echo "  ❌ FAIL: IP mismatch with docker-compose.yml"
    ALL_VALID=false
elif [ "$ACTUAL_DNSCRYPT_IP" != "$DNSDIST_DNSCRYPT_IP" ]; then
    echo "  ❌ FAIL: IP mismatch with dnsdist.conf"
    ALL_VALID=false
else
    echo "  ✅ PASS: All IPs match"
fi
echo ""

# Summary and remediation
echo "========================================="
if [ "$ALL_VALID" = true ]; then
    echo "✅ All DNS IP addresses are correctly configured"
    echo "========================================="
    exit 0
else
    echo "❌ IP address mismatches detected"
    echo "========================================="
    echo ""
    echo "REMEDIATION OPTIONS:"
    echo ""
    echo "Option 1: Recreate containers to match configuration"
    echo "  docker compose down dnsdist coredns dnscrypt-proxy"
    echo "  docker compose up -d dnscrypt-proxy coredns dnsdist"
    echo "  # Then run this script again to verify"
    echo ""
    echo "Option 2: Update docker-compose.yml to match actual IPs"
    echo "  Edit: $PROJECT_DIR/docker-compose.yml"
    echo "  Set coredns ipv4_address: $ACTUAL_COREDNS_IP"
    echo "  Set dnscrypt-proxy ipv4_address: $ACTUAL_DNSCRYPT_IP"
    echo ""
    echo "Option 3: Update dnsdist.conf to match actual IPs"
    echo "  Edit: $PROJECT_DIR/configs/dns/dnsdist.conf"
    echo "  Set coredns address: $ACTUAL_COREDNS_IP:53"
    echo "  Set dnscrypt-proxy address: $ACTUAL_DNSCRYPT_IP:5300"
    echo "  Then: docker compose restart dnsdist"
    echo ""
    exit 1
fi
