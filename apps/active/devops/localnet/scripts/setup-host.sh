#!/bin/bash
# Home Lab In-a-Box - Host Setup Script
# Purpose: Install dependencies and optionally configure host for transparent proxying
#
# NOTE: For WSL/Windows/macOS environments, use the container-based transparent gateway instead.
#       See: docs/transparent-proxy-usage.md

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect WSL environment
is_wsl() {
    # Check /proc/version for WSL indicators
    if [[ -f "/proc/version" ]] && grep -qi "microsoft\|wsl" "/proc/version" 2>/dev/null; then
        return 0
    fi

    # Check for WSL-specific environment variables
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSLENV:-}" ]]; then
        return 0
    fi

    # Check uname output
    if [[ "$(uname -r)" == *microsoft* ]] || [[ "$(uname -r)" == *Microsoft* ]]; then
        return 0
    fi

    return 1
}

echo -e "${BLUE}=== Home Lab In-a-Box Host Setup ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Detect environment
if is_wsl; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  WSL2 DETECTED ⚠️                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}WSL2 has significant limitations for transparent proxying:${NC}"
    echo -e "  • nftables rules may not work correctly"
    echo -e "  • Kernel networking features are restricted"
    echo -e "  • IP forwarding and transparent sockets have limited support"
    echo ""
    echo -e "${BLUE}Recommended approach for WSL2/Windows:${NC}"
    echo -e "  Use the ${GREEN}container-based transparent gateway${NC} instead."
    echo -e "  See: ${YELLOW}docs/transparent-proxy-usage.md${NC}"
    echo ""
    echo -e "${YELLOW}This script can still install WSL2-compatible packages (bc),${NC}"
    echo -e "${YELLOW}but will skip nftables/sysctl configuration.${NC}"
    echo ""
    read -p "Continue with limited setup? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Setup aborted. Please use the container-based gateway instead.${NC}"
        exit 0
    fi
    echo ""
    echo -e "${GREEN}Proceeding with package installation only...${NC}"
    echo ""
    SKIP_NFTABLES=true
else
    echo -e "${BLUE}Linux host detected - full setup will be performed${NC}"
    echo ""
    SKIP_NFTABLES=false
fi

# Check if required packages are installed
# Core utilities used by the project:
#   bc         - Math calculations in NTP accuracy tests
#   chronyc    - Modern NTP client for host-to-docker NTP testing
#   curl       - HTTP requests in health checks and tests
#   dig        - DNS queries in DNS leak tests
#   docker     - Container runtime (required)
#   make       - Build automation (Makefile commands)
#   nc         - Netcat for TCP port testing (NTP, DNS)
#   ntpdate    - Legacy NTP client for host-to-docker NTP testing (deprecated but still useful)
# Note: chronyd service will be disabled/masked to avoid time-daemon conflicts
REQUIRED_PACKAGES=("bc" "chronyc" "curl" "dig" "docker" "make" "nc" "ntpdate")

# Add nftables only for non-WSL environments
if [[ "$SKIP_NFTABLES" == "false" ]]; then
    REQUIRED_PACKAGES+=("nft")
fi

PACKAGES_TO_INSTALL=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        case "$pkg" in
            nft)
                PACKAGES_TO_INSTALL+=("nftables")
                ;;
            bc)
                PACKAGES_TO_INSTALL+=("bc")
                ;;
            chronyc)
                PACKAGES_TO_INSTALL+=("chrony")
                ;;
            curl)
                PACKAGES_TO_INSTALL+=("curl")
                ;;
            dig)
                PACKAGES_TO_INSTALL+=("dnsutils")
                ;;
            nc)
                PACKAGES_TO_INSTALL+=("netcat-openbsd")
                ;;
            ntpdate)
                PACKAGES_TO_INSTALL+=("ntpdate")
                ;;
            docker)
                # Docker requires special installation - provide instructions
                echo -e "${YELLOW}⚠️  Docker is not installed${NC}"
                echo -e "${BLUE}Docker installation required. Please install Docker first:${NC}"
                echo -e "  • Debian/Ubuntu: https://docs.docker.com/engine/install/debian/"
                echo -e "  • WSL2: Install Docker Desktop for Windows"
                echo -e "  • Other: https://docs.docker.com/engine/install/"
                echo ""
                exit 1
                ;;
            make)
                PACKAGES_TO_INSTALL+=("make")
                ;;
        esac
    fi
