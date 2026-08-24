#!/bin/sh
# verify-volume.sh — verify Docker volume ownership matches expected values.
#
# Usage: docker run --rm --entrypoint /usr/local/bin/verify-volume \
#          -v <volume>:/data localnet-volume-init:latest verify <uid> <gid>
#
# Exit codes:
#   0 = ownership matches expected uid:gid
#   1 = parameter error (missing/non-numeric uid/gid)
#   2 = ownership mismatch
#
# Per ADR-20260822001: this is the Phase 2 "fresh-container verify" — it runs
# in a SEPARATE container from init-volume.sh so the volume is re-mounted from
# the Docker volume store, giving a true persistence check. If init-volume.sh
# passed (Phase 1 + Phase 1.5) but this script fails, the diagnosis is a
# volume driver persistence failure (Docker Desktop WSL2 quirk). See the ADR's
# diagnostic matrix and recovery procedures.

set -eu

DATA_DIR="${DATA_DIR:-/data}"

# Allow invocation as either:
#   verify-volume verify <uid> <gid>   (CMD-style, when ENTRYPOINT is overridden)
#   verify-volume <uid> <gid>          (direct)
if [ "${1:-}" = "verify" ]; then
    shift
fi

UID_EXPECTED="${1:-}"
GID_EXPECTED="${2:-}"

if [ -z "$UID_EXPECTED" ] || [ -z "$GID_EXPECTED" ]; then
    echo "ERROR: Usage: verify-volume verify <uid> <gid>" >&2
    echo "  uid — expected UID (numeric, required)" >&2
    echo "  gid — expected GID (numeric, required)" >&2
    echo "" >&2
    echo "Environment:" >&2
    echo "  DATA_DIR — mount point inside the container (default: /data)" >&2
    exit 1
fi

case "$UID_EXPECTED" in
    ''|*[!0-9]*) echo "ERROR: UID must be numeric, got: $UID_EXPECTED" >&2; exit 1 ;;
esac
case "$GID_EXPECTED" in
    ''|*[!0-9]*) echo "ERROR: GID must be numeric, got: $GID_EXPECTED" >&2; exit 1 ;;
esac

if [ ! -d "$DATA_DIR" ]; then
    echo "ERROR: Data directory ${DATA_DIR} does not exist" >&2
    echo "  Did you forget to mount the volume with -v <volume>:${DATA_DIR}?" >&2
    exit 2
fi

ACTUAL_UID=$(stat -c %u "$DATA_DIR")
ACTUAL_GID=$(stat -c %g "$DATA_DIR")

if [ "$ACTUAL_UID" = "$UID_EXPECTED" ] && [ "$ACTUAL_GID" = "$GID_EXPECTED" ]; then
    echo "OK: Volume ownership verified: ${ACTUAL_UID}:${ACTUAL_GID}"
    exit 0
else
    echo "ERROR: Volume ownership mismatch!" >&2
    echo "  Expected: ${UID_EXPECTED}:${GID_EXPECTED}" >&2
    echo "  Actual:   ${ACTUAL_UID}:${ACTUAL_GID}" >&2
    echo "" >&2
    echo "If init-volume.sh passed but this verify failed, this is a volume" >&2
    echo "driver persistence failure (Docker Desktop WSL2 quirk). See" >&2
    echo "ADR-20260822001 for recovery procedures." >&2
    exit 2
fi
