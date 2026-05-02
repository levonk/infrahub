#!/bin/sh
# =============================================================================
# Base Sidecar Entrypoint Script
# =============================================================================
# Purpose: Extend base-nix functionality with additional sidecar capabilities
# Context: Runs as the main entrypoint for base-sidecar container
# Inheritance: Inherits /base-app and /base-nix directories from base-nix
# Usage: Base image for services that need both Nix and additional tools
# =============================================================================

# Exit immediately if any command fails
set -e

# =============================================================================
# Environment Variables Configuration
# =============================================================================
# Default values for user configuration (inherited from base-nix)
# - PUID: User ID for the non-root user (default: 1000)
# - PGID: Group ID for the non-root user (default: 1000)
# - USERNAME: Username for the non-root user (default: cuser)
# These can be overridden via environment variables or docker-compose
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Base Sidecar: Starting entrypoint..."

# =============================================================================
# PATH Configuration
# =============================================================================
# Ensure Nix binaries are in the PATH (simplified since base-nix already setup)
# Note: This is a basic PATH since base-nix already configured the full Nix PATH
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# =============================================================================
# User Creation (if needed)
# =============================================================================
# Create the user if it doesn't exist
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "🤖 Base Sidecar: Creating user $USERNAME (UID: $PUID, GID: $PGID)..."
    # Try to create group first
    if command -v addgroup >/dev/null 2>&1; then
        addgroup -g "$PGID" -S "$USERNAME" 2>/dev/null || addgroup -S "$USERNAME" 2>/dev/null || true
    elif command -v groupadd >/dev/null 2>&1; then
        groupadd -g "$PGID" "$USERNAME" 2>/dev/null || groupadd "$USERNAME" 2>/dev/null || true
    fi
    # Create user
    if command -v adduser >/dev/null 2>&1; then
        adduser -u "$PUID" -S "$USERNAME" -G "$USERNAME" -s /bin/sh -h "/home/$USERNAME" 2>/dev/null || \
        adduser -S "$USERNAME" -s /bin/sh 2>/dev/null || true
    elif command -v useradd >/dev/null 2>&1; then
        useradd -u "$PUID" -g "$PGID" -m -s /bin/sh "$USERNAME" 2>/dev/null || \
        useradd -m -s /bin/sh "$USERNAME" 2>/dev/null || true
    fi
fi

# =============================================================================
# User Execution Function (Sidecar Context)
# =============================================================================
# Purpose: Execute commands as the non-root user with proper environment
# Security: Ensures commands run with reduced privileges
# Environment: Runs within sidecar nix develop for sidecar-specific dependencies
exec_as_user() {
    local cmd="$1"
    echo "🤖 Base Sidecar: Executing as user $USERNAME: $cmd"
    # Try different user switching methods in order of preference:
    # 1. gosu: Modern, secure user switching (preferred)
    # 2. su-exec: Alpine-compatible user switching
    # 3. su: Traditional Unix user switching (fallback)
    if command -v gosu >/dev/null 2>&1; then
        exec gosu "$USERNAME" sh -c "$cmd"
    elif command -v su-exec >/dev/null 2>&1; then
        exec su-exec "$USERNAME" sh -c "$cmd"
    else
        exec su "$USERNAME" -s /bin/sh -c "$cmd"
    fi
}

echo "🤖 Base Sidecar: Ready."

# =============================================================================
# Main Execution Logic (Sidecar Context)
# =============================================================================
# Purpose: Execute provided command or print informative message and exit
# Behavior:
# - With arguments: Execute the command as the non-root user
# - Without arguments: Print message and exit (base image behavior)
# Context: Uses sidecar-specific nix develop environment
# =============================================================================
# Execute command or print message and exit
if [ "$#" -gt 0 ]; then
	echo "🤖 Base Sidecar: Executing command: $*"
    exec_as_user "$*"
else
	echo "🤖 Base Sidecar: Intended to be a base image for sidecar images, shutting down."
	echo "🤖 Base Sidecar: Use 'docker exec -it <container-name> /bin/bash' to get an interactive shell"
    # Exit cleanly - this is a base image, not meant to run as a standalone service
    exit 0
fi
