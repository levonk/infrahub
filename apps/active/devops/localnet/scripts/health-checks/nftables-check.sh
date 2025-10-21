#!/bin/bash
# Home Lab In-a-Box - nftables Health Check
# Purpose: Verify TPROXY rules are active

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Checking nftables TPROXY rules..."

# Check if nftables is running
if ! command -v nft &> /dev/null; then
    echo -e "${RED}✗ nftables not installed${NC}"
    exit 1
fi

# Check for transparent_proxy table
if ! nft list tables | grep -q "inet transparent_proxy"; then
    echo -e "${RED}✗ transparent_proxy table not found${NC}"
    exit 1
fi

# Check for TPROXY rules
if ! nft list ruleset | grep -q "tproxy to"; then
    echo -e "${RED}✗ TPROXY rules not found${NC}"
    exit 1
fi

# Check for packet marking
if ! nft list ruleset | grep -q "meta mark set 1"; then
    echo -e "${RED}✗ Packet marking not configured${NC}"
    exit 1
fi

# Check IP forwarding
if [[ $(sysctl -n net.ipv4.ip_forward) != "1" ]]; then
    echo -e "${YELLOW}⚠ IP forwarding not enabled${NC}"
    exit 1
fi

# Check IP_TRANSPARENT
if [[ $(sysctl -n net.ipv4.ip_nonlocal_bind) != "1" ]]; then
    echo -e "${YELLOW}⚠ IP_TRANSPARENT not enabled${NC}"
    exit 1
fi

echo -e "${GREEN}✓ nftables TPROXY rules active${NC}"
exit 0
