#!/bin/bash
# NTP Accuracy Health Check
# Verifies chronyd offset is <10ms as per NFR-1 requirements

set -e

# Configuration
MAX_OFFSET_MS=10
CHRONYD_CONTAINER="localnet-chronyd"

echo "=== NTP Accuracy Health Check ==="
echo "Maximum allowed offset: ${MAX_OFFSET_MS}ms"
echo ""

# Check if chronyd container is running
if ! docker compose ps ${CHRONYD_CONTAINER} | grep -q "Up"; then
    echo "❌ FAIL: chronyd container is not running"
    exit 1
fi

echo "✓ chronyd container is running"

# Get tracking information from chronyd
TRACKING_OUTPUT=$(docker compose exec -T chronyd chronyc tracking 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ FAIL: Could not get chronyd tracking information"
    echo "Error: ${TRACKING_OUTPUT}"
    exit 1
fi

echo "✓ Retrieved chronyd tracking information"
echo ""

# Parse offset from tracking output
# Example line: "System time     : 0.000002345 seconds slow of NTP time"
OFFSET_LINE=$(echo "${TRACKING_OUTPUT}" | grep "System time")

if [ -z "${OFFSET_LINE}" ]; then
    echo "❌ FAIL: Could not parse system time offset"
    echo "Tracking output:"
    echo "${TRACKING_OUTPUT}"
    exit 1
fi

# Extract offset value (in seconds)
OFFSET_SECONDS=$(echo "${OFFSET_LINE}" | awk '{print $4}')

# Convert to milliseconds (multiply by 1000)
OFFSET_MS=$(echo "${OFFSET_SECONDS} * 1000" | bc -l)

# Get absolute value
OFFSET_MS_ABS=$(echo "${OFFSET_MS}" | awk '{print ($1 < 0) ? -$1 : $1}')

echo "Current NTP offset: ${OFFSET_MS_ABS}ms"
echo ""

# Check if offset is within acceptable range
OFFSET_CHECK=$(echo "${OFFSET_MS_ABS} < ${MAX_OFFSET_MS}" | bc -l)

if [ "${OFFSET_CHECK}" -eq 1 ]; then
    echo "✅ PASS: NTP offset (${OFFSET_MS_ABS}ms) is within acceptable range (<${MAX_OFFSET_MS}ms)"
    
    # Additional checks
    echo ""
    echo "=== Additional NTP Status ==="
    
    # Check stratum
    STRATUM=$(echo "${TRACKING_OUTPUT}" | grep "Stratum" | awk '{print $3}')
    echo "Stratum: ${STRATUM}"
    
    # Check reference
    REFERENCE=$(echo "${TRACKING_OUTPUT}" | grep "Reference ID" | awk '{print $4, $5}')
    echo "Reference: ${REFERENCE}"
    
    # Check last update
    LAST_UPDATE=$(echo "${TRACKING_OUTPUT}" | grep "Last update" | awk '{print $4, $5, $6}')
    echo "Last update: ${LAST_UPDATE}"
    
    exit 0
else
    echo "❌ FAIL: NTP offset (${OFFSET_MS_ABS}ms) exceeds maximum allowed (${MAX_OFFSET_MS}ms)"
    echo ""
    echo "Full tracking output:"
    echo "${TRACKING_OUTPUT}"
    exit 1
fi
