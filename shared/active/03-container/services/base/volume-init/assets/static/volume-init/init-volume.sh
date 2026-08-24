#!/bin/sh
# init-volume.sh — fix Docker volume ownership with validation, logging, and verification.
#
# Usage: docker run --rm -v <volume>:/data localnet-volume-init:latest <uid> <gid> [mode]
#        docker run --rm -e DATA_DIR=/custom/path -v <volume>:/custom/path \
#          localnet-volume-init:latest <uid> <gid> [mode]
#
# Exit codes:
#   0 = success (volume already correct, or chown + verify passed)
#   1 = parameter error (missing/non-numeric uid/gid)
#   2 = chown or chmod failed
#   3 = persistence verify failed (volume driver quirk — see ADR-20260822001 recovery)
#   4 = in-container verify failed (overlay/fs issue — see ADR-20260822001 recovery)
#
# Per ADR-20260822001: Parameterized Utility Container pattern. This script
# implements Phase 1 (chown) + Phase 1.5 (in-container verify) of the ADR's
# three-phase init. The caller should ALSO run verify-volume.sh in a separate
# container (fresh mount namespace) to get a true Phase 2 persistence check.

set -eu

DATA_DIR="${DATA_DIR:-/data}"
UID_TARGET="${1:-}"
GID_TARGET="${2:-}"
MODE="${3:-755}"

# --- Parameter validation ---
if [ -z "$UID_TARGET" ] || [ -z "$GID_TARGET" ]; then
    echo "ERROR: Usage: init-volume <uid> <gid> [mode]" >&2
    echo "  uid   — target UID (numeric, required)" >&2
    echo "  gid   — target GID (numeric, required)" >&2
    echo "  mode  — directory mode (default: 755)" >&2
    echo "" >&2
    echo "Environment:" >&2
    echo "  DATA_DIR — mount point inside the container (default: /data)" >&2
    exit 1
fi

# Validate UID/GID are numeric (rejects empty, negative, or non-numeric strings).
case "$UID_TARGET" in
    ''|*[!0-9]*) echo "ERROR: UID must be numeric, got: $UID_TARGET" >&2; exit 1 ;;
esac
case "$GID_TARGET" in
    ''|*[!0-9]*) echo "ERROR: GID must be numeric, got: $GID_TARGET" >&2; exit 1 ;;
esac

echo "INFO: Initializing volume at $DATA_DIR"
echo "INFO: Target ownership: ${UID_TARGET}:${GID_TARGET}"
echo "INFO: Target mode: ${MODE}"

# --- Pre-flight: data directory must exist (volume must be mounted) ---
if [ ! -d "$DATA_DIR" ]; then
    echo "ERROR: Data directory ${DATA_DIR} does not exist" >&2
    echo "  Did you forget to mount the volume with -v <volume>:${DATA_DIR}?" >&2
    exit 2
fi

# --- Show current state ---
CURRENT_UID=$(stat -c %u "$DATA_DIR")
CURRENT_GID=$(stat -c %g "$DATA_DIR")
echo "INFO: Current ownership: ${CURRENT_UID}:${CURRENT_GID}"

if [ "$CURRENT_UID" = "$UID_TARGET" ] && [ "$CURRENT_GID" = "$GID_TARGET" ]; then
    echo "OK: Volume already has correct ownership — no changes needed"
    exit 0
fi

# --- Phase 1: chown ---
echo "INFO: Running chown -R ${UID_TARGET}:${GID_TARGET} ${DATA_DIR}"
if chown -R "${UID_TARGET}:${GID_TARGET}" "$DATA_DIR"; then
    echo "INFO: chown completed successfully"
else
    rc=$?
    echo "ERROR: chown failed with exit code ${rc}" >&2
    echo "  This is a parameter/filesystem error, not a persistence failure." >&2
    exit 2
fi

echo "INFO: Running chmod ${MODE} ${DATA_DIR}"
if ! chmod "$MODE" "$DATA_DIR"; then
    echo "ERROR: chmod failed" >&2
    exit 2
fi

# --- Phase 1.5: in-container verify (within this container's mount namespace) ---
# Catches overlay/fs issues where chown exits 0 but the VFS layer doesn't
# reflect the change even within the same container.
IN_CONTAINER_UID=$(stat -c %u "$DATA_DIR")
IN_CONTAINER_GID=$(stat -c %g "$DATA_DIR")

if [ "$IN_CONTAINER_UID" = "$UID_TARGET" ] && [ "$IN_CONTAINER_GID" = "$GID_TARGET" ]; then
    echo "INFO: In-container verify passed: ${IN_CONTAINER_UID}:${IN_CONTAINER_GID}"
else
    echo "ERROR: In-container verification failed!" >&2
    echo "  Expected: ${UID_TARGET}:${GID_TARGET}" >&2
    echo "  Actual:   ${IN_CONTAINER_UID}:${IN_CONTAINER_GID}" >&2
    echo "" >&2
    echo "The chown command exited 0 but stat inside the same container shows" >&2
    echo "the old ownership. This is NOT a persistence failure — it's an overlay" >&2
    echo "filesystem issue or a read-only mount. Check:" >&2
    echo "  1. Is the volume mounted read-only? (mount | grep ${DATA_DIR})" >&2
    echo "  2. Is the Docker storage driver corrupted? (docker info)" >&2
    echo "  3. Is this a remote/NFS volume with different ownership semantics?" >&2
    echo "See ADR-20260822001 for diagnostics." >&2
    exit 4
fi

# --- Phase 2: persistence verify (re-read from the volume's backing store) ---
# In a single-container invocation this re-stat reads the same VFS view, so it
# will not catch Docker Desktop WSL2 volume driver persistence failures. The
# caller MUST run verify-volume.sh in a SEPARATE container (fresh mount
# namespace) to get a true persistence check. This block exists only to fail
# fast if the VFS cache is somehow inconsistent within one process.
PERSIST_UID=$(stat -c %u "$DATA_DIR")
PERSIST_GID=$(stat -c %g "$DATA_DIR")

if [ "$PERSIST_UID" = "$UID_TARGET" ] && [ "$PERSIST_GID" = "$GID_TARGET" ]; then
    echo "OK: Volume ownership verified: ${PERSIST_UID}:${PERSIST_GID}"
    echo "NOTE: For a true persistence check, also run verify-volume.sh in a" >&2
    echo "      separate container (fresh mount namespace). See ADR-20260822001." >&2
    exit 0
else
    echo "ERROR: Persistence verification failed!" >&2
    echo "  Expected: ${UID_TARGET}:${GID_TARGET}" >&2
    echo "  Actual:   ${PERSIST_UID}:${PERSIST_GID}" >&2
    echo "" >&2
    echo "In-container verify passed but re-stat shows different ownership." >&2
    echo "This may indicate a VFS cache issue. Run verify-volume.sh in a fresh" >&2
    echo "container to confirm. If the fresh container also fails, this is a" >&2
    echo "volume driver persistence failure (Docker Desktop WSL2 quirk)." >&2
    echo "See ADR-20260822001 for recovery procedures." >&2
    exit 3
fi
