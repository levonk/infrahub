#!/bin/bash
# Home Lab In-a-Box - Blocklist Update Script
# Purpose: Download and compile blocklists to CDB format

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}" >&2
}

# Error handler
trap 'error "An error occurred on line $LINENO. Exiting with status $?"' ERR

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

log "=== Blocklist Update Started ==="
log "User: $(whoami)"
log "Working Directory: $(pwd)"

# Log Configuration
log "Configuration:"
echo "  SOURCES_DIR: $SOURCES_DIR"
echo "  COMPILED_DIR: $COMPILED_DIR"
echo "  TEMP_DIR: $TEMP_DIR"

# Check disk space
log "Disk Space:"
df -h "$COMPILED_DIR" || warn "Could not check disk space for $COMPILED_DIR"

# Create directories
log "Creating directories..."
mkdir -p "$SOURCES_DIR" "$COMPILED_DIR" "$TEMP_DIR"

# Download StevenBlack hosts
log "Downloading StevenBlack hosts from $STEVENBLACK_URL..."
if curl -fsSL "$STEVENBLACK_URL" -o "$TEMP_DIR/stevenblack.txt"; then
    SIZE=$(du -h "$TEMP_DIR/stevenblack.txt" | cut -f1)
    LINES_STEVENBLACK=$(wc -l < "$TEMP_DIR/stevenblack.txt")
    success "StevenBlack downloaded ($SIZE, $LINES_STEVENBLACK lines)"
else
    error "Failed to download StevenBlack"
    warn "Continuing with other lists..."
fi

# Download AdAway
log "Downloading AdAway from $ADAWAY_URL..."
if curl -fsSL "$ADAWAY_URL" -o "$TEMP_DIR/adaway.txt"; then
    SIZE=$(du -h "$TEMP_DIR/adaway.txt" | cut -f1)
    LINES_ADAWAY=$(wc -l < "$TEMP_DIR/adaway.txt")
    success "AdAway downloaded ($SIZE, $LINES_ADAWAY lines)"
else
    error "Failed to download AdAway"
    warn "Continuing with other lists..."
fi

# Download Disconnect.me
log "Downloading Disconnect.me from $DISCONNECT_URL..."
if curl -fsSL "$DISCONNECT_URL" -o "$TEMP_DIR/disconnect.txt"; then
    SIZE=$(du -h "$TEMP_DIR/disconnect.txt" | cut -f1)
    LINES_DISCONNECT=$(wc -l < "$TEMP_DIR/disconnect.txt")
    success "Disconnect.me downloaded ($SIZE, $LINES_DISCONNECT lines)"
else
    error "Failed to download Disconnect.me"
    warn "Continuing with other lists..."
fi

# Download EasyList (convert to hosts format)
log "Downloading EasyList from $EASYLIST_URL..."
if curl -fsSL "$EASYLIST_URL" -o "$TEMP_DIR/easylist.txt"; then
    SIZE=$(du -h "$TEMP_DIR/easylist.txt" | cut -f1)
    log "Extracting domains from EasyList..."
    grep -E '^\|\|[a-zA-Z0-9.-]+\^' "$TEMP_DIR/easylist.txt" | \
        sed 's/^||//; s/\^.*//' > "$TEMP_DIR/easylist_domains.txt" || true

    if [ -f "$TEMP_DIR/easylist_domains.txt" ]; then
        LINES_EASYLIST=$(wc -l < "$TEMP_DIR/easylist_domains.txt")
        success "EasyList downloaded and converted ($LINES_EASYLIST domains extracted)"
    else
        warn "EasyList conversion resulted in empty file"
    fi
else
    error "Failed to download EasyList"
    warn "Continuing with other lists..."
fi

