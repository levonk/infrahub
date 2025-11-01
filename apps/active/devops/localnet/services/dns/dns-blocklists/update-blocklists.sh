#!/bin/bash
# Home Lab In-a-Box - Blocklist Update Script
# Purpose: Download and compile blocklists to CDB format

set -uo pipefail

# Configuration
SOURCES_DIR="/blocklists/sources"
COMPILED_DIR="/blocklists/compiled"
TEMP_DIR="/tmp/blocklists-$$"
TEMP_COMBINED_TXT_FILE="$TEMP_DIR/combined.txt"
TEMP_COMBINED_CDBINPUT_FILE="$TEMP_DIR/combined.cdb_input"
TEMP_COMBINED_CDB_FILE="$TEMP_DIR/combined.cdb"
FINAL_COMBINED_CDB_FILE="$COMPILED_DIR/blocklist.cdb"

# Blocklist URLs
STEVENBLACK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
ADAWAY_URL="https://adaway.org/hosts.txt"
PHISHTANK_URL="https://data.phishtank.com/data/online-valid.csv"
EASYLIST_URL="https://easylist.to/easylist/easylist.txt"
DISCONNECT_URL="https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Blocklist Update Started ===${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Create directories
mkdir -p "$SOURCES_DIR" "$COMPILED_DIR" "$TEMP_DIR"

# Download StevenBlack hosts
echo -e "${BLUE}Downloading StevenBlack hosts...${NC}"
if curl -fsSL "$STEVENBLACK_URL" -o "$TEMP_DIR/stevenblack.txt"; then
    echo -e "${GREEN}✓ StevenBlack downloaded${NC}"
else
    echo -e "${RED}✗ Failed to download StevenBlack${NC}"
fi

# Download AdAway
echo -e "${BLUE}Downloading AdAway...${NC}"
if curl -fsSL "$ADAWAY_URL" -o "$TEMP_DIR/adaway.txt"; then
    echo -e "${GREEN}✓ AdAway downloaded${NC}"
else
    echo -e "${RED}✗ Failed to download AdAway${NC}"
fi

# Download Disconnect.me
echo -e "${BLUE}Downloading Disconnect.me...${NC}"
if curl -fsSL "$DISCONNECT_URL" -o "$TEMP_DIR/disconnect.txt"; then
    echo -e "${GREEN}✓ Disconnect.me downloaded${NC}"
else
    echo -e "${RED}✗ Failed to download Disconnect.me${NC}"
fi

# Download EasyList (convert to hosts format)
echo -e "${BLUE}Downloading EasyList...${NC}"
if curl -fsSL "$EASYLIST_URL" -o "$TEMP_DIR/easylist.txt"; then
    # Extract domains from EasyList format
    grep -E '^\|\|[a-zA-Z0-9.-]+\^' "$TEMP_DIR/easylist.txt" | \
        sed 's/^||//; s/\^.*//' > "$TEMP_DIR/easylist_domains.txt" || true
    echo -e "${GREEN}✓ EasyList downloaded and converted${NC}"
else
    echo -e "${RED}✗ Failed to download EasyList${NC}"
fi

# Combine all blocklists
echo -e "${BLUE}Combining blocklists...${NC}"
cat "$TEMP_DIR"/*.txt 2>/dev/null | \
    grep -v '^#' | \
    grep -v '^$' | \
    grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' | \
    sort -u > "$TEMP_COMBINED_TXT_FILE"

TOTAL_DOMAINS=$(wc -l < "$TEMP_COMBINED_TXT_FILE")
echo -e "${GREEN}✓ Combined ${TOTAL_DOMAINS} unique domains${NC}"

# Convert to CDB format
echo -e "${BLUE}Converting to CDB format...${NC}"
if command -v cdb &> /dev/null; then
    # Create CDB input format (key\tvalue)
    awk '{print $1 "\t1"}' "$TEMP_COMBINED_TXT_FILE" | \
        cdb -mc "$TEMP_COMBINED_CDB_FILE"

    # Verify CDB file
    if [[ -f "$TEMP_COMBINED_CDB_FILE" ]]; then
        CDB_SIZE=$(stat -f%z "$TEMP_COMBINED_CDB_FILE" 2>/dev/null || stat -c%s "$TEMP_COMBINED_CDB_FILE")
        echo -e "${GREEN}✓ CDB file created (${CDB_SIZE} bytes)${NC}"

        # Atomic replacement
        mv "$TEMP_COMBINED_CDB_FILE" "$FINAL_COMBINED_CDB_FILE"
        echo -e "${GREEN}✓ Blocklist updated successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create CDB file${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ cdb command not found, installing tinycdb...${NC}"
    apk add --no-cache tinycdb || apt-get install -y tinycdb || yum install -y tinycdb
    echo -e "${YELLOW}Please run this script again${NC}"
    exit 1
fi

# Save source files for reference
cp "$TEMP_COMBINED_TXT_FILE" "$SOURCES_DIR/combined-$(date +%Y%m%d).txt"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}=== Blocklist Update Complete ===${NC}"
echo "Total domains: $TOTAL_DOMAINS"
echo "CDB file: $FINAL_COMBINED_CDB_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
