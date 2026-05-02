#!/bin/bash
# RustFS entrypoint script
# Initializes data directories and starts RustFS

set -euo pipefail

# Configuration
DATA_DIR="/data"
LOG_DIR="/app/logs"
RUSTFS_BINARY="/usr/bin/rustfs"

# Get user info from environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [entrypoint] $*"
}

# Create data directories if they don't exist
create_data_directories() {
    log "Initializing data directories: ${DATA_DIR}/rustfs{0..3}"

    # Create data directory if it doesn't exist
    if [ ! -d "${DATA_DIR}" ]; then
        mkdir -p "${DATA_DIR}"
        log "Created data directory: ${DATA_DIR}"
    fi

    # Create individual volume directories
    for i in 0 1 2 3; do
        volume_dir="${DATA_DIR}/rustfs${i}"
        if [ ! -d "${volume_dir}" ]; then
            mkdir -p "${volume_dir}"
            log "Created volume directory: ${volume_dir}"
        fi
    done

    # Set proper permissions using environment variables
    chown -R "${PUID}:${PGID}" "${DATA_DIR}"
    chmod 755 "${DATA_DIR}"
    log "Set permissions on data directories (owner: ${PUID}:${PGID})"
}

# Create log directory
create_log_directory() {
    log "Initializing log directory: ${LOG_DIR}"

    # Create /app/logs if it doesn't exist (might be read-only)
    if [ ! -d "${LOG_DIR}" ]; then
        # Try to create it, but don't fail if we can't
        mkdir -p "${LOG_DIR}" 2>/dev/null || log "Could not create ${LOG_DIR}, will use in-memory logs"
    fi

    # Set permissions if directory exists
    if [ -d "${LOG_DIR}" ]; then
        chown -R "${PUID}:${PGID}" "${LOG_DIR}" 2>/dev/null || true
        chmod 755 "${LOG_DIR}" 2>/dev/null || true
        log "Set permissions on log directory (owner: ${PUID}:${PGID})"
    fi
}

# Check if RustFS binary exists
check_rustfs_binary() {
    if [ ! -f "${RUSTFS_BINARY}" ]; then
        log "${RED}ERROR: RustFS binary not found at ${RUSTFS_BINARY}${NC}"
        exit 1
    fi

    log "Found RustFS binary: ${RUSTFS_BINARY}"
}

# Main function
main() {
    log "Starting RustFS entrypoint..."
    log "User configuration: PUID=${PUID}, PGID=${PGID}, USERNAME=${USERNAME}"

    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        log "${YELLOW}Running as root, initializing directories...${NC}"
        create_data_directories
        create_log_directory

        # Drop privileges to specified user
        log "Dropping privileges to ${USERNAME} (${PUID}:${PGID})..."

        # Check if user exists, if not create it
        if ! id "${USERNAME}" >/dev/null 2>&1; then
            log "Creating user ${USERNAME} with UID=${PUID} and GID=${PGID}"
            # Create group first
            addgroup -g "${PGID}" "${USERNAME}" 2>/dev/null || {
                # If group already exists, use it
                GROUP_NAME=$(getent group "${PGID}" | cut -d: -f1)
                log "Using existing group: ${GROUP_NAME}"
                adduser -D -u "${PUID}" -G "${GROUP_NAME}" -s /bin/sh "${USERNAME}" 2>/dev/null || {
                    log "Failed to create user, will use root"
                    exec "$@"
                }
            }
            # Create user
            adduser -D -u "${PUID}" -G "${USERNAME}" -s /bin/sh "${USERNAME}" 2>/dev/null || {
                log "Failed to create user with group ${USERNAME}, trying with numeric GID"
                adduser -D -u "${PUID}" -G "${PGID}" -s /bin/sh "${USERNAME}" 2>/dev/null || {
                    log "Failed to create user, will use root"
                    exec "$@"
                }
            }
        fi

        # Drop privileges
        log "Dropping privileges to ${USERNAME} (${PUID}:${PGID})..."
        exec su -s /bin/sh "${USERNAME}" "$@"
    else
        log "Running as non-root user $(id -u):$(id -g)"
        # Already running as non-root, just start RustFS
        exec "$@"
    fi
}

# Run main function with all arguments
main "$@"
