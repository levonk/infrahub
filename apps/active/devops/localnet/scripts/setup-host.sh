#!/bin/bash
# Home Lab In-a-Box - Host Setup Script
# Purpose: Configure host system for transparent proxying

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Home Lab In-a-Box Host Setup ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if nftables is installed
if ! command -v nft &> /dev/null; then
    echo -e "${YELLOW}Installing nftables...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y nftables
    elif command -v yum &> /dev/null; then
        yum install -y nftables
    elif command -v dnf &> /dev/null; then
        dnf install -y nftables
    else
        echo -e "${RED}Error: Could not install nftables (unknown package manager)${NC}"
        exit 1
    fi
fi

# Enable IP forwarding
echo -e "${BLUE}Configuring IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.forwarding=1

# Make IP forwarding persistent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.conf.all.forwarding=1" /etc/sysctl.conf; then
    echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
fi

# Enable IP_TRANSPARENT socket option
echo -e "${BLUE}Configuring IP_TRANSPARENT...${NC}"
sysctl -w net.ipv4.ip_nonlocal_bind=1

# Make IP_TRANSPARENT persistent
if ! grep -q "net.ipv4.ip_nonlocal_bind=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
fi

# Load nftables rules
echo -e "${BLUE}Loading nftables rules...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NFTABLES_CONF="${SCRIPT_DIR}/../configs/nftables/transparent-proxy.nft"

if [[ ! -f "$NFTABLES_CONF" ]]; then
    echo -e "${RED}Error: nftables config not found at $NFTABLES_CONF${NC}"
    exit 1
fi

nft -f "$NFTABLES_CONF"

# Make nftables rules persistent
echo -e "${BLUE}Making nftables rules persistent...${NC}"
if command -v nft &> /dev/null; then
    # Save current ruleset
    nft list ruleset > /etc/nftables.conf
    
    # Enable nftables service
    if command -v systemctl &> /dev/null; then
        systemctl enable nftables
        systemctl start nftables
    fi
fi

# Verify configuration
echo -e "${BLUE}Verifying configuration...${NC}"
echo -e "${GREEN}✓ IP forwarding enabled:${NC} $(sysctl net.ipv4.ip_forward | awk '{print $3}')"
echo -e "${GREEN}✓ IP_TRANSPARENT enabled:${NC} $(sysctl net.ipv4.ip_nonlocal_bind | awk '{print $3}')"
echo -e "${GREEN}✓ nftables rules loaded${NC}"

# Show loaded rules
echo ""
echo -e "${BLUE}Loaded nftables rules:${NC}"
nft list ruleset | grep -A 20 "table inet transparent_proxy" || echo "No transparent_proxy table found"

echo ""
echo -e "${GREEN}=== Host setup complete! ===${NC}"
echo -e "${YELLOW}Note: You may need to reboot for all changes to take effect${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Configure .env file with your HOST_IP"
echo -e "  2. Run: make up"
echo -e "  3. Run: make health-check"