# Check if we have any files to process
count_files=$(ls -1 "$TEMP_DIR"/*.txt 2>/dev/null | wc -l)
if [ "$count_files" -eq 0 ]; then
    error "No blocklists were downloaded successfully. Aborting."
    exit 1
fi

# Statistics collection
START_TIME=$(date +%s)
STATS_FILE="$TEMP_DIR/stats.txt"
touch "$STATS_FILE"

# Function to record stats
record_stat() {
  echo "$1: $2" >> "$STATS_FILE"
}

# Combine all blocklists
log "Combining blocklists from $count_files source files..."
cat "$TEMP_DIR"/*.txt 2>/dev/null | \
    grep -v '^#' | \
    grep -v '^$' | \
    grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' | \
    sort -u > "$TEMP_COMBINED_TXT_FILE"

if [ ! -s "$TEMP_COMBINED_TXT_FILE" ]; then
    error "Combined blocklist is empty!"
    exit 1
fi

TOTAL_DOMAINS=$(wc -l < "$TEMP_COMBINED_TXT_FILE")
success "Combined ${TOTAL_DOMAINS} unique domains"

# Record counts per source
record_stat "StevenBlack" "$LINES_STEVENBLACK"
record_stat "AdAway" "$LINES_ADAWAY"
record_stat "Disconnect.me" "$LINES_DISCONNECT"
record_stat "EasyList" "$LINES_EASYLIST"

# Record combined and deduplicated counts
record_stat "TotalBeforeDedupe" "$(cat "$TEMP_DIR"/*.txt 2>/dev/null | wc -l)"
record_stat "TotalUniqueDomains" "$TOTAL_DOMAINS"

# Record file sizes
record_stat "CombinedSize" "$(du -h "$TEMP_COMBINED_TXT_FILE" | cut -f1)"

# Convert to CDB format
log "Converting to CDB format..."
if command -v cdb &> /dev/null; then
    log "Using cdb command..."
    # Create CDB input format (key\tvalue)
    log "Creating CDB input format..."
    awk '{print $1 "\t1"}' "$TEMP_COMBINED_TXT_FILE" | \
        cdb -mc "$TEMP_COMBINED_CDB_FILE"

    # Verify CDB file
    if [[ -f "$TEMP_COMBINED_CDB_FILE" ]]; then
        CDB_SIZE=$(stat -c%s "$TEMP_COMBINED_CDB_FILE" 2>/dev/null || stat -f%z "$TEMP_COMBINED_CDB_FILE")
        success "CDB file created ($CDB_SIZE bytes)"
        record_stat "CDBSize" "$(du -h "$TEMP_COMBINED_CDB_FILE" | cut -f1)"

        # Atomic replacement
        log "Moving CDB file to final destination: $FINAL_COMBINED_CDB_FILE"
        mv "$TEMP_COMBINED_CDB_FILE" "$FINAL_COMBINED_CDB_FILE"
        success "Blocklist updated successfully"
    else
        error "Failed to create CDB file"
        exit 1
    fi
else
    warn "cdb command not found, attempting to install tinycdb..."
    if command -v apk &> /dev/null; then
        apk add --no-cache tinycdb
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y tinycdb
    elif command -v yum &> /dev/null; then
        yum install -y tinycdb
    else
        error "Could not find package manager to install tinycdb"
        exit 1
    fi

    warn "Please run this script again after installation"
    exit 1
fi

# Record execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))
record_stat "ExecutionTime" "${EXECUTION_TIME}s"

# Print stats
log "=== Blocklist Statistics ==="
cat "$STATS_FILE"

# Save source files for reference
BACKUP_FILE="$SOURCES_DIR/combined-$(date +%Y%m%d).txt"
log "Saving backup to $BACKUP_FILE"
cp "$TEMP_COMBINED_TXT_FILE" "$BACKUP_FILE"

# Cleanup
log "Cleaning up temporary directory: $TEMP_DIR"

echo ""
echo -e "${GREEN}=== Blocklist Update Complete ===${NC}"
echo "Total domains: $TOTAL_DOMAINS"
echo "CDB file: $FINAL_COMBINED_CDB_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