done

if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Installing required packages: ${PACKAGES_TO_INSTALL[*]}...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
    elif command -v yum &> /dev/null; then
        yum install -y "${PACKAGES_TO_INSTALL[@]}"
    elif command -v dnf &> /dev/null; then
        dnf install -y "${PACKAGES_TO_INSTALL[@]}"
    else
        echo -e "${RED}Error: Could not install packages (unknown package manager)${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Packages installed successfully${NC}"
else
    echo -e "${GREEN}✓ All required packages already installed${NC}"
fi
echo ""

# Manage chronyd service - only disable if another time daemon is running
if command -v chronyc &> /dev/null && command -v systemctl &> /dev/null; then
    echo -e "${BLUE}Checking time daemon configuration...${NC}"
    
    # Check for other time daemons (ntpsec, systemd-timesyncd, etc.)
    OTHER_TIME_DAEMON_RUNNING=false
    
    # Check for ntpsec
    if systemctl is-active --quiet ntpsec 2>/dev/null || systemctl is-active --quiet ntp 2>/dev/null; then
        OTHER_TIME_DAEMON_RUNNING=true
        TIME_DAEMON_NAME="ntpsec/ntp"
    fi
    
    # Check for systemd-timesyncd
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        OTHER_TIME_DAEMON_RUNNING=true
        TIME_DAEMON_NAME="systemd-timesyncd"
    fi

    if [[ "$OTHER_TIME_DAEMON_RUNNING" == "true" ]]; then
        # Another time daemon is running - disable chronyd to avoid conflict
        echo -e "${YELLOW}Detected active time daemon: ${TIME_DAEMON_NAME}${NC}"
        echo -e "${BLUE}Disabling chronyd to avoid time-daemon conflict...${NC}"
        
        # Stop the service if it's running
        if systemctl is-active --quiet chronyd 2>/dev/null; then
            systemctl stop chronyd 2>/dev/null || true
        fi
        
        # Disable and mask the service
        systemctl disable chronyd 2>/dev/null || true
        systemctl mask chronyd 2>/dev/null || true
        
        echo -e "${GREEN}✓ chronyd service disabled and masked (using ${TIME_DAEMON_NAME} instead)${NC}"
        echo -e "${BLUE}chronyc client tool is still available for testing${NC}"
    else
        # No other time daemon - let chronyd run as the time server
        echo -e "${GREEN}No conflicting time daemon detected${NC}"
        echo -e "${BLUE}Enabling chronyd as the system time daemon...${NC}"
        
        # Unmask if previously masked
        systemctl unmask chronyd 2>/dev/null || true
        
        # Enable and start chronyd
        systemctl enable chronyd 2>/dev/null || true
        systemctl start chronyd 2>/dev/null || true
        
        if systemctl is-active --quiet chronyd 2>/dev/null; then
            echo -e "${GREEN}✓ chronyd service enabled and running${NC}"
        else
            echo -e "${YELLOW}⚠ chronyd service enabled but not running - may start on next boot${NC}"
        fi
    fi
    echo ""
fi

if [[ "$SKIP_NFTABLES" == "false" ]]; then
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
    echo ""
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
else
    # WSL/container-based setup
    echo -e "${GREEN}=== Setup complete! ===${NC}"
    echo ""
    echo -e "${BLUE}Next steps for WSL/Windows users:${NC}"
    echo -e "  1. Configure .env file with your HOST_IP"
    echo -e "  2. Run: ${YELLOW}make up${NC}"
    echo -e "  3. Run: ${YELLOW}make health-check${NC}"
    echo ""
    echo -e "${BLUE}The transparent-gateway container will handle traffic interception.${NC}"
    echo -e "See: ${YELLOW}docs/transparent-proxy-usage.md${NC} for details."
fi
